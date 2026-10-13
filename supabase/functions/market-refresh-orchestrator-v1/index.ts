// PR4 additive QA-only Edge adapter. NOT deployed/cut over by this PR.
// JWT + independent automation-token gate; no real provider endpoints are called.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";
import {requestRefresh,driveOne,type MarketGateway,type MarketRequest,type Claim,
  type ProviderResult} from "../_shared/pr4_core.ts";
const url=Deno.env.get("SUPABASE_DB_URL");
const sql=url?postgres(url,{prepare:false,max:1}):null;
function sameHex(a:string,b:string){if(a.length!==b.length)return false;let d=0;
  for(let i=0;i<a.length;i++)d|=a.charCodeAt(i)^b.charCodeAt(i);return d===0;}
async function tokenSha(t:string){const b=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(t));
  return [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,"0")).join("");}
const db:MarketGateway={
  async cache(r){
    const x=await sql!`select fwios.pr4_cache_lookup_v1(
      ${r.flightKey},${r.signature},${r.instrumentId}::uuid,${r.providerKey},
      ${r.observationType},${r.currency},${r.sessionDate}::date,
      ${r.ttlSeconds}) v`;return x[0].v;
  },
  async enqueue(r){
    const x=await sql!`select fwios.pr4_request_market_refresh_v1(
      ${r.flightKey},${r.signature},${r.instrumentId}::uuid,
      ${r.providerKey},${r.capability},${r.endpoint},${r.observationType},
      ${r.currency},${r.sessionDate}::date,${r.priority},
      ${r.ttlSeconds},${r.fxBaseCurrency??null},${r.fxQuoteCurrency??null},
      ${r.qaOnly===true}) v`;return x[0].v;
  },
  async claim(workerId){
    const x=await sql!`select fwios.pr4_claim_market_refresh_v1(${workerId}::uuid) v`;
    return x[0].v;
  },
  async reserve(c){
    const x=await sql!`select fwios.reserve_api_quota_unified_v1(
      ${c.provider_key},${c.capability},${c.endpoint},'pr4-market-refresh',
      ${c.request_key},${c.signature},${c.priority},
      null::uuid,${c.instrument_id},${{qa_only:c.qa_only,flight_key:c.flight_key}}::jsonb
    ) v`;return x[0].v;
  },
  async dispatch(id,seconds){
    const x=await sql!`select fwios.mark_api_quota_dispatched_v1(${id}::uuid,${seconds}) v`;
    return x[0].v;
  },
  async finalize(id,status,cost,http,retry,reason,called){
    const x=await sql!`select fwios.finalize_api_quota_usage_v1(
      ${id}::uuid,${status},${cost}::numeric,${http}::integer,
      ${retry}::timestamptz,${reason},${called}) v`;
    return x[0].v;
  },
  async publish(c,worker,id,r){
    const x=await sql!`select fwios.pr4_publish_market_refresh_v1(
      ${c.flight_key},${worker}::uuid,${id}::uuid,${r.value}::numeric,
      ${r.observedAt}::timestamptz,${r.marketStatus},${r.sourceTier}) v`;
    return x[0].v;
  },
  async finish(key,worker,state,retry,reason){
    const x=await sql!`select fwios.pr4_finish_market_refresh_v1(
      ${key},${worker}::uuid,${state},${retry}::timestamptz,${reason}) v`;
    return x[0].v;
  }
};
// Mock-only provider adapter: deterministic response types via QA provider identity.
// This is the SAME ProviderTransport interface exercised by CI mock E2E.
async function qaMockProvider(c:Claim,signal:AbortSignal):Promise<ProviderResult>{
  if(!c.qa_only||!c.provider_key.startsWith("QA_PR4_"))
    return {httpStatus:503,error:"LIVE_PROVIDER_ADAPTER_NOT_ENABLED"};
  if(c.provider_key.endsWith("_429"))
    return {httpStatus:429,retryAfter:"600",error:"HTTP_429"};
  if(c.provider_key.endsWith("_500"))
    return {httpStatus:500,error:"MOCK_5XX"};
  if(c.provider_key.endsWith("_TIMEOUT")){
    await new Promise<void>((resolve,reject)=>{
      if(signal.aborted){reject(new Error("ABORTED"));return;}
      signal.addEventListener("abort",()=>reject(new Error("ABORTED")),{once:true});
    });
  }
  if(c.provider_key.endsWith("_INVALID"))
    return {httpStatus:200,value:-1,error:"INVALID_PRICE"};
  return {httpStatus:200,value:100,observedAt:new Date().toISOString(),
    marketStatus:c.observation_type==="REGULAR_CLOSE"?"LAST_CLOSE":"24X7",sourceTier:"B"};
}
Deno.serve(async(req:Request)=>{
  if(req.method!=="POST")return Response.json({error:"METHOD_NOT_ALLOWED"},{status:405});
  if(!sql||Deno.env.get("FWIOS_PR4_MOCK_ONLY")!=="true")
    return Response.json({error:"PR4_CUTOVER_OFF"},{status:503});
  const token=req.headers.get("x-fwios-automation-token")??"";
  if(token.length<32)return Response.json({error:"UNAUTHORIZED"},{status:401});
  const access=await sql`select token_sha256 from fwios.decision_refresh_automation_access
    where access_key='PR4_MARKET_REFRESH_WORKER' and active=true limit 1`;
  if(!access.length||!sameHex(await tokenSha(token),String(access[0].token_sha256)))
    return Response.json({error:"UNAUTHORIZED"},{status:401});
  try{
    const body=await req.json();
    if(body.operation==="enqueue"){
      const r=body.request as MarketRequest;
      if(r.qaOnly!==true || !r.providerKey?.toUpperCase().startsWith("QA_PR4_"))
        return Response.json({error:"QA_ONLY"},{status:403});
      return Response.json(await requestRefresh(db,r));
    }
    if(body.operation==="drain"){
      return Response.json(await driveOne(db,crypto.randomUUID(),qaMockProvider,15));
    }
    return Response.json({error:"UNKNOWN_OPERATION"},{status:400});
  }catch(e){
    return Response.json({error:"PR4_REQUEST_FAILED",reason:String(e).slice(0,180)},{status:500});
  }
});
