// FWIOS PR4: same transport-independent coordinator used by Edge and mock E2E.
// Never dispatch directly from cache/enqueue; PR3 Reserve -> Dispatch -> Finalize.
export type Priority = "P0"|"P1"|"P2"|"P3"|"P4";
export type ObservationType = "LIVE_QUOTE"|"REGULAR_CLOSE"|"PRE_MARKET"|"AFTER_HOURS"|"FX";
export type MarketRequest = {
  instrumentId:string;providerKey:string;capability:string;endpoint:string;
  observationType:ObservationType;currency:string;sessionDate:string;
  priority:Priority;adjustment:string;timeframe:string;marketSession:string;
  parameters:Record<string,string|number|boolean|null>;
  ttlSeconds:number; fxBaseCurrency?:string;fxQuoteCurrency?:string; qaOnly?:boolean;
};
export type Identity = MarketRequest & {flightKey:string;signature:string};
export type CacheResult = {status:string;observation_id?:string;observed_at?:string;reason?:string};
export type Claim = {
  status:string;flight_key:string;signature:string;provider_key:string;capability:string;
  endpoint:string;instrument_id:string;observation_type:ObservationType;currency:string;
  session_date:string;priority:Priority;ttl_seconds:number;attempt_number:number;
  request_key:string;qa_only:boolean;
};
export type QuotaResult = {allowed:boolean;usage_id?:string;reason?:string;retry_after?:string};
export type FinalResult = {ok:boolean;changed?:boolean;reason?:string};
export type ProviderResult = {
  httpStatus:number;retryAfter?:string|null;value?:number;observedAt?:string;
  marketStatus?:string;sourceTier?:string;error?:string;
};
export interface MarketGateway {
  cache(r:Identity):Promise<CacheResult>;
  enqueue(r:Identity):Promise<CacheResult>;
  claim(workerId:string):Promise<Claim|{status:"EMPTY"}>;
  reserve(c:Claim):Promise<QuotaResult>;
  dispatch(usageId:string,timeoutSeconds:number):Promise<QuotaResult>;
  finalize(usageId:string,status:"SUCCESS"|"PROVIDER_ERROR"|"BILLABLE_FAILURE"|"RELEASED",
    actual:number|null,httpStatus:number|null,retryAfter:string|null,reason:string|null,providerCalled:boolean):Promise<FinalResult>;
  publish(c:Claim,workerId:string,usageId:string,result:ProviderResult):Promise<{ok:boolean;observation_id?:string;reason?:string}>;
  finish(key:string,workerId:string,status:"DEFERRED"|"FAILED"|"UNCERTAIN",
    retryAfter:string|null,reason:string):Promise<{ok:boolean;reason?:string}>;
}
export type ProviderTransport = (claim:Claim,signal:AbortSignal)=>Promise<ProviderResult>;

