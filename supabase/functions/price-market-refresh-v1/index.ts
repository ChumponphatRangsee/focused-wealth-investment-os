import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {parseTwelveDailyEod,previousNyBusinessDay,twelveFallbackWindow,type StockEodRow} from "./twelve-eod-guards.ts";
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
 if(!(rate>0)||!(/^\d{4}-\d{2}-\d{2}$/.test(day)))throw new Error("FX_INVALID");
 const age=(Date.now()-Date.parse(day+"T00:00:00Z"))/86400000;
 if(age>5||age< -1)throw new Error("FX_STALE");
 const identity=await sql!`select fwios.resolve_instrument_id_v1(
   'USDTHB','FX','FX','FX_PAIR') instrument_id`;
 if(identity.length!==1||!identity[0].instrument_id)throw new Error("FX_IDENTITY_MISSING");
 if(dry)return {source:"FRANKFURTER_FX",day,rate,fx_symbol:"USDTHB",
  database_writes:0,dry_run:true};
 const meta=JSON.stringify({price_only:true,fx_symbol:"USDTHB",source_url:url,quote_date:day});
 const o=await sql!`select fwios.ensure_market_observation_v1(
    ${identity[0].instrument_id}::uuid,'FX',${rate},'THB',${day}::date,now(),'FX',
    'FRANKFURTER_FX','B',${url},'PASS',${meta}::jsonb,'USD','THB') observation_id`;
 if(!o?.[0]?.observation_id)throw new Error("FX_SAVE_FAILED");
 return {source:"FRANKFURTER_FX",day,fx_symbol:"USDTHB",database_writes:1,dry_run:false};
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

// Historical Alpha observations remain immutable; the live collector is Twelve Data only.
// Private quota ledger is not a price store. All external API calls require an atomic reservation.
type EodProvider="TWELVE_DATA";
function quotaKey(_p:EodProvider){return "TWELVE_DATA_API_KEY";}
async function reserveEod(p:EodProvider,day:string,symbols:string[]){
 const key=quotaKey(p),batch="EOD_V1:"+p+":"+day;
 const rows=await sql!`select fwios_quota.reserve_eod_batch_v1(${p},${key},${batch},${day}::date,${symbols}::text[]) gate`;
 const gate=rows[0]?.gate||{allowed:false,reason:"QUOTA_RESERVATION_FAILED"};
 return {gate,batch,key};
}
async function cancelUndispatched(p:EodProvider,key:string,batch:string){
 const done=await sql!`select fwios_quota.cancel_eod_undispatched_v1(${p},${key},${batch}) canceled`;
 return Number(done[0]?.canceled||0);
}
async function withReservedProviderCall<T>(p:EodProvider,key:string,batch:string,symbol:string,work:()=>Promise<T>):Promise<T>{
 const started=await sql!`select fwios_quota.mark_eod_dispatched_v1(${p},${key},${batch},${symbol}) ok`;
 if(started[0]?.ok!==true)throw new Error("QUOTA_DISPATCH_NOT_RESERVED");
 let value:T;
 try { value=await work(); }
 catch(e){
  const msg=e instanceof Error?e.message:"PROVIDER_UNKNOWN";
  const code=/^[A-Z0-9_]{3,110}$/.test(msg)?msg:"PROVIDER_REJECTED";
  const state=/(TIMEOUT|NETWORK_ERROR)/.test(code)?"UNKNOWN":"PROVIDER_REJECTED";
  await sql!`select fwios_quota.complete_eod_call_v1(${p},${key},${batch},${symbol},${state},${code}) ok`;
  throw e;
 }
 const completed=await sql!`select fwios_quota.complete_eod_call_v1(${p},${key},${batch},${symbol},${"SUCCESS"},${null}::text) ok`;
 if(completed[0]?.ok!==true)throw new Error("QUOTA_COMPLETION_FAILED");
 return value;
}

