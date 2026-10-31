import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";
const dbUrl=Deno.env.get("SUPABASE_DB_URL");
const sql=dbUrl?postgres(dbUrl,{prepare:false,max:1}):null;
const SPREADSHEET_ID="1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw";
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


const COINS:Record<string,string>={BTC:"bitcoin",ETH:"ethereum",XRP:"ripple",SOL:"solana",HBAR:"hedera-hashgraph",DOGE:"dogecoin"};
async function jsonFetch(uri:string){
 const c=new AbortController(),id=setTimeout(()=>c.abort(),18000);
 try {const r=await fetch(uri,{signal:c.signal,headers:{Accept:"application/json"}});
  if(!r.ok)throw new Error("PROVIDER_HTTP_"+r.status);return await r.json();
 }finally{clearTimeout(id);}
}
async function cryptoRefresh(dry:boolean){
 const cred=await vaultSecret("fwios_google_sheets_service_account_json");
 if(!cred)throw new Error("GOOGLE_CREDENTIAL_MISSING");
 const token=await getGoogleAccessToken(JSON.parse(cred));
 const holdings=parseLiveHoldings(await readLiveHoldings(token));
 const names=[...new Set(holdings.filter(x=>x.asset_class==="Crypto").map(x=>x.asset_symbol))].sort();
 if(!names.length||names.length>15||names.some(x=>!COINS[x]))throw new Error("CRYPTO_UNIVERSE_INVALID");
 const ids=names.map(x=>COINS[x]).join(",");
 const d=await jsonFetch("https://api.coingecko.com/api/v3/simple/price?ids="+encodeURIComponent(ids)+"&vs_currencies=usd&include_last_updated_at=true");
 const now=Date.now();
 const rows=names.map(symbol=>{
   const q=d?.[COINS[symbol]],usd=Number(q?.usd),ts=Number(q?.last_updated_at);
   if(!(usd>0)||!(ts>0)||!Number.isFinite(usd))throw new Error("QUOTE_MISSING_"+symbol);
   const at=new Date(ts*1000);if(Math.abs(now-at.getTime())>7200000)throw new Error("QUOTE_STALE_"+symbol);
   return {symbol,usd,at:at.toISOString(),day:at.toISOString().slice(0,10),ts};
 });
 if(dry)return {source:"COINGECKO",asset_count:rows.length,symbols:names,database_writes:0,dry_run:true};
 for(const x of rows){
   const meta=JSON.stringify({price_only:true,provider_last_updated_at:x.ts,source_url:"https://api.coingecko.com/api/v3/simple/price"});
   const o=await sql!`select fwios.ensure_market_observation_v1(
     fwios.resolve_instrument_id_v1(${x.symbol},'Crypto',null,null),
     'LIVE_QUOTE',${x.usd},'USD',${x.day}::date,${x.at}::timestamptz,
     '24X7','COINGECKO','B','https://api.coingecko.com/api/v3/simple/price',
     'PASS',${meta}::jsonb,null,null) observation_id`;
   if(!o?.[0]?.observation_id)throw new Error("CRYPTO_SAVE_FAILED_"+x.symbol);
 }
 return {source:"COINGECKO",asset_count:rows.length,symbols:names,database_writes:rows.length,dry_run:false};
}
async function fxRefresh(dry:boolean){
 const url="https://api.frankfurter.app/latest?from=USD&to=THB",d=await jsonFetch(url);
 const rate=Number(d?.rates?.THB),day=String(d?.date||"");
 if(!(rate>0)||!(/^\d{4}-\d{2}-\d{2}$/).test(day))throw new Error("FX_INVALID");
 const age=(Date.now()-Date.parse(day+"T00:00:00Z"))/86400000;
 if(age>5||age< -1)throw new Error("FX_STALE");
 if(dry)return {source:"FRANKFURTER_FX",day,rate,database_writes:0,dry_run:true};
 const ids=await sql!`select instrument_id from fwios.market_observations
  where observation_type='FX' and fx_base_currency='USD' and fx_quote_currency='THB'
    and provenance_status='PASS' and instrument_id is not null
  order by observed_at desc limit 1`;
 if(!ids.length)throw new Error("FX_INSTRUMENT_MISSING");
 const meta=JSON.stringify({price_only:true,source_url:url,quote_date:day});
 const o=await sql!`select fwios.ensure_market_observation_v1(
    ${ids[0].instrument_id}::uuid,'FX',${rate},'THB',${day}::date,now(),'FX',
    'FRANKFURTER_FX','B',${url},'PASS',${meta}::jsonb,'USD','THB') observation_id`;
 if(!o?.[0]?.observation_id)throw new Error("FX_SAVE_FAILED");
 return {source:"FRANKFURTER_FX",day,database_writes:1,dry_run:false};
}