function stableJson(x:unknown):string {
  if(Array.isArray(x)) return "["+x.map(stableJson).join(",")+"]";
  if(x!==null&&typeof x==="object"){
    const o=x as Record<string,unknown>;
    return "{"+Object.keys(o).sort().map(k=>JSON.stringify(k)+":"+stableJson(o[k])).join(",")+"}";
  }
  return JSON.stringify(x);
}
async function digest(x:string):Promise<string>{
  const b=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(x));
  return [...new Uint8Array(b)].map(n=>n.toString(16).padStart(2,"0")).join("");
}
export async function canonicalize(req:MarketRequest):Promise<Identity>{
  const x:MarketRequest={
    ...req,
    instrumentId:req.instrumentId.toLowerCase(),
    providerKey:req.providerKey.trim().toUpperCase(),
    capability:req.capability.trim().toUpperCase(),
    endpoint:req.endpoint.trim().toUpperCase(),
    currency:req.currency.trim().toUpperCase(),
    observationType:req.observationType,
    priority:req.priority,
    adjustment:req.adjustment.trim().toUpperCase(),
    timeframe:req.timeframe.trim().toUpperCase(),
    marketSession:req.marketSession.trim().toUpperCase(),
    parameters:{...req.parameters},
    fxBaseCurrency:req.fxBaseCurrency?.toUpperCase(),
    fxQuoteCurrency:req.fxQuoteCurrency?.toUpperCase()
  };
  if(!/^[0-9a-f]{8}-[0-9a-f-]{27,}$/.test(x.instrumentId)
    || !/^[A-Z0-9_]{3,64}$/.test(x.providerKey)
    || !/^[A-Z0-9_]{2,64}$/.test(x.endpoint)
    || !/^[A-Z0-9_]{2,64}$/.test(x.capability)
    || !/^[A-Z]{3,8}$/.test(x.currency)
    || !/^\d{4}-\d{2}-\d{2}$/.test(x.sessionDate)
    || !["P0","P1","P2","P3","P4"].includes(x.priority)
    || !["LIVE_QUOTE","REGULAR_CLOSE","PRE_MARKET","AFTER_HOURS","FX"].includes(x.observationType)
    || !Number.isInteger(x.ttlSeconds)||x.ttlSeconds<1||x.ttlSeconds>259200
    || !x.adjustment||!x.timeframe||!x.marketSession
    || (x.observationType==="FX")!==(!!x.fxBaseCurrency&&!!x.fxQuoteCurrency)
    || (x.qaOnly===true&&!x.providerKey.startsWith("QA_PR4_"))) throw new Error("INVALID_CANONICAL_REQUEST");
  const core={
    instrumentId:x.instrumentId,providerKey:x.providerKey,capability:x.capability,
    endpoint:x.endpoint,observationType:x.observationType,currency:x.currency,
    sessionDate:x.sessionDate,adjustment:x.adjustment,timeframe:x.timeframe,
    marketSession:x.marketSession,parameters:x.parameters,
    fxBaseCurrency:x.fxBaseCurrency??null,fxQuoteCurrency:x.fxQuoteCurrency??null
  };
  const repr=stableJson(core);
  return {...x,flightKey:await digest("FWIOS_PR4_FLIGHT_V1:"+repr),
    signature:await digest("FWIOS_PR4_SIGNATURE_V1:"+repr)};
}
export async function requestRefresh(db:MarketGateway,request:MarketRequest){
  const id=await canonicalize(request);
  const cached=await db.cache(id);
  if(cached.status==="FRESH"||cached.status==="LAST_CLOSE"){
    return {...cached,cache_hit:true,new_provider_calls:0,new_reservations:0,flight_key:id.flightKey};
  }
  if(cached.status!=="MISS")return {status:"BLOCKED",reason:"CACHE_LOOKUP_ERROR"};
  const r=await db.enqueue(id);
  return {...r,cache_hit:false,new_provider_calls:0,new_reservations:0,flight_key:id.flightKey};
}
export function retryAfterToIso(value:string|null|undefined,now:Date):string|null{
  if(!value)return null;
  const seconds=Number(value);
  const ts=Number.isFinite(seconds)&&seconds>=0
    ?now.getTime()+seconds*1000:Date.parse(value);
  if(!Number.isFinite(ts))return null;
  return new Date(Math.min(now.getTime()+86400000,Math.max(now.getTime()+30000,ts))).toISOString();
}
function after(now:Date,seconds:number):string{return new Date(now.getTime()+seconds*1000).toISOString();}
function quotaRetry(reason:string,claimedAt:Date,retryAfter?:string){
  const hard=reason.includes("UNVERIFIED")||reason.includes("DISABLED")
    ||reason.includes("NOT_CONFIGURED")||reason.includes("INVALID");
  return hard?null:retryAfterToIso(retryAfter,claimedAt)??after(claimedAt,900);
}
export async function driveOne(db:MarketGateway,workerId:string,transport:ProviderTransport,
  timeoutSeconds=15,now:()=>Date=()=>new Date()){
  const c=await db.claim(workerId);
  if(c.status!=="CLAIMED")return {status:c.status,provider_calls:0};
  const claim=c as Claim;
  const gate=await db.reserve(claim);
  if(!gate.allowed||!gate.usage_id){
    const due=quotaRetry(gate.reason??"QUOTA_DENIED",now(),gate.retry_after);
    const state=due?"DEFERRED":"FAILED";
    await db.finish(claim.flight_key,workerId,state,due,gate.reason??"QUOTA_DENIED");
    return {status:"QUOTA_BLOCKED",reason:gate.reason,provider_calls:0};
  }
  const usageId=gate.usage_id;
  const mark=await db.dispatch(usageId,timeoutSeconds);
  if(!mark.allowed){
    const release=await db.finalize(usageId,"RELEASED",0,null,null,"PRE_DISPATCH_DENIED",false);
    await db.finish(claim.flight_key,workerId,
      release.ok?"FAILED":"UNCERTAIN",null,"DISPATCH_DENIED");
    return {status:"DISPATCH_DENIED",provider_calls:0};
  }
  // DISPATCHED is a billing boundary: no credit refunds after this point.
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),timeoutSeconds*1000);
  let result:ProviderResult;
  try {result=await transport(claim,controller.signal);}
  catch(e){result={httpStatus:0,error:controller.signal.aborted?"TIMEOUT":String(e)};}
  finally{clearTimeout(timer);}
  const status=result.httpStatus;
  const valid=status>=200&&status<300
    && Number.isFinite(result.value)&&Number(result.value)>0
    && !!result.observedAt&&Number.isFinite(Date.parse(result.observedAt))
    && ["OPEN","CLOSED","24X7","LAST_CLOSE"].includes(result.marketStatus??"")
    && !(claim.observation_type==="LIVE_QUOTE"
      && !["OPEN","24X7"].includes(result.marketStatus??""))
    && ["A","B","C"].includes(result.sourceTier??"");
  const retry= status===429
    ?retryAfterToIso(result.retryAfter,now())??after(now(),900)
    :status>=500||status===0 ? after(now(),300):null;
  const final=await db.finalize(usageId,valid?"SUCCESS":"PROVIDER_ERROR",null,
    status>0?status:null,retry,valid?null:(result.error??"INVALID_PROVIDER_RESPONSE"),true);
  if(!final.ok){
    await db.finish(claim.flight_key,workerId,"UNCERTAIN",null,"FINALIZATION_UNCERTAIN");
    return {status:"UNCERTAIN",provider_calls:1};
  }
  if(valid){
    const published=await db.publish(claim,workerId,usageId,result);
    if(published.ok)return {status:"READY",observation_id:published.observation_id,provider_calls:1};
    await db.finish(claim.flight_key,workerId,"UNCERTAIN",null,"PUBLICATION_FAILED_AFTER_BILLING");
    return {status:"UNCERTAIN",provider_calls:1};
  }
  await db.finish(claim.flight_key,workerId,retry?"DEFERRED":"FAILED",
    retry,result.error??(status===429?"HTTP_429":"PROVIDER_FAILURE"));
  return {status:status===429?"RATE_LIMITED":status===0?"TIMEOUT":"PROVIDER_ERROR",
    provider_calls:1,retry_after:retry};
}
// Fallback is explicitly another request/flight and must get its OWN provider policy,
// quota reservation and dispatch. It never bypasses PR3 by reusing the failed permit.
export async function requestFallback(db:MarketGateway,failed:MarketRequest,
  alternate:{providerKey:string;endpoint:string;capability:string}){
  if(alternate.providerKey.toUpperCase()===failed.providerKey.toUpperCase())
    throw new Error("FALLBACK_MUST_USE_OTHER_PROVIDER");
  return requestRefresh(db,{...failed,...alternate});
}
