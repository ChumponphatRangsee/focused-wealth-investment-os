import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";
// Dedicated PRICE ONLY worker. No write to any fwios portfolio/holdings/transactions/decision tables.
// _Market_Data compatibility layout copied from current verified sync service.
const dbUrl = Deno.env.get("SUPABASE_DB_URL");
const sql = dbUrl ? postgres(dbUrl, { prepare:false,max:1 }) : null;
const WORKER = "price-sheet-sync-v1";
const SPREADSHEET_ID = "1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw";
const SHEET_NAME = "_Market_Data";
const SHEET_MAX_ROW = 200;
const GOOGLE_CREDENTIAL_SECRET = "fwios_google_sheets_service_account_json";
type ServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

async function sha256Hex(input: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(bytes))
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
}

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function base64Url(data: Uint8Array | string) {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToDer(pem: string) {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function vaultSecret(name: string) {
  const rows = await sql!`select decrypted_secret
    from vault.decrypted_secrets
    where name=${name}
    limit 1`;
  return rows.length ? String(rows[0].decrypted_secret) : null;
}

async function getGoogleAccessToken(sa: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64Url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/spreadsheets",
    aud: sa.token_uri || "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  ));
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });
  const res = await fetch(sa.token_uri || "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const json = await res.json();
  if (!res.ok || !json?.access_token) {
    throw new Error(`GOOGLE_OAUTH_FAILED_${res.status}`);
  }
  return String(json.access_token);
}

async function googleJson(url: string, token: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers || {});
  headers.set("Authorization", `Bearer ${token}`);
  if (init.body != null) headers.set("Content-Type", "application/json");
  const res = await fetch(url, { ...init, headers });
  const text = await res.text();
  let data: any = text;
  try { data = text ? JSON.parse(text) : {}; } catch {}
  if (!res.ok) {
    const reason = typeof data === "string" ? data.slice(0, 240) : JSON.stringify(data).slice(0, 240);
    throw new Error(`GOOGLE_SHEETS_HTTP_${res.status}_${reason}`);
  }
  return data;
}
async function readLiveHoldings(token: string) {
  const range = "Holdings!A5:L1001";
  const link = "https://sheets.googleapis.com/v4/spreadsheets/" + SPREADSHEET_ID +
    "/values/" + encodeURIComponent(range) + "?valueRenderOption=UNFORMATTED_VALUE";
  const data = await googleJson(link, token);
  return Array.isArray(data?.values) ? data.values : [];
}

function parseLiveHoldings(source: unknown[][]) {
  const positions: { source_row:number; account_key:string;
    asset_symbol:string; asset_class:string; quantity:number }[] = [];
  const accountKeys: Record<string,string> = {
    "best":"best", "loan money":"loan_money", "mom":"mom"
  };
  const seen = new Set<string>();
  for (let i=0;i<source.length;i++) {
    const r=source[i] || [];
    if (String(r[11]||"").trim().toUpperCase()!=="OPEN") continue;
    const account_key=accountKeys[String(r[0]||"").trim().toLowerCase()];
    const asset_symbol=String(r[1]||"").trim().toUpperCase();
    const asset_class=String(r[4]||"").trim();
    const quantity=Number(r[3]);
    const unique=account_key+":"+asset_symbol;
    if (!account_key || !/^[A-Z0-9._-]{1,20}$/.test(asset_symbol) ||
        !["Stock","Crypto"].includes(asset_class) || !(quantity>0) ||
        !Number.isFinite(quantity) || seen.has(unique)) {
      throw new Error("INVALID_LIVE_HOLDINGS_ROW_"+(i+5));
    }
    seen.add(unique);
    positions.push({source_row:i+5,account_key,asset_symbol,asset_class,quantity});
  }
  if (!positions.length || positions.length>200) throw new Error("INVALID_LIVE_HOLDINGS_COUNT");
  return positions;
}

