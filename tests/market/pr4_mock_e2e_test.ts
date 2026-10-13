// Deterministic offline E2E against SAME pr4_core imported by Edge adapter.
// No API keys, network calls, Supabase connection, transactions or real holdings.
import {test} from "node:test";
import assert from "node:assert/strict";
import {canonicalize,requestRefresh,driveOne,requestFallback,
  type MarketGateway,type MarketRequest,type Identity,type CacheResult,
  type Claim,type QuotaResult,type FinalResult,type ProviderResult} from
  "../../supabase/functions/_shared/pr4_core.ts";

type Flight={id:Identity;status:string;attempt:number;worker?:string;retry?:string;};
class MockGateway implements MarketGateway {
  flights=new Map<string,Flight>();
  cacheRows=new Map<string,CacheResult>();
  ledgers=new Map<string,{status:string;cost:number;key:string;provider:string}>();
  calls=0;reserved=0;dispatches=0;finalized=0;
  remaining=100;protected=0;mockPolicy=true;
  async cache(r:Identity){return this.cacheRows.get(r.flightKey)??{status:"MISS"};}
  async enqueue(r:Identity){
    const prev=this.flights.get(r.flightKey);
    if(prev)return {status:prev.status==="RUNNING"?"JOIN":prev.status};
    this.flights.set(r.flightKey,{id:r,status:"QUEUED",attempt:0});
    return {status:"QUEUED"};
  }
  async claim(worker:string):Promise<Claim|{status:"EMPTY"}>{
    const due=[...this.flights.values()].filter(f=>
      f.status==="QUEUED"||(f.status==="DEFERRED"&&Date.parse(f.retry??"")<=Date.now()));
    due.sort((a,b)=>a.id.priority.localeCompare(b.id.priority));
    const f=due[0];if(!f)return {status:"EMPTY"};
    f.status="RUNNING";f.worker=worker;f.attempt++;
    const r=f.id;
    return {status:"CLAIMED",flight_key:r.flightKey,signature:r.signature,
      provider_key:r.providerKey,capability:r.capability,endpoint:r.endpoint,
      instrument_id:r.instrumentId,observation_type:r.observationType,
      currency:r.currency,session_date:r.sessionDate,priority:r.priority,
      ttl_seconds:r.ttlSeconds,qa_only:r.qaOnly===true,
      attempt_number:f.attempt,request_key:`PR4:${r.flightKey}:${f.attempt}`};
  }
  async reserve(c:Claim):Promise<QuotaResult>{
    if(!this.mockPolicy)return {allowed:false,reason:"VENDOR_ENTITLEMENT_UNVERIFIED"};
    if(this.remaining<=0)return {allowed:false,reason:"DAY_CREDITS_EXHAUSTED"};
    if(c.priority!=="P0"&&this.remaining-1<this.protected)
      return {allowed:false,reason:"P0_CAPACITY_PROTECTED"};
    if([...this.ledgers.values()].some(l=>l.key===c.request_key))
      return {allowed:false,reason:"IDEMPOTENT_REPLAY_NO_NEW_CALL"};
    const id="usage-"+(++this.reserved);
    this.ledgers.set(id,{status:"RESERVED",cost:1,key:c.request_key,provider:c.provider_key});
    this.remaining--;
    return {allowed:true,usage_id:id};
  }
  async dispatch(id:string,_seconds:number):Promise<QuotaResult>{
    const l=this.ledgers.get(id);if(!l||l.status!=="RESERVED")return {allowed:false};
    l.status="DISPATCHED";this.dispatches++;return {allowed:true,usage_id:id};
  }
  async finalize(id:string,status:string,_actual:number|null,_http:number|null,
    _retry:string|null,_reason:string|null,called:boolean):Promise<FinalResult>{
    const l=this.ledgers.get(id);
    if(!l||(!called&&l.status!=="RESERVED")||(called&&l.status!=="DISPATCHED"))
      return {ok:false};
    l.status=status;
    if(!called){this.remaining++;}else{this.finalized++;}
    return {ok:true,changed:true};
  }
  async publish(c:Claim,worker:string,id:string,r:ProviderResult){
    const f=this.flights.get(c.flight_key),l=this.ledgers.get(id);
    if(!f||f.worker!==worker||l?.status!=="SUCCESS"||l.key!==c.request_key)
      return {ok:false,reason:"PR3_SUCCESS_PROOF_MISSING"};
    f.status="READY";this.cacheRows.set(c.flight_key,{
      status:c.observation_type==="REGULAR_CLOSE"?"LAST_CLOSE":"FRESH",
      observation_id:"observation-"+c.flight_key,observed_at:r.observedAt});
    return {ok:true,observation_id:"observation-"+c.flight_key};
  }
  async finish(key:string,worker:string,status:"DEFERRED"|"FAILED"|"UNCERTAIN",
    retry:string|null,_reason:string){
    const f=this.flights.get(key);
    if(!f||f.worker!==worker)return {ok:false};
    f.status=status;f.retry=retry??undefined;
    return {ok:true};
  }
}
const base:MarketRequest={
 instrumentId:"9bcd074c-3d58-4433-a7d3-c11144444444",providerKey:"QA_PR4_OK",
 capability:"MARKET_PRICE",endpoint:"SIMPLE_PRICE",observationType:"LIVE_QUOTE",
 currency:"THB",sessionDate:"2026-10-13",priority:"P4",
 adjustment:"NONE",timeframe:"SPOT",marketSession:"24X7",
 parameters:{lastUpdated:true,currency:"THB"},ttlSeconds:45,qaOnly:true
};
const mockOk=async (_c:Claim,_signal:AbortSignal):Promise<ProviderResult>=>({
 httpStatus:200,value:100,marketStatus:"24X7",sourceTier:"B",
 observedAt:new Date().toISOString()
});
test("20 identical callers => one flight, one PR3 dispatch, cache hits cost zero",async()=>{
 const db=new MockGateway();
 const results=await Promise.all(Array.from({length:20},()=>requestRefresh(db,base)));
 assert.equal(db.flights.size,1);assert.equal(results.filter(r=>r.status==="QUEUED").length,1);
 assert.equal(db.reserved,0);assert.equal(db.dispatches,0);
 const one=await driveOne(db,"w1",async(c,s)=>{db.calls++;return mockOk(c,s);});
 assert.equal(one.status,"READY");assert.equal(db.calls,1);assert.equal(db.reserved,1);
 assert.equal(db.dispatches,1);
 const cached=await Promise.all(Array.from({length:20},()=>requestRefresh(db,base)));
 assert.equal(cached.every(r=>r.cache_hit===true&&r.status==="FRESH"),true);
 assert.equal(new Set(cached.map(r=>r.observation_id)).size,1);
 assert.equal(db.reserved,1);assert.equal(db.calls,1);
});
test("semantic isolation: currency, session, adjustment, endpoint, instrument",async()=>{
 const db=new MockGateway();
 await Promise.all([
  base,{...base,currency:"USD"},{...base,sessionDate:"2026-10-12"},
  {...base,adjustment:"SPLIT"},{...base,endpoint:"QUOTE"},
  {...base,instrumentId:"9bcd074c-3d58-4433-a7d3-c22222222222"}
 ].map(r=>requestRefresh(db,r as MarketRequest)));
 assert.equal(db.flights.size,6);
 const a=await canonicalize(base),b=await canonicalize({...base,parameters:{currency:"THB",lastUpdated:true}});
 assert.equal(a.flightKey,b.flightKey,"parameter ordering must canonicalize");
});
test("P0 priority and protected reserve preserve one last credit under P4 pressure",async()=>{
 const db=new MockGateway();db.remaining=2;db.protected=1;
 await requestRefresh(db,{...base,parameters:{job:1},priority:"P4"});
 await requestRefresh(db,{...base,parameters:{job:2},priority:"P4"});
 await requestRefresh(db,{...base,parameters:{job:3},priority:"P0"});
 const first=await driveOne(db,"w0",async(c,s)=>{db.calls++;return mockOk(c,s);});
 assert.equal(first.status,"READY");assert.equal(db.calls,1);
 await driveOne(db,"w4",async(c,s)=>{db.calls++;return mockOk(c,s);});
 const blocked=await driveOne(db,"w5",async(c,s)=>{db.calls++;return mockOk(c,s);});
 assert.equal(blocked.status,"QUOTA_BLOCKED");
 assert.equal(blocked.reason,"P0_CAPACITY_PROTECTED");assert.equal(db.calls,2);
});
test("HTTP 429 charges once, honors Retry-After and stops re-dispatch",async()=>{
 const db=new MockGateway();
 await requestRefresh(db,{...base,providerKey:"QA_PR4_429"});
 const result=await driveOne(db,"w429",async()=>{db.calls++;
   return {httpStatus:429,retryAfter:"600",error:"RATE_LIMIT"};});
 assert.equal(result.status,"RATE_LIMITED");assert.equal(db.calls,1);
 assert.equal((await driveOne(db,"later",mockOk)).status,"EMPTY");
 assert.equal(db.finalized,1);assert.ok(Date.parse(result.retry_after!)>Date.now());
});
test("timeout/provider 5xx conservatively finalized and not immediate retry",async()=>{
 for(const response of [
  async()=>{throw Error("NETWORK_TIMEOUT");},
  async()=>({httpStatus:503,error:"MOCK_5XX"})
 ]){
  const db=new MockGateway();await requestRefresh(db,base);
  const r=await driveOne(db,"w",async()=>{db.calls++;return response();});
  assert.equal(["TIMEOUT","PROVIDER_ERROR"].includes(r.status),true);
  assert.equal(db.finalized,1);assert.equal(db.calls,1);
  assert.equal((await driveOne(db,"w2",mockOk)).status,"EMPTY");
 }
});
test("quota denied, provider never called",async()=>{
 const db=new MockGateway();db.mockPolicy=false;
 await requestRefresh(db,base);
 const r=await driveOne(db,"deny",async()=>{db.calls++;return mockOk({} as Claim,new AbortController().signal);});
 assert.equal(r.status,"QUOTA_BLOCKED");assert.equal(db.calls,0);assert.equal(db.dispatches,0);
});
test("fallback gets distinct flight/permit and never reuses primary quota",async()=>{
 const db=new MockGateway();db.mockPolicy=false;
 const primary=await requestRefresh(db,base);assert.equal(primary.status,"QUEUED");
 const denied=await driveOne(db,"p",mockOk);assert.equal(denied.status,"QUOTA_BLOCKED");
 db.mockPolicy=true;
 const fb=await requestFallback(db,base,{providerKey:"QA_PR4_ALT",endpoint:"QUOTE",capability:"MARKET_PRICE"});
 assert.notEqual(fb.flight_key,primary.flight_key);
 const ok=await driveOne(db,"f",async(c,s)=>{db.calls++;return mockOk(c,s);});
 assert.equal(ok.status,"READY");assert.equal(db.calls,1);assert.equal(db.reserved,1);
});
test("last close remains explicitly LAST_CLOSE",async()=>{
 const db=new MockGateway();const req={...base,observationType:"REGULAR_CLOSE" as const};
 await requestRefresh(db,req);await driveOne(db,"close",mockOk);
 const r=await requestRefresh(db,req);
 assert.equal(r.status,"LAST_CLOSE");assert.equal(r.cache_hit,true);
});
