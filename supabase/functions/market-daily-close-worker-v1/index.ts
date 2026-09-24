import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const dbUrl=Deno.env.get("SUPABASE_DB_URL");
const sql=dbUrl?postgres(dbUrl,{prepare:false,max:1}):null;
const WORKER="market-daily-close-worker-v1";

async function sha256Hex(s:string){
  const b=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
  return Array.from(new Uint8Array(b)).map(x=>x.toString(16).padStart(2,"0")).join("");
}
function safeEqual(a:string,b:string){
  if(a.length!==b.length)return false; let d=0;
  for(let i=0;i<a.length;i++) d|=a.charCodeAt(i)^b.charCodeAt(i);
  return d===0;
}
async function secret(name:string|null|undefined){
  if(!name)return null;
  const env=Deno.env.get(name); if(env)return env;
  try{
    const r=await sql!`select decrypted_secret from vault.decrypted_secrets where name=${name} limit 1`;
    return r.length?String(r[0].decrypted_secret):null;
  }catch{return null;}
}
async function provider(){
  const r=await sql!`select provider_key,active,readiness_status,source_tier,secret_name,config
    from fwios.decision_refresh_provider_registry where provider_key='TWELVE_DATA' limit 1`;
  return r[0]??null;
}
async function fetchJson(url:string){
  const c=new AbortController(),t=setTimeout(()=>c.abort(),15000);
  try{
    const res=await fetch(url,{signal:c.signal,headers:{"User-Agent":"FWIOS/1.0 daily-close"}});
    const body=await res.text(); let d:any=body;
    try{d=JSON.parse(body);}catch{}
    if(!res.ok) throw new Error(`TWELVE_DATA_HTTP_${res.status}_${typeof d==="string"?d.slice(0,180):JSON.stringify(d).slice(0,180)}`);
    return d;
  }finally{clearTimeout(t);}
}
function exactRow(d:any,sd:string){
  const rows=Array.isArray(d?.values)?d.values:[];
  return rows.find((x:any)=>String(x?.datetime||"").slice(0,10)===sd)||null;
}
function latestDate(d:any){
  const rows=Array.isArray(d?.values)?d.values:[];
  return rows.map((x:any)=>String(x?.datetime||"").slice(0,10)).filter(Boolean).sort().reverse()[0]||null;
}
async function markUsage(gate:any,outcome:string,meta:any={}){
  const id=String(gate?.usage_id||"");
  if(!id)return;
  await sql!`update fwios.market_daily_close_api_usage
    set outcome=${outcome},metadata=metadata||${meta}
    where usage_id=${id}::uuid`;
}
async function processJob(job:any,p:any,key:string){
  const rr=await sql!`select session_date from fwios.market_daily_close_runs where run_id=${job.run_id}::uuid limit 1`;
  if(!rr.length) return {status:"BLOCKED",reason:"RUN_NOT_FOUND"};
  const rawDate=rr[0].session_date; const sd=rawDate instanceof Date?rawDate.toISOString().slice(0,10):(String(rawDate).match(/\\d{4}-\\d{2}-\\d{2}/)?.[0]||String(rawDate).slice(0,10));

  const gateRows=await sql!`select fwios.reserve_market_daily_close_api_call_v1(
    'TWELVE_DATA',${job.ticker},${WORKER},${{run_id:job.run_id,job_id:job.job_id,session_date:sd}}::jsonb
  ) gate`;
  const gate=gateRows[0]?.gate||{allowed:false,reason:"QUOTA_RESERVATION_FAILED"};
  if(!gate.allowed){
    return {status:"RETRY",reason:gate.reason||"QUOTA_BLOCK",next_retry_minutes:2,quota:gate};
  }

  const url=`https://api.twelvedata.com/time_series?symbol=${encodeURIComponent(job.ticker)}&interval=1day&date=${encodeURIComponent(sd)}&adjust=none&apikey=${encodeURIComponent(key)}`;
  try{
    const d=await fetchJson(url);
    if(d?.status==="error"){
      await markUsage(gate,"ERROR",{code:d?.code??null,message:String(d?.message||"").slice(0,180)});
      return {status:"RETRY",reason:"TWELVE_DATA_API_ERROR",next_retry_minutes:30,detail:String(d?.message||"").slice(0,180),quota:gate};
    }
    const row=exactRow(d,sd);
    if(!row){
      await markUsage(gate,"NO_EXACT_SESSION",{requested_session_date:sd,latest_date:latestDate(d)});
      return {status:"RETRY",reason:"EOD_NOT_READY_OR_MARKET_CLOSED",next_retry_minutes:30,requested_session_date:sd,latest_date:latestDate(d),quota:gate};
    }
    const close=Number(row.close);
    if(!(close>0)){
      await markUsage(gate,"INVALID_PRICE",{requested_session_date:sd});
      return {status:"BLOCKED",reason:"INVALID_CLOSE_PRICE",quota:gate};
    }
    const meta=d?.meta??{};
    await sql!`insert into fwios.market_daily_closes(
      asset_symbol,session_date,close_price,currency,exchange,primary_provider,source_url,source_tier,
      retrieved_at,verification_status,provenance_status,raw_payload,updated_at
    ) values(
      ${job.ticker},${sd}::date,${close},${meta?.currency??null},${meta?.exchange??null},
      'TWELVE_DATA','https://api.twelvedata.com/time_series','A',now(),'PRIMARY_ONLY','PASS',
      ${{meta,row,interval:"1day",adjust:"none"}}::jsonb,now()
    )
    on conflict(asset_symbol,session_date) do update set
      close_price=excluded.close_price,
      currency=excluded.currency,
      exchange=excluded.exchange,
      primary_provider=excluded.primary_provider,
      source_url=excluded.source_url,
      source_tier=excluded.source_tier,
      retrieved_at=excluded.retrieved_at,
      provenance_status='PASS',
      raw_payload=excluded.raw_payload,
      updated_at=now()`;
    await markUsage(gate,"PASS",{session_date:sd,close});
    return {status:"PASS",session_date:sd,close,provider:"TWELVE_DATA",verification_status:"PRIMARY_ONLY",quota:gate};
  }catch(e){
    await markUsage(gate,"ERROR",{error:(e instanceof Error?e.message:String(e)).slice(0,240)});
    throw e;
  }
}