async function loadPricePayload(googleToken:string) {
 const source = await readLiveHoldings(googleToken);
 const positions = parseLiveHoldings(source); // holdings remain owned by Google Sheet
 const openAssets=[...new Set(positions.filter(p=>p.asset_class==="Crypto").map(p=>p.asset_symbol))].sort();
 const openStocks=[...new Set(positions.filter(p=>p.asset_class==="Stock").map(p=>p.asset_symbol))].sort();
 if(openAssets.length<1||openAssets.length>15)throw new Error("INVALID_CRYPTO_UNIVERSE_SIZE");
 if(openStocks.length>15)throw new Error("INVALID_STOCK_UNIVERSE_SIZE");
 const all=[...new Set([...openAssets,...openStocks])].sort();
 const results=await sql!`select t.asset_symbol,fwios.pr7_native_usd_price_read_v1(t.asset_symbol) q
   from unnest(${all}::text[]) as t(asset_symbol) order by asset_symbol`;
 if(results.length!==all.length)throw new Error("QUOTE_COVERAGE_MISMATCH");
 const bySymbol=new Map<string,any>(results.map((r:any)=>[String(r.asset_symbol),r.q||{}]));
 const toValue=(symbol:string,q:any)=>[
  symbol,String(q.instrument_id),String(q.asset_class),Number(q.price_usd),
  "USD",String(q.status),String(q.quote_kind),String(q.provider),
  String(q.observation_id),String(q.observed_at),String(q.session_date),
  String(q.valid_until),true,false,true,String(q.checked_at)
 ];
 const values=openAssets.map(symbol=>{
  const q=bySymbol.get(symbol)||{},px=Number(q.price_usd);
  if(q.asset_class!=="Crypto"||q.status!=="FRESH"||q.source_native_usd!==true
     ||q.valuation_eligible!==true||q.currency!=="USD"
     ||!(px>0)||!Number.isFinite(px)||!q.observation_id||!q.session_date||!q.valid_until)
    throw new Error("CRYPTO_PRICE_NOT_ELIGIBLE_"+symbol);
  return toValue(symbol,q);
 });
 // Stock row refresh is opt-in: require the new EOD collector's immutable provenance.
 // Historic stock observations may still be in the database but are NOT synced.
 const stockQuotes=openStocks.map(symbol=>({symbol,q:bySymbol.get(symbol)||{}}));
 const candidateIds=stockQuotes.filter(({q})=>q.asset_class==="Stock"
  &&q.status==="LAST_CLOSE"&&q.quote_kind==="STOCK_REGULAR_CLOSE"
  &&q.provider==="ALPHA_VANTAGE_PRICE"&&q.currency==="USD"
  &&q.source_native_usd===true&&q.valuation_eligible===true
  &&Number(q.price_usd)>0&&q.observation_id&&q.session_date&&q.valid_until)
  .map(({q})=>String(q.observation_id));
 const certified=candidateIds.length?await sql!`select observation_id::text id
  from fwios.market_observations where observation_id=ANY(${candidateIds}::uuid[])
   and observation_type='REGULAR_CLOSE' and market_status='CLOSED'
   and provider='ALPHA_VANTAGE_PRICE' and source_tier='A'
   and raw_payload->>'price_only_stock_eod'='true'
   and raw_payload->>'close_kind'='UNADJUSTED'`:[];
 const allowedIds=new Set(certified.map((r:any)=>String(r.id)));
 const stockValues=stockQuotes.filter(({q})=>allowedIds.has(String(q.observation_id)))
  .map(({symbol,q})=>toValue(symbol,q));
 const fxRows=await sql!`select observation_value::numeric fx_rate,provider,observation_id,observed_at,session_date,provenance_status
    from fwios.market_observations where observation_type='FX' and value_currency='THB'
      and provenance_status='PASS' and observation_value>0
    order by observed_at desc,created_at desc limit 1`;
 if(!fxRows.length)throw new Error("USDTHB_FX_MISSING");
 const fx=fxRows[0];
 if(new Date(String(fx.observed_at)).getTime()<Date.now()-1000*60*60*120)throw new Error("USDTHB_FX_STALE");
 return {openAssets,openStocks,values,stockValues,fx:["USDTHB",Number(fx.fx_rate),String(fx.provider),
  String(fx.observation_id),String(fx.observed_at),String(fx.session_date),String(fx.provenance_status)]};
}

