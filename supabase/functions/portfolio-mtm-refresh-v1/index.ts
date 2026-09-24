import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const dbUrl=Deno.env.get("SUPABASE_DB_URL");
const sql=dbUrl?postgres(dbUrl,{prepare:false,max:1}):null;
const WORKER="portfolio-mtm-refresh-v1";

async function sha256Hex(s:string){
  const b=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));
  return Array.from(new Uint8Array(b)).map(x=>x.toString(16).padStart(2,"0")).join("");
}
function safeEqual(a:string,b:string){
  if(a.length!==b.length)return false;let d=0;
  for(let i=0;i<a.length;i++)d|=a.charCodeAt(i)^b.charCodeAt(i);
  return d===0;
}
async function secret(name:string|null|undefined){
  if(!name)return null;
  const e=Deno.env.get(name); if(e)return e;
  try{
    const r=await sql!`select decrypted_secret from vault.decrypted_secrets where name=${name} limit 1`;
    return r.length?String(r[0].decrypted_secret):null;
  }catch{return null;}
}
async function fetchJson(url:string,headers:Record<string,string>={}){
  const c=new AbortController(),t=setTimeout(()=>c.abort(),15000);
  try{
    const r=await fetch(url,{headers:{...headers,"User-Agent":"FWIOS/1.0 portfolio-mtm"},signal:c.signal});
    const body=await r.text();let d:any=body;
    try{d=JSON.parse(body);}catch{}
    if(!r.ok)throw new Error(`HTTP_${r.status}_${typeof d==="string"?d.slice(0,180):JSON.stringify(d).slice(0,180)}`);
    return d;
  }finally{clearTimeout(t);}
}
async function reserve(symbol:string,meta:any={}){
  const r=await sql!`select fwios.reserve_market_daily_close_api_call_v1(
    'TWELVE_DATA',${symbol},${WORKER},${meta}::jsonb
  ) gate`;
  return r[0]?.gate||{allowed:false,reason:"QUOTA_RESERVATION_FAILED"};
}
async function markUsage(gate:any,outcome:string,meta:any={}){
  const id=String(gate?.usage_id||""); if(!id)return;
  await sql!`update fwios.market_daily_close_api_usage
    set outcome=${outcome},metadata=metadata||${meta}
    where usage_id=${id}::uuid`;
}
async function provider(){
  const r=await sql!`select active,readiness_status,source_tier,secret_name
    from fwios.decision_refresh_provider_registry
    where provider_key='TWELVE_DATA' limit 1`;
  return r[0]??null;
}
function stockValidity(now:Date){
  const day=now.getUTCDay();
  const h=day===5?96:(day===6?72:(day===0?60:48));
  return new Date(now.getTime()+h*3600_000);
}
function inStockPollWindow(now:Date){
  const d=now.getUTCDay();
  const mins=now.getUTCHours()*60+now.getUTCMinutes();
  return d>=1&&d<=5&&mins>=13*60&&mins<=22*60;
}
async function currentOpenAssets(){
  return await sql!`select distinct asset_symbol,asset_class
    from fwios.v_portfolio_positions_current
    where upper(source_position_status)='OPEN' and coalesce(quantity,0)>0
    order by asset_symbol`;
}
async function needsStockSeed(){
  const r=await sql!`select count(*)::int n
    from (
      select distinct p.asset_symbol
      from fwios.v_portfolio_positions_current p
      left join fwios.v_portfolio_market_quote_current q on q.asset_symbol=p.asset_symbol
      where upper(p.source_position_status)='OPEN'
        and upper(p.asset_class)='STOCK'
        and coalesce(p.quantity,0)>0
        and coalesce(q.freshness_status,'MISSING')<>'FRESH'
    ) x`;
  return Number(r[0]?.n||0)>0;
}
async function getFxUsdThb(key:string){
  const gate=await reserve("USD/THB",{capability:"PORTFOLIO_FX"});
  if(gate.allowed){
    try{
      const u=`https://api.twelvedata.com/exchange_rate?symbol=USD%2FTHB&apikey=${encodeURIComponent(key)}`;
      const d=await fetchJson(u);
      const rate=Number(d?.rate);
      if(rate>0){
        await markUsage(gate,"PASS",{capability:"PORTFOLIO_FX",rate});
        return {rate,provider:"TWELVE_DATA_FX",payload:d};
      }
      await markUsage(gate,"INVALID_PRICE",{capability:"PORTFOLIO_FX",payload:d});
    }catch(e){
      await markUsage(gate,"ERROR",{capability:"PORTFOLIO_FX",error:(e instanceof Error?e.message:String(e)).slice(0,180)});
    }
  }
  const f=await fetchJson("https://api.frankfurter.app/latest?from=USD&to=THB");
  const rate=Number(f?.rates?.THB);
  if(!(rate>0))throw new Error("FX_USDTHB_UNAVAILABLE");
  return {rate,provider:"FRANKFURTER_FX",payload:f};
}
async function insertQuote(q:any){
  await sql!`insert into fwios.portfolio_market_quote_snapshots(
    asset_symbol,asset_class,price_native,native_currency,fx_rate_thb,price_thb,
    provider,source_tier,observed_at,valid_until,market_status,provenance_status,raw_payload
  ) values(
    ${q.asset_symbol},${q.asset_class},${q.price_native},${q.native_currency},
    ${q.fx_rate_thb},${q.price_thb},${q.provider},${q.source_tier},
    ${q.observed_at},${q.valid_until},${q.market_status},'PASS',${q.raw_payload}::jsonb
  )`;
}
async function refreshCrypto(assets:any[]){
  const ids:Record<string,string>={
    BTC:"bitcoin",ETH:"ethereum",XRP:"ripple",SOL:"solana",HBAR:"hedera-hashgraph",DOGE:"dogecoin"
  };
  const symbols=assets.map(a=>String(a.asset_symbol)).filter(s=>ids[s]);
  if(!symbols.length)return {attempted:false,updated:0,missing:[]};
  const uniqueIds=[...new Set(symbols.map(s=>ids[s]))];
  const url=`https://api.coingecko.com/api/v3/simple/price?ids=${encodeURIComponent(uniqueIds.join(","))}&vs_currencies=thb&include_last_updated_at=true`;
  const d=await fetchJson(url,{"Accept":"application/json"});
  const now=new Date();let updated=0;const missing:string[]=[];
  for(const s of symbols){
    const x=d?.[ids[s]],p=Number(x?.thb);
    if(!(p>0)){missing.push(s);continue;}
    const providerTs=Number(x?.last_updated_at)>0?new Date(Number(x.last_updated_at)*1000):now;
    await insertQuote({
      asset_symbol:s,asset_class:"Crypto",price_native:p,native_currency:"THB",
      fx_rate_thb:1,price_thb:p,provider:"COINGECKO",source_tier:"B",
      observed_at:providerTs,valid_until:new Date(now.getTime()+45*60_000),
      market_status:"24X7",
      raw_payload:{provider_last_updated_at:x?.last_updated_at??null,source_url:"https://api.coingecko.com/api/v3/simple/price"}
    });
    updated++;
  }
  return {attempted:true,updated,missing};
}
async function refreshStock(ticker:string,key:string,fx:any,now:Date){
  const gate=await reserve(ticker,{capability:"PORTFOLIO_QUOTE"});
  let price:number|null=null,payload:any=null,providerName="TWELVE_DATA_QUOTE",marketStatus="UNKNOWN";
  if(gate.allowed){
    try{
      const u=`https://api.twelvedata.com/quote?symbol=${encodeURIComponent(ticker)}&apikey=${encodeURIComponent(key)}`;
      const d=await fetchJson(u); payload=d;
      if(d?.status==="error")throw new Error(String(d?.message||"TWELVE_DATA_API_ERROR"));
      price=Number(d?.close??d?.price??d?.previous_close);
      marketStatus=d?.is_market_open===true?"OPEN":(d?.is_market_open===false?"CLOSED":"UNKNOWN");
      if(!(price>0))throw new Error("INVALID_QUOTE_PRICE");
      await markUsage(gate,"PASS",{capability:"PORTFOLIO_QUOTE",price});
    }catch(e){
      await markUsage(gate,"ERROR",{capability:"PORTFOLIO_QUOTE",error:(e instanceof Error?e.message:String(e)).slice(0,180)});
      price=null;
    }
  }
  if(!(Number(price)>0)){
    const r=await sql!`select close_price,session_date,primary_provider,retrieved_at
      from fwios.v_market_daily_close_latest where asset_symbol=${ticker} limit 1`;
    if(!r.length||!(Number(r[0].close_price)>0))return {ticker,status:"BLOCKED",reason:gate.allowed?"QUOTE_AND_DAILY_CLOSE_UNAVAILABLE":gate.reason};
    price=Number(r[0].close_price);
    providerName="TWELVE_DATA_DAILY_CLOSE_FALLBACK";
    marketStatus="LAST_CLOSE";
    payload={session_date:r[0].session_date,primary_provider:r[0].primary_provider,retrieved_at:r[0].retrieved_at};
  }
  const thb=Number(price)*Number(fx.rate);
  await insertQuote({
    asset_symbol:ticker,asset_class:"Stock",price_native:Number(price),native_currency:"USD",
    fx_rate_thb:Number(fx.rate),price_thb:thb,provider:providerName,source_tier:"A",
    observed_at:now,valid_until:stockValidity(now),market_status:marketStatus,
    raw_payload:{quote:payload,fx_provider:fx.provider,fx_payload:fx.payload}
  });
  return {ticker,status:"PASS",price_usd:Number(price),fx_rate_thb:Number(fx.rate),price_thb:thb,provider:providerName};
}

