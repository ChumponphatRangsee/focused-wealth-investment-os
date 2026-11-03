/**
 * Manual provider entitlement probe. NOT invoked by CI, Cron or Edge Function.
 * One read-only HTTP request per held stock (max 4). Never prints the key,
 * request URL, raw provider response, or unsolicited provider error messages.
 * Usage:
 *   deno run --allow-env=TWELVE_DATA_API_KEY \
 *     --allow-net=api.twelvedata.com tests/price/manual_twelve_provider_probe.ts
 *
 * May consume up to 4 of your Twelve Data API credits.
 */
import {parseTwelveDailyEod,previousNyBusinessDay,twelveFallbackWindow}
 from "../../supabase/functions/price-market-refresh-v1/twelve-eod-guards.ts";

const key = Deno.env.get("TWELVE_DATA_API_KEY")?.trim();
if(!key || key.length<8) {
 console.error("PROBE_KEY_UNAVAILABLE: set TWELVE_DATA_API_KEY in the local process environment");
 Deno.exit(2);
}
const dateParts = new Intl.DateTimeFormat("en-US",{
 timeZone:"America/New_York",year:"numeric",month:"2-digit",day:"2-digit",
 weekday:"short",hour:"2-digit",minute:"2-digit",hourCycle:"h23"
}).formatToParts(new Date());
const parts = Object.fromEntries(dateParts.map(p=>[p.type,p.value]));
const ny = {
 day:parts.year+"-"+parts.month+"-"+parts.day,
 weekday:parts.weekday,
 hour:Number(parts.hour),
 minute:Number(parts.minute)
};
const session=previousNyBusinessDay(ny);
if(!session||!twelveFallbackWindow(ny)) {
 console.error("PROBE_OUTSIDE_TWELVE_EOD_WINDOW: only 01:15-01:59 New York weekdays");
 Deno.exit(2);
}
const symbols=["MSFT","NVDA","TLN","TTWO"] as const;
const checks:unknown[]=[];
for(const symbol of symbols){
 const url=new URL("https://api.twelvedata.com/time_series");
 for(const [k,v] of Object.entries({
  symbol,interval:"1day",outputsize:"4",adjust:"none",apikey:key
 })) url.searchParams.set(k,v);
 const controller=new AbortController();
 const timeout=setTimeout(()=>controller.abort(),15000);
 let outcome:Record<string,unknown>={symbol,status:"NOT_ATTEMPTED"};
 try {
  const response=await fetch(url,{headers:{Accept:"application/json"},
   signal:controller.signal});
  let data:unknown=null;
  try{data=await response.json()}catch {}
  const report=data && typeof data==="object" && !Array.isArray(data)
   ?data as Record<string,unknown>:null;
  outcome={
   symbol,
   http_status:response.status,
   provider_status:typeof report?.status==="string"?report.status:"UNKNOWN",
   provider_code:Number.isSafeInteger(report?.code)?report?.code:null,
   credits_used:Number(response.headers.get("api-credits-used"))||null,
   credits_left:Number(response.headers.get("api-credits-left"))||null
  };
  if(response.ok&&report?.status!=="error"){
   try{
    const value=parseTwelveDailyEod(data,symbol,session);
    outcome.status="VALID_EOD";
    outcome.session_date=value.session_date;
    outcome.close_usd=value.close;
   }catch(error){
    outcome.status=error instanceof Error &&
     /^TWELVE_DATA_[A-Z0-9_]+$/.test(error.message)
      ?error.message:"UNEXPECTED_RESPONSE";
   }
  }else{
   outcome.status=response.status===429?"PROVIDER_HTTP_429":"PROVIDER_REJECTED";
  }
 }catch(error){
  outcome.status=error instanceof Error&&error.name==="AbortError"?
   "PROBE_TIMEOUT":"PROBE_NETWORK_ERROR";
 }finally{
  clearTimeout(timeout);
 }
 checks.push(outcome);
 if(outcome.status!=="VALID_EOD")break; // prevent avoidable additional credit use
}
console.log(JSON.stringify({
 mode:"READ_ONLY_MANUAL_NO_DATABASE_WRITES",ny_day:ny.day,target_session:session,
 attempted:checks.length,all_valid:checks.length===4&&checks.every(
  x=>(x as Record<string,unknown>).status==="VALID_EOD"),
 checks
},null,2));