async function writeShadow(payload: Awaited<ReturnType<typeof loadPricePayload>>, token: string) {
  // Update only verified fresh Stock EOD rows; leave all other Stock history untouched.
  const existingUrl = `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/` +
    encodeURIComponent(`${SHEET_NAME}!A1:X${SHEET_MAX_ROW}`) +
    "?majorDimension=ROWS&valueRenderOption=UNFORMATTED_VALUE";
  const beforeDoc = await googleJson(existingUrl, token);
  const before: any[][] = Array.isArray(beforeDoc?.values) ? beforeDoc.values : [];
  if (String(before?.[0]?.[0] || "") !== "asset_symbol")
    throw new Error("SHEET_HEADER_MISMATCH");
  const updateableStockSymbols = new Set(payload.stockValues.map(data=>String(data[0])));
  const existingBySymbol = new Map<string, number>();
  const stockProtected = new Map<number, string>();
  for (let row = 2; row <= SHEET_MAX_ROW; row++) {
    const record = before[row - 1] || [];
    const symbol = String(record[0] || "").trim().toUpperCase();
    if (!symbol) continue;
    if (existingBySymbol.has(symbol))
      throw new Error("DUPLICATE_SHEET_SYMBOL_" + symbol);
    existingBySymbol.set(symbol, row);
    if (String(record[2] || "") === "Stock" && !updateableStockSymbols.has(symbol))
      stockProtected.set(row, JSON.stringify(record.slice(0, 16)));
  }
  const claimedRows = new Set<number>(existingBySymbol.values());
  const targets = [...payload.values,...payload.stockValues].map((data) => {
    const symbol = String(data[0]);
    let row = existingBySymbol.get(symbol);
    if (!row) {
      for (let candidate = 2; candidate <= SHEET_MAX_ROW; candidate++) {
        if (!claimedRows.has(candidate)) { row = candidate; break; }
      }
    }
    if (!row) throw new Error("SHEET_CAPACITY_EXHAUSTED");
    const existingClass=String((before[row - 1]||[])[2]||"");
    if (existingClass && existingClass!==String(data[2]))
      throw new Error("ASSET_CLASS_CHANGE_BLOCKED_"+symbol);
    if (existingClass==="Stock" && !updateableStockSymbols.has(symbol))
      throw new Error("STOCK_ROW_OVERWRITE_BLOCKED_" + symbol);
    claimedRows.add(row);
    return { row, data };
  });
  if (!targets.length || targets.length > 30)
    throw new Error("PRICE_SHEET_UNIVERSE_INVALID");
  const updates: any[] = [];
  for (const t of targets) {
    updates.push({ range:`${SHEET_NAME}!A${t.row}:P${t.row}`,
      majorDimension:"ROWS", values:[t.data] });
    updates.push({ range:`${SHEET_NAME}!Q${t.row}`,
      majorDimension:"ROWS",
      values:[[`=IF(AND(D${t.row}<>"",$S$2<>""),D${t.row}*$S$2,"")`]] });
  }
  updates.push({ range:`${SHEET_NAME}!R2:X2`,
    majorDimension:"ROWS", values:[payload.fx] });
  await googleJson(
    `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values:batchUpdate`,
    token, { method:"POST",
      body:JSON.stringify({valueInputOption:"USER_ENTERED",data:updates}) }
  );

  const afterDoc = await googleJson(existingUrl, token);
  const after: any[][] = Array.isArray(afterDoc?.values) ? afterDoc.values : [];
  if (String(after?.[0]?.[0] || "") !== "asset_symbol")
    throw new Error("SHEET_READBACK_HEADER_MISMATCH");
  for (const [row, snapshot] of stockProtected.entries()) {
    if (JSON.stringify((after[row - 1] || []).slice(0, 16)) !== snapshot)
      throw new Error("STOCK_HISTORY_MODIFIED_" + row);
  }
  for (const t of targets) {
    const actual = after[t.row - 1] || [];
    const expected = t.data;
    for (const col of [0,1,2,4,5,6,7,8,14]) {
      if (String(actual[col] ?? "") !== String(expected[col] ?? ""))
        throw new Error("PRICE_READBACK_FIELD_MISMATCH_" + t.row + "_" + col);
    }
    const rawDate = actual[10];
    const isoDate = typeof rawDate === "number"
      ? new Date(Date.UTC(1899,11,30)+rawDate*86400000).toISOString().slice(0,10)
      : String(rawDate || "").slice(0,10);
    if (isoDate !== String(expected[10]).slice(0,10))
      throw new Error("PRICE_SESSION_MISMATCH_" + t.row);
    const p = Number(expected[3]), r = Number(actual[3]);
    if (!Number.isFinite(p) || !Number.isFinite(r) ||
        Math.abs(p-r) > 1e-8*Math.max(1,Math.abs(p)))
      throw new Error("PRICE_PRICE_READBACK_MISMATCH_" + t.row);
    const converted = Number(actual[16]);
    if (!Number.isFinite(converted) ||
        Math.abs(converted-p*Number(payload.fx[1])) >
          1e-7*Math.max(1,Math.abs(p*Number(payload.fx[1]))))
      throw new Error("PRICE_FX_FORMULA_READBACK_MISMATCH_" + t.row);
  }
  const fx = after[1] || [];
  if (String(fx[17]) !== String(payload.fx[0]) ||
      Math.abs(Number(fx[18])-Number(payload.fx[1])) > 1e-9 ||
      String(fx[19]) !== String(payload.fx[2]) ||
      String(fx[20]) !== String(payload.fx[3]) ||
      String(fx[23]) !== String(payload.fx[6]))
    throw new Error("FX_READBACK_MISMATCH");
  return { rowCount:targets.length, totalRowsPreserved:existingBySymbol.size,
    protectedStocks:stockProtected.size, openAssets:payload.openAssets,
    openStocks:payload.openStocks,stockSynced:payload.stockValues.length,cryptoSynced:payload.values.length };
}