Deno.serve(async(req:Request)=>{
  if(!sql||!dbUrl)return Response.json({error:"DB_UNAVAILABLE"},{status:503});
  if(req.method!=="POST")return new Response("Method Not Allowed",{status:405});

  const tok=req.headers.get("x-fwios-automation-token")||"";
  const access=await sql`select token_sha256 from fwios.decision_refresh_automation_access
    where access_key='DECISION_REFRESH_WORKER' and active=true limit 1`;
  if(tok.length<32||!access.length||!safeEqual(await sha256Hex(tok),String(access[0].token_sha256)))
    return new Response("Unauthorized",{status:401});

  const p=await provider();
  const key=await secret(p?.secret_name);
  if(!p||p.active!==true||p.readiness_status!=="READY"||p.source_tier!=="A"||!key)
    return Response.json({error:"TWELVE_DATA_NOT_READY"},{status:503});

  const pol=await sql`select worker_batch from fwios.market_daily_close_policy
    where provider_key='TWELVE_DATA' and active=true limit 1`;
  const batch=Math.min(8,Math.max(1,Number(pol[0]?.worker_batch||8)));
  const jobs=await sql`select * from fwios.claim_market_daily_close_jobs_v1(${batch})`;

  let passed=0,retried=0,blocked=0,dead=0;
  const touched=new Set<string>();
  const results:any[]=[];

  for(const job of jobs){
    touched.add(String(job.run_id));
    try{
      const r:any=await processJob(job,p,key);
      if(r.status==="PASS"){
        await sql`update fwios.market_daily_close_jobs set status='PASS',output=${r},last_error=null,
          completed_at=now(),next_retry_at=null,updated_at=now() where job_id=${job.job_id}::uuid`;
        passed++;
      }else if(r.status==="RETRY" && Number(job.attempts||0)<Number(job.max_attempts||4)){
        const mins=Math.max(2,Number(r.next_retry_minutes||30));
        await sql`update fwios.market_daily_close_jobs set status='RETRY',output=${r},last_error=${r.reason||"RETRY"},
          next_retry_at=now()+make_interval(mins=>${mins}),updated_at=now() where job_id=${job.job_id}::uuid`;
        retried++;
      }else{
        const finalStatus=Number(job.attempts||0)>=Number(job.max_attempts||4)?"DEAD_LETTER":"BLOCKED";
        await sql`update fwios.market_daily_close_jobs set status=${finalStatus},output=${r},
          last_error=${r.reason||"BLOCKED"},completed_at=now(),next_retry_at=null,updated_at=now()
          where job_id=${job.job_id}::uuid`;
        if(finalStatus==="DEAD_LETTER")dead++; else blocked++;
      }
      results.push({ticker:job.ticker,...r});
    }catch(e){
      const er=e instanceof Error?e.message:String(e);
      if(Number(job.attempts||0)>=Number(job.max_attempts||4)){
        await sql`update fwios.market_daily_close_jobs set status='DEAD_LETTER',last_error=${er.slice(0,240)},
          completed_at=now(),updated_at=now() where job_id=${job.job_id}::uuid`; dead++;
      }else{
        await sql`update fwios.market_daily_close_jobs set status='RETRY',last_error=${er.slice(0,240)},
          next_retry_at=now()+interval '30 minutes',updated_at=now() where job_id=${job.job_id}::uuid`; retried++;
      }
      results.push({ticker:job.ticker,status:"ERROR",error:er.slice(0,240)});
    }
  }

  for(const rid of touched) await sql`select fwios.refresh_market_daily_close_run_status_v1(${rid}::uuid)`;

  return Response.json({
    ok:true,worker:WORKER,version:3,claimed:jobs.length,passed,retried,blocked,dead,
    provider:"TWELVE_DATA",batch_limit:batch,display_source_of_truth:true,
    decision_verification:"SELECTIVE_ALPHA_VANTAGE",auto_trade:false,results
  });
});