// Twelve Data US historical EOD is published after NY midnight on the next trading day.
async function twelveDailyFetch(uri:string):Promise<any>{
 const c=new AbortController(),timer=setTimeout(()=>c.abort(),18000);
 let res:Response,body:string;
 try {res=await fetch(uri,{headers:{Accept:"application/json"},signal:c.signal});body=await res.text();}
 catch(e){throw new Error(e instanceof Error&&e.name==="AbortError"?"TWELVE_DATA_TIMEOUT":"TWELVE_DATA_NETWORK_ERROR");}
 finally{clearTimeout(timer);}
 if(!res.ok&&res.status!==429)throw new Error("TWELVE_DATA_HTTP_"+res.status);
 let data:any;
 try{data=JSON.parse(body)}catch{
  throw new Error(res.status===429?"TWELVE_DATA_RATE_LIMIT":"TWELVE_DATA_NON_JSON_RESPONSE");
 }
 if(res.status===429||data?.status==="error"||typeof data?.code==="number"&&Number(data.code)>=400){
  const message=String(data?.message||"").toLowerCase();
  if(/per day|daily|800.{0,10}credit/.test(message))throw new Error("TWELVE_DATA_DAILY_RATE_LIMIT");
  if(/per minute|minute|limit|credit|quota|too many|rate/.test(message)||Number(data?.code)===429)
   throw new Error("TWELVE_DATA_RATE_LIMIT");
  if(/apikey|api key|invalid|unauthori/.test(message))throw new Error("TWELVE_DATA_KEY_REJECTED");
  if(/plan|premium|subscription|access/.test(message))throw new Error("TWELVE_DATA_PLAN_RESTRICTED");
  throw new Error("TWELVE_DATA_PROVIDER_REJECTED");
 }
 if(!Array.isArray(data?.values)||typeof data?.meta!=="object")throw new Error("TWELVE_DATA_MALFORMED_EOD");
 return data;
}