Deno.serve(async(req:Request)=>{
 if(req.method!=="POST") return new Response("Method Not Allowed",{status:405});
 if(!sql||!dbUrl) return Response.json({ok:false,error:"DB_UNAVAILABLE"},{status:503});
 const provided=req.headers.get("x-fwios-automation-token")||"";
 const expected=(await vaultSecret("fwios_automation_token"))||"";
 if(provided.length<32||!expected||!safeEqual(provided,expected))
    return new Response("Unauthorized",{status:401});
 let body:any={};try{body=await req.json()}catch{}
 const dryRun=body?.dry_run===true;
 try {
  const creds=await vaultSecret(GOOGLE_CREDENTIAL_SECRET);
  if(!creds)throw new Error("GOOGLE_SERVICE_ACCOUNT_CREDENTIAL_MISSING");
  const sa:ServiceAccount=JSON.parse(creds);
  if(!sa?.client_email||!sa?.private_key)throw new Error("GOOGLE_SERVICE_ACCOUNT_INCOMPLETE");
  const token=await getGoogleAccessToken(sa);
  const payload=await loadPricePayload(token);
  if(dryRun) return Response.json({ok:true,worker:WORKER,dry_run:true,asset_count:payload.values.length+payload.stockValues.length,
    crypto_count:payload.values.length,stock_count:payload.stockValues.length,
    source:"GOOGLE_SHEET_HOLDINGS_READ_ONLY",database_writes:0,sheet_writes:0,auto_trade:false});
  const receipt=await writeShadow(payload,token);
  return Response.json({ok:true,worker:WORKER,asset_count:receipt.rowCount,
    crypto_count:receipt.cryptoSynced,stock_count:receipt.stockSynced,
    sheet:SHEET_NAME,sheet_write_readback_verified:true,source:"GOOGLE_SHEET_HOLDINGS_READ_ONLY",
    database_writes:0,auto_trade:false});
 }catch(e) {
  const message=(e instanceof Error?e.message:String(e)).slice(0,300);
  return Response.json({ok:false,worker:WORKER,error:message,auto_trade:false},{status:503});
 }
});