function newYorkClock(now: Date) {
 const parts = new Intl.DateTimeFormat("en-US", {
  timeZone:"America/New_York", year:"numeric", month:"2-digit",
  day:"2-digit", hour:"2-digit", minute:"2-digit", hourCycle:"h23",
  weekday:"short"
 }).formatToParts(now);
 const get=(type:string)=>parts.find(x=>x.type===type)?.value || "";
 return {day:get("year")+"-"+get("month")+"-"+get("day"),
  hour:Number(get("hour")),minute:Number(get("minute")),
  weekday:get("weekday")};
}
type StockEodRow={symbol:string;close:number;session_date:string};
async function stockCloseRefresh(dry:boolean){
 const ny=newYorkClock(new Date());
 if(["Sat","Sun"].includes(ny.weekday)){
  return {source:"ALPHA_VANTAGE_PRICE",skipped:true,reason:"US_MARKET_WEEKEND",
   session_date:ny.day,database_writes:0,dry_run:dry};
 }
 if(ny.hour<18){
  return {source:"ALPHA_VANTAGE_PRICE",skipped:true,reason:"EOD_COLLECTION_BEFORE_18_ET",
   session_date:ny.day,database_writes:0,dry_run:dry};
 }
 const credential=await vaultSecret("fwios_google_sheets_service_account_json");
 if(!credential)throw new Error("GOOGLE_CREDENTIAL_MISSING");
 const token=await getGoogleAccessToken(JSON.parse(credential));
 const holdings=parseLiveHoldings(await readLiveHoldings(token));
 const symbols=[...new Set(holdings.filter(x=>x.asset_class==="Stock")
  .map(x=>x.asset_symbol))].sort();
 if(symbols.length===0)return {source:"ALPHA_VANTAGE_PRICE",skipped:true,
  reason:"NO_OPEN_STOCK_HOLDINGS",asset_count:0,database_writes:0,dry_run:dry};
 if(symbols.length>15)throw new Error("STOCK_UNIVERSE_OVER_FREE_API_CAP");
 // Avoid redundant provider requests on repeat invocations or a manual dry run.
 // Protect partial certified sessions: do not mix old and newly fetched rows.
 const already=await sql!`select distinct s.symbol from fwios.market_observations o
  join fwios.instrument_symbols s on s.instrument_id=o.instrument_id
  where s.active=true and s.is_primary=true and s.symbol=any(${symbols}::text[])
    and o.session_date=${ny.day}::date and o.observation_type='REGULAR_CLOSE'
    and o.market_status='CLOSED' and o.provider='ALPHA_VANTAGE_PRICE'
    and o.source_tier='A' and o.value_currency='USD' and o.provenance_status='PASS'
    and o.observation_value>0 and o.raw_payload->>'price_only_stock_eod'='true'`;
 const certified=new Set(already.map((x:any)=>String(x.symbol).toUpperCase()));
 if(certified.size===symbols.length)return {
  source:"ALPHA_VANTAGE_PRICE",asset_count:symbols.length,symbols,session_date:ny.day,
  skipped:true,reason:"EOD_SESSION_ALREADY_CERTIFIED",
  provider_requests_attempted:0,database_writes:0,dry_run:dry
 };
 if(certified.size>0)return {
  source:"ALPHA_VANTAGE_PRICE",skipped:true,
  reason:"INCOMPLETE_CERTIFIED_SESSION_REQUIRES_REVIEW",
  expected_count:symbols.length,certified_count:certified.size,
  session_date:ny.day,provider_requests_attempted:0,database_writes:0,dry_run:dry
 };
 // Dry-run is a quota-free preflight, NOT a source EOD validation.
 if(dry)return {
  source:"ALPHA_VANTAGE_PRICE",asset_count:symbols.length,symbols,
  expected_session:ny.day,skipped:true,reason:"PREFLIGHT_NO_PROVIDER_REQUEST",
  provider_called:false,provider_requests_attempted:0,database_writes:0,dry_run:true
 };
 // Official Alpha Vantage API is queried only from the protected Edge runtime.
 // Never persist or return its key or the query URL with key embedded.
 const apiKey=await vaultSecret("ALPHA_VANTAGE_API_KEY");
 if(!apiKey||apiKey.trim().length<8)throw new Error("ALPHA_VANTAGE_KEY_MISSING");
 const rows:StockEodRow[]=[];
 for(const symbol of symbols){
  const url=new URL("https://www.alphavantage.co/query");
  url.searchParams.set("function","TIME_SERIES_DAILY");
  url.searchParams.set("symbol",symbol);
  url.searchParams.set("outputsize","compact");
  url.searchParams.set("apikey",apiKey);
  // Do not include the private URL in any log, error, provenance or response.
  let data:any;
  try {data=await jsonFetch(url.toString());}
  catch(e) {
   // HTTP 429 is a provider-side limit. Never retry automatically.
   if(e instanceof Error && e.message==="PROVIDER_HTTP_429")
    throw new Error("ALPHA_VANTAGE_RATE_LIMIT");
   throw e;
  }
  if(data?.Note||data?.Information||data?.["Error Message"]){
   // Sanitize provider rejection without returning raw provider message or credentials.
   const why=String(data.Note||data.Information||data["Error Message"]).toLowerCase();
   const code=/limit|quota|frequency|requests per day|api calls/.test(why)
     ?"ALPHA_VANTAGE_DAILY_RATE_LIMIT"
     :/invalid|demo|not valid|unknown key/.test(why)
     ?"ALPHA_VANTAGE_KEY_REJECTED"
     :/premium|subscription|plan|upgrade/.test(why)
     ?"ALPHA_VANTAGE_PLAN_RESTRICTED":"ALPHA_VANTAGE_PROVIDER_REJECTED";
   throw new Error(code);
  }
  const meta=String(data?.["Meta Data"]?.["2. Symbol"]||"").toUpperCase();
  if(meta!==symbol)throw new Error("STOCK_EOD_SYMBOL_MISMATCH_"+symbol);
  const series=data?.["Time Series (Daily)"];
  if(!series||typeof series!=="object"||Array.isArray(series))
   throw new Error("STOCK_EOD_RESPONSE_MISSING_"+symbol);
  const days=Object.keys(series).filter(x=>/^\d{4}-\d{2}-\d{2}$/.test(x)
    && x<=ny.day).sort().reverse();
  const day=days[0]||"";
  const close=Number(series?.[day]?.["4. close"]);
  if(!day||!(close>0)||!Number.isFinite(close)||close>10000000)
   throw new Error("STOCK_EOD_CLOSE_INVALID_"+symbol);
  rows.push({symbol,close,session_date:day});
 }
 // Never backdate a stale/previous-day quote as a fresh US closing price.
 const allCurrent=rows.every(x=>x.session_date===ny.day);
 if(!allCurrent){
  return {source:"ALPHA_VANTAGE_PRICE",asset_count:rows.length,
   symbols,available_sessions:[...new Set(rows.map(x=>x.session_date))],
   expected_session:ny.day,skipped:true,reason:"CURRENT_SESSION_EOD_NOT_AVAILABLE",
   database_writes:0,dry_run:dry};
 }
 if(dry)return {source:"ALPHA_VANTAGE_PRICE",asset_count:rows.length,
  symbols,session_date:ny.day,close_kind:"UNADJUSTED",database_writes:0,dry_run:true};
 // One SQL statement so all held symbols commit together or none commit.
 // Observed_at is the actual collection time; provider reports only the session DATE.
 const tickers=rows.map(x=>x.symbol),closes=rows.map(x=>x.close);
 const metadata=JSON.stringify({price_only:true,price_only_stock_eod:true,
  provider_function:"TIME_SERIES_DAILY",close_kind:"UNADJUSTED",
  source_session_date:ny.day});
 const saved=await sql!`select x.symbol,fwios.ensure_market_observation_v1(
  fwios.resolve_instrument_id_v1(x.symbol,'Stock',null,null),
  'REGULAR_CLOSE',x.close,'USD',${ny.day}::date,now(),'CLOSED',
  'ALPHA_VANTAGE_PRICE','A','https://www.alphavantage.co/query',
  'PASS',${metadata}::jsonb,null,null
 ) observation_id
 from unnest(${tickers}::text[],${closes}::numeric[]) AS x(symbol,close)`;
 if(saved.length!==rows.length||saved.some((x:any)=>!x.observation_id))
  throw new Error("STOCK_EOD_DATABASE_PERSISTENCE_MISMATCH");
 return {source:"ALPHA_VANTAGE_PRICE",asset_count:rows.length,symbols,
  session_date:ny.day,close_kind:"UNADJUSTED",
  provider_requests_attempted:rows.length,database_writes:rows.length,dry_run:false};
}

Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return new Response("Method Not Allowed",{status:405});
 if(!sql)return Response.json({ok:false,error:"DB_UNAVAILABLE"},{status:503});
 const got=req.headers.get("x-fwios-automation-token")||"",want=await vaultSecret("fwios_automation_token");
 if(!want||got.length<32||!safeEqual(got,want))return new Response("Unauthorized",{status:401});
 let b:any={};try{b=await req.json()}catch{}
 const mode=String(b?.mode||"").toUpperCase(),dry=b?.dry_run===true;
 if(!["CRYPTO","FX","US_STOCK_EOD"].includes(mode))return Response.json({ok:false,error:"INVALID_MODE"},{status:400});
 try{
  const x=mode==="CRYPTO"?await cryptoRefresh(dry):mode==="FX"?await fxRefresh(dry):await stockCloseRefresh(dry);
  return Response.json({ok:true,worker:"price-market-refresh-v1",mode,...x,portfolio_writes:0,auto_trade:false});
 }catch(e){return Response.json({ok:false,worker:"price-market-refresh-v1",mode,error:String(e instanceof Error?e.message:e).slice(0,200)},{status:503});}
});
