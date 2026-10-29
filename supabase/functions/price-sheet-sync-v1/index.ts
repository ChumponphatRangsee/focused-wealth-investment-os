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
 const positions = parseLiveHoldings(source);  // Read Google Sheet only; do NOT persist holdings to Supabase.
 const openAssets = [...new Set(positions.map(p=>p.asset_symbol))].sort();
 if(openAssets.length<1 || openAssets.length>199)throw new Error("INVALID_PRICE_UNIVERSE_SIZE");
 const results = await sql!`select t.asset_symbol,fwios.pr7_native_usd_price_read_v1(t.asset_symbol) q
    from unnest(${openAssets}::text[]) as t(asset_symbol) order by asset_symbol`;
 if(results.length!==openAssets.length)throw new Error("QUOTE_COVERAGE_MISMATCH");
 const values = results.map((r:any)=>{
    const q = r.q || {};
    const px=Number(q.price_usd);
    if(!["Stock","Crypto"].includes(String(q.asset_class))
      || !["LAST_CLOSE","FRESH"].includes(String(q.status))
      || q.source_native_usd!==true || q.valuation_eligible!==true
      || q.currency!=="USD" || !(px>0) || !Number.isFinite(px)
      || !q.observation_id || !q.session_date || !q.valid_until)
      throw new Error("PRICE_NOT_ELIGIBLE_"+String(r.asset_symbol));
    return [String(r.asset_symbol),String(q.instrument_id),String(q.asset_class),
      px,"USD",String(q.status),String(q.quote_kind),String(q.provider),
      String(q.observation_id),String(q.observed_at),String(q.session_date),
      String(q.valid_until),true,false,true,String(q.checked_at)];
 });
 const fxRows=await sql!`select observation_value::numeric fx_rate,provider,observation_id,observed_at,session_date,provenance_status
    from fwios.market_observations where observation_type='FX' and value_currency='THB'
      and provenance_status='PASS' and observation_value>0
    order by observed_at desc,created_at desc limit 1`;
 if(!fxRows.length)throw new Error("USDTHB_FX_MISSING");
 const fx=fxRows[0];
 if(new Date(String(fx.observed_at)).getTime()<Date.now()-1000*60*60*120)throw new Error("USDTHB_FX_STALE");
 return {openAssets,values,fx:["USDTHB",Number(fx.fx_rate),String(fx.provider),
  String(fx.observation_id),String(fx.observed_at),String(fx.session_date),String(fx.provenance_status)]};
}
async function writeShadow(payload: Awaited<ReturnType<typeof loadPricePayload>>, token: string) {
  const rowCount = payload.values.length;
  if (rowCount < 1 || rowCount >= SHEET_MAX_ROW) throw new Error("SHADOW_ROW_COUNT_OUT_OF_RANGE");
  const endRow = rowCount + 1;
  const formulas = payload.values.map((_, i) => {
    const row = i + 2;
    return [`=IF(AND(D${row}<>"",$S$2<>""),D${row}*$S$2,"")`];
  });

  const batchUrl = `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values:batchUpdate`;
  await googleJson(batchUrl, token, {
    method: "POST",
    body: JSON.stringify({
      valueInputOption: "USER_ENTERED",
      data: [
        { range: `${SHEET_NAME}!A2:P${endRow}`, majorDimension: "ROWS", values: payload.values },
        { range: `${SHEET_NAME}!Q2:Q${endRow}`, majorDimension: "ROWS", values: formulas },
        { range: `${SHEET_NAME}!R2:X2`, majorDimension: "ROWS", values: [payload.fx] },
      ],
    }),
  });

  const verifyRange = encodeURIComponent(`${SHEET_NAME}!A1:X${endRow}`);
  const verify = await googleJson(
    `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/${verifyRange}?majorDimension=ROWS&valueRenderOption=UNFORMATTED_VALUE`,
    token,
  );
  const actual = Array.isArray(verify?.values) ? verify.values : [];
  if (actual.length !== endRow) throw new Error("SHEET_VERIFY_ROW_COUNT_MISMATCH");

  const actualSymbols = new Set(actual.slice(1).map((r: any[]) => String(r?.[0] || "").toUpperCase()));
  const missingOpen = payload.openAssets.filter((s) => !actualSymbols.has(s));
  if (missingOpen.length) throw new Error(`SHEET_VERIFY_OPEN_HOLDING_MISSING_${missingOpen.join(",")}`);
  if (String(actual?.[0]?.[0] || "") !== "asset_symbol") throw new Error("SHEET_VERIFY_HEADER_MISMATCH");

  // Compare the native source values with Google's post-write calculation.
  for (let i = 0; i < payload.values.length; i++) {
    const expected = payload.values[i];
    const readback = actual[i + 1] || [];
    for (const col of [0, 1, 5, 6, 7, 8, 14]) {
      if (String(readback[col] ?? "") !== String(expected[col] ?? "")) {
        throw new Error("SHEET_VERIFY_FIELD_MISMATCH_" + (i + 2) + "_" + col);
      }
    }
    // Sheets USER_ENTERED converts ISO session_date into a date serial number.
    const dateCell = readback[10];
    const isoDate = typeof dateCell === "number"
      ? new Date(Date.UTC(1899, 11, 30) + dateCell * 86400000).toISOString().slice(0, 10)
      : String(dateCell || "").slice(0, 10);
    if (isoDate !== String(expected[10]).slice(0, 10)) {
      throw new Error("SHEET_VERIFY_SESSION_MISMATCH_" + (i + 2));
    }
    const p = Number(expected[3]), r = Number(readback[3]);
    if (!Number.isFinite(p) || !Number.isFinite(r) ||
        Math.abs(p - r) > 1e-8 * Math.max(1, Math.abs(p))) {
      throw new Error("SHEET_VERIFY_USD_PRICE_MISMATCH_" + (i + 2));
    }
    if (expected[14] === true) {
      const expectedThb = p * Number(payload.fx[1]);
      const readThb = Number(readback[16]);
      if (!Number.isFinite(readThb) ||
          Math.abs(expectedThb - readThb) > 1e-7 * Math.max(1, Math.abs(expectedThb))) {
        throw new Error("SHEET_VERIFY_CONVERTED_PRICE_MISMATCH_" + (i + 2));
      }
    }
  }
  const actualFx = actual[1] || [];
  if (String(actualFx[17]) !== String(payload.fx[0]) ||
      Math.abs(Number(actualFx[18]) - Number(payload.fx[1])) > 1e-9 ||
      String(actualFx[19]) !== String(payload.fx[2]) ||
      String(actualFx[20]) !== String(payload.fx[3]) ||
      String(actualFx[23]) !== String(payload.fx[6])) {
    throw new Error("SHEET_VERIFY_FX_MISMATCH");
  }


  const staleStart = endRow + 1;
  if (staleStart <= SHEET_MAX_ROW) {
    const clearRange = encodeURIComponent(`${SHEET_NAME}!A${staleStart}:X${SHEET_MAX_ROW}`);
    await googleJson(
      `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/${clearRange}:clear`,
      token,
      { method: "POST", body: "{}" },
    );
  }

  return { rowCount, endRow, openAssets: payload.openAssets };
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
  if(dryRun) return Response.json({ok:true,worker:WORKER,dry_run:true,asset_count:payload.values.length,
    source:"GOOGLE_SHEET_HOLDINGS_READ_ONLY",database_writes:0,sheet_writes:0,auto_trade:false});
  const receipt=await writeShadow(payload,token);
  return Response.json({ok:true,worker:WORKER,asset_count:receipt.rowCount,
    sheet:SHEET_NAME,sheet_write_readback_verified:true,source:"GOOGLE_SHEET_HOLDINGS_READ_ONLY",
    database_writes:0,auto_trade:false});
 }catch(e) {
  const message=(e instanceof Error?e.message:String(e)).slice(0,300);
  return Response.json({ok:false,worker:WORKER,error:message,auto_trade:false},{status:503});
 }
});