Deno.serve(async(req:Request)=>{
  if(!sql||!dbUrl)return Response.json({error:"DB_UNAVAILABLE"},{status:503});
  if(req.method!=="POST")return new Response("Method Not Allowed",{status:405});

  const tok=req.headers.get("x-fwios-automation-token")||"";
  const access=await sql`select token_sha256 from fwios.decision_refresh_automation_access
    where access_key='DECISION_REFRESH_WORKER' and active=true limit 1`;
  if(tok.length<32||!access.length||!safeEqual(await sha256Hex(tok),String(access[0].token_sha256)))
    return new Response("Unauthorized",{status:401});

  let body:any={};try{body=await req.json();}catch{}
  const forceAll=body?.force_all===true;
  const runRows=await sql`insert into fwios.portfolio_mtm_runs(run_source)
    values(${String(body?.source||"SCHEDULED")}) returning run_id`;
  const runId=String(runRows[0].run_id);
  const now=new Date();
  const assets=await currentOpenAssets();
  const crypto=assets.filter((a:any)=>String(a.asset_class).toUpperCase()==="CRYPTO");
  const stocks=assets.filter((a:any)=>String(a.asset_class).toUpperCase()==="STOCK");

  let cryptoResult:any={attempted:false,updated:0,missing:[]};
  let stockResults:any[]=[];
  let fx:any=null;
  let errors:any[]=[];

  try{cryptoResult=await refreshCrypto(crypto);}catch(e){errors.push({scope:"CRYPTO",error:(e instanceof Error?e.message:String(e)).slice(0,240)});}

  const doStocks=forceAll||inStockPollWindow(now)||await needsStockSeed();
  if(doStocks&&stocks.length){
    const p=await provider();
    const key=await secret(p?.secret_name);
    if(!p||p.active!==true||p.readiness_status!=="READY"||p.source_tier!=="A"||!key){
      errors.push({scope:"STOCK",error:"TWELVE_DATA_NOT_READY"});
    }else{
      try{
        fx=await getFxUsdThb(key);
        for(const a of stocks){
          try{stockResults.push(await refreshStock(String(a.asset_symbol),key,fx,now));}
          catch(e){stockResults.push({ticker:String(a.asset_symbol),status:"ERROR",error:(e instanceof Error?e.message:String(e)).slice(0,240)});}
        }
      }catch(e){errors.push({scope:"FX",error:(e instanceof Error?e.message:String(e)).slice(0,240)});}
    }
  }

  const h=await sql`select * from fwios.v_portfolio_market_price_health`;
  const s=await sql`select portfolio_value_thb from fwios.v_dashboard_account_summary where account_view_key='ALL' limit 1`;
  const health=h[0]??{};
  const value=s[0]?.portfolio_value_thb??null;

  await sql`update fwios.portfolio_mtm_runs set
    completed_at=now(),asset_count=${Number(health.open_asset_count||assets.length)},
    fresh_asset_count=${Number(health.fresh_asset_count||0)},
    portfolio_value_thb=${value},
    pricing_gate=${String(health.pricing_gate||"BLOCKED")},
    stock_refresh_attempted=${doStocks},
    crypto_refresh_attempted=${cryptoResult.attempted===true},
    fx_rate_thb=${fx?.rate??null},
    detail=${{crypto:cryptoResult,stocks:stockResults,errors,price_health:health}}::jsonb
    where run_id=${runId}::uuid`;

  await sql`update fwios.system_state set
    state_value=state_value||${{
      portfolio_mark_to_market_status:String(health.pricing_gate||"BLOCKED"),
      portfolio_mark_to_market_value_thb:value==null?null:Number(value),
      portfolio_mark_to_market_last_refresh:now.toISOString(),
      portfolio_mark_to_market_worker_version:1,
      portfolio_mark_to_market_run_id:runId,
      auto_trade:false
    }}::jsonb,
    updated_at=now(),as_of_text=(now() at time zone 'Asia/Bangkok')::date::text
    where state_key='architecture_consolidation_v1'`;

  return Response.json({
    ok:String(health.pricing_gate)==="PASS",
    worker:WORKER,version:1,run_id:runId,force_all:forceAll,
    stock_refresh_attempted:doStocks,crypto:cryptoResult,stocks:stockResults,
    fx_rate_thb:fx?.rate??null,pricing_gate:health.pricing_gate,
    fresh_asset_count:health.fresh_asset_count,open_asset_count:health.open_asset_count,
    portfolio_value_thb:value,errors,auto_trade:false
  },{status:String(health.pricing_gate)==="PASS"?200:503});
});