async function twelveFallbackRefresh(dry:boolean){
 const ny=newYorkClock(new Date());
 // Never treat the 00:00-01:14 ET interval as published EOD.
 if(!twelveFallbackWindow(ny))
  return {source:"TWELVE_DATA",skipped:true,reason:"TWELVE_EOD_OUTSIDE_RELEASE_WINDOW",database_writes:0,dry_run:dry};
 const day=previousNyBusinessDay(ny);
 if(!day)throw new Error("TWELVE_EOD_SESSION_INVALID");
 const credential=await vaultSecret("fwios_google_sheets_service_account_json");
 if(!credential)throw new Error("GOOGLE_CREDENTIAL_MISSING");
 const googleToken=await getGoogleAccessToken(JSON.parse(credential));
 const holdings=parseLiveHoldings(await readLiveHoldings(googleToken));
 const symbols=[...new Set(holdings.filter(x=>x.asset_class==="Stock").map(x=>x.asset_symbol))].sort();
 if(!symbols.length)return {source:"TWELVE_DATA",skipped:true,reason:"NO_OPEN_STOCK_HOLDINGS",database_writes:0,dry_run:dry};
 if(symbols.length>15)throw new Error("STOCK_UNIVERSE_OVER_FREE_API_CAP");
 // A full certified session from either provider needs no more API requests.
 const certifiedRows=await sql!`select distinct s.symbol from fwios.market_observations o
  join fwios.instrument_symbols s on s.instrument_id=o.instrument_id
  cross join lateral (select case when jsonb_typeof(o.raw_payload)='string'
    then (o.raw_payload #>> '{}')::jsonb else o.raw_payload end as payload) normalized
  where s.active=true and s.is_primary=true and s.symbol=any(${symbols}::text[])
   and o.session_date=${day}::date and o.observation_type='REGULAR_CLOSE'
   and o.market_status='CLOSED' and o.provider='TWELVE_DATA'
   and o.source_tier='A' and o.value_currency='USD' and o.provenance_status='PASS'
   and o.observation_value>0 and normalized.payload->>'price_only_stock_eod'='true'
    and normalized.payload->>'close_kind'='UNADJUSTED'
    and (normalized.payload->>'adjustment'='none')`;
 const certified=new Set(certifiedRows.map((x:any)=>String(x.symbol).toUpperCase()));
 if(certified.size===symbols.length)return {source:"TWELVE_DATA",skipped:true,reason:"EOD_SESSION_ALREADY_CERTIFIED",session_date:day,provider_requests_attempted:0,database_writes:0,dry_run:dry};
 if(certified.size>0)return {source:"TWELVE_DATA",skipped:true,reason:"INCOMPLETE_CERTIFIED_SESSION_REQUIRES_REVIEW",certified_count:certified.size,provider_requests_attempted:0,database_writes:0,dry_run:dry};
 if(dry)return {source:"TWELVE_DATA",skipped:true,reason:"PREFLIGHT_NO_PROVIDER_REQUEST",expected_session:day,asset_count:symbols.length,symbols,provider_requests_attempted:0,database_writes:0,dry_run:true};
 const apiKey=await vaultSecret("TWELVE_DATA_API_KEY");
 if(!apiKey||apiKey.trim().length<8)throw new Error("TWELVE_DATA_KEY_MISSING");
 const {gate,batch,key}=await reserveEod("TWELVE_DATA",day,symbols);
 if(!gate.allowed)return {source:"TWELVE_DATA",skipped:true,reason:"QUOTA_GUARD_"+gate.reason,provider_requests_attempted:0,database_writes:0,dry_run:false};
 const rows:StockEodRow[]=[];
 try {
 for(const symbol of symbols){
  const url=new URL("https://api.twelvedata.com/time_series");
  for(const [k,v] of Object.entries({symbol,interval:"1day",outputsize:"4",adjust:"none",apikey:apiKey}))url.searchParams.set(k,v);
  let row:StockEodRow;
  try {
   row=await withReservedProviderCall("TWELVE_DATA",key,batch,symbol,async()=>{
    const data=await twelveDailyFetch(url.toString());
    return parseTwelveDailyEod(data,symbol,day);
   });
  }catch(e){
   const code=e instanceof Error?e.message:"TWELVE_DATA_UNKNOWN";
   throw new Error(code+"_SYMBOL_"+symbol+"_ATTEMPT_"+(rows.length+1));
  }
  rows.push(row);
 }
 } finally {await cancelUndispatched("TWELVE_DATA",key,batch)}
 const tickers=rows.map(r=>r.symbol),closes=rows.map(r=>r.close);
 // Write typed JSONB object, never serialize it into JSONB string.
 const saved=await sql!`select x.symbol,fwios.ensure_market_observation_v1(
  fwios.resolve_instrument_id_v1(x.symbol,'Stock',null,null),
  'REGULAR_CLOSE',x.close,'USD',${day}::date,now(),'CLOSED',
  'TWELVE_DATA','A','https://api.twelvedata.com/time_series',
  'PASS',jsonb_build_object('price_only',true,'price_only_stock_eod',true,
    'provider_function','time_series','adjustment','none','close_kind','UNADJUSTED',
    'source_session_date',${day}::text),null,null
 ) observation_id from unnest(${tickers}::text[],${closes}::numeric[]) AS x(symbol,close)`;
 if(saved.length!==rows.length||saved.some((x:any)=>!x.observation_id))throw new Error("STOCK_EOD_DATABASE_PERSISTENCE_MISMATCH");
 return {source:"TWELVE_DATA",asset_count:rows.length,symbols,session_date:day,
  provider_requests_attempted:rows.length,close_kind:"UNADJUSTED",database_writes:rows.length,dry_run:false};
}

Deno.serve(async(req:Request)=>{
 if(req.method!=="POST")return new Response("Method Not Allowed",{status:405});
 if(!sql)return Response.json({ok:false,error:"DB_UNAVAILABLE"},{status:503});
 const got=req.headers.get("x-fwios-automation-token")||"",want=await vaultSecret("fwios_automation_token");
 if(!want||got.length<32||!safeEqual(got,want))return new Response("Unauthorized",{status:401});
 let b:any={};try{b=await req.json()}catch{}
 const mode=String(b?.mode||"").toUpperCase(),dry=b?.dry_run===true;
 if(!["CRYPTO","FX","TWELVE_STOCK_EOD_FALLBACK"].includes(mode))return Response.json({ok:false,error:"INVALID_MODE"},{status:400});
 try{
  const x=mode==="CRYPTO"?await cryptoRefresh(dry):mode==="FX"?await fxRefresh(dry):
   await twelveFallbackRefresh(dry);
  return Response.json({ok:true,worker:"price-market-refresh-v1",mode,...x,portfolio_writes:0,auto_trade:false});
 }catch(e){return Response.json({ok:false,worker:"price-market-refresh-v1",mode,error:String(e instanceof Error?e.message:e).slice(0,200)},{status:503});}
});
