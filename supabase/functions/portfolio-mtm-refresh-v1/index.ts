import { buildCoinGeckoUsdThbCompatBatchUrl, parseCoinGeckoUsdBatch } from "../_shared/pr5_coingecko_usd_adapter.ts";
import type { CryptoSymbol } from "../_shared/pr5_coingecko_usd_adapter.ts";
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
async function currentOpenAssets(){
  return await sql!`select distinct asset_symbol,asset_class
    from fwios.v_portfolio_positions_current
    where upper(source_position_status)='OPEN' and coalesce(quantity,0)>0
    order by asset_symbol`;
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
async function publishNativeUsdCrypto(
  symbol:CryptoSymbol,priceUsd:number,providerTs:Date,providerLastUpdatedAt:unknown
){
  const raw={
    provider_last_updated_at:providerLastUpdatedAt??null,
    source_url:"https://api.coingecko.com/api/v3/simple/price",
    fwios_pr5_mvp:{native_usd:true,legacy_thb_compat:true,same_provider_request:true}
  };
  const r=await sql!`select fwios.ensure_market_observation_v1(
    fwios.resolve_instrument_id_v1(${symbol},'Crypto',null,null),
    'LIVE_QUOTE',${priceUsd},'USD',${providerTs.toISOString().slice(0,10)}::date,
    ${providerTs},'24X7','COINGECKO','B','https://api.coingecko.com/api/v3/simple/price',
    'PASS',${JSON.stringify(raw)}::jsonb,null,null
  ) observation_id`;
  if(!r[0]?.observation_id)throw new Error("USD_OBSERVATION_NOT_PUBLISHED");
  return String(r[0].observation_id);
}
async function refreshCrypto(assets:any[]){
  const ids:Record<CryptoSymbol,string>={
    BTC:"bitcoin",ETH:"ethereum",XRP:"ripple",SOL:"solana",HBAR:"hedera-hashgraph",DOGE:"dogecoin"
  };
  const symbols=[...new Set(
    assets.map(a=>String(a.asset_symbol).toUpperCase())
      .filter((s):s is CryptoSymbol=>Object.prototype.hasOwnProperty.call(ids,s))
  )];
  if(!symbols.length)return {attempted:false,updated:0,usd_updated:0,missing:[],usd_missing:[],usd_errors:[]};
  // MVP: one existing CoinGecko request now returns both currencies.
  // One batch call covers all held crypto. Phase 1 invokes this once daily post-close.
  const d=await fetchJson(buildCoinGeckoUsdThbCompatBatchUrl(symbols),{"Accept":"application/json"});
  const now=new Date();
  const usdParsed=parseCoinGeckoUsdBatch(d,symbols,now);
  const usdByAsset=new Map(usdParsed.map(x=>[x.asset,x]));
  let updated=0,usdUpdated=0;
  const missing:string[]=[],usdMissing:string[]=[],usdErrors:any[]=[];
  for(const s of symbols){
    const x=d?.[ids[s]],pThb=Number(x?.thb);
    if(!(pThb>0)){missing.push(s);continue;}
    const providerTs=Number(x?.last_updated_at)>0?new Date(Number(x.last_updated_at)*1000):now;
    const usd=usdByAsset.get(s);
    if(usd?.status==="READY"){
      try{
        await publishNativeUsdCrypto(s,usd.candidate.price_usd,providerTs,x?.last_updated_at);
        usdUpdated++;
      }catch(e){
        usdErrors.push({asset:s,error:(e instanceof Error?e.message:String(e)).slice(0,180)});
      }
    }else{
      usdMissing.push(s);
      if(usd)usdErrors.push({asset:s,status:usd.status,reason:usd.reason});
    }
    // Legacy THB compatibility path remains exactly in place for current portfolio consumers.
    await insertQuote({
      asset_symbol:s,asset_class:"Crypto",price_native:pThb,native_currency:"THB",
      fx_rate_thb:1,price_thb:pThb,provider:"COINGECKO",source_tier:"B",
      observed_at:providerTs,valid_until:new Date(now.getTime()+30*60*60_000),
      market_status:"24X7",
      raw_payload:{provider_last_updated_at:x?.last_updated_at??null,source_url:"https://api.coingecko.com/api/v3/simple/price"}
    });
    updated++;
  }
  return {attempted:true,updated,usd_updated:usdUpdated,missing,usd_missing:usdMissing,usd_errors:usdErrors};
}
async function refreshStockFromDailyClose(ticker:string,fx:any,now:Date){
  const r=await sql!`select o.observation_value price_usd,o.observed_at,o.session_date,o.provider,o.observation_id
    from fwios.market_observations o
    join fwios.v_instrument_identity_current id on id.instrument_id=o.instrument_id
    where id.asset_symbol=${ticker}
      and o.observation_type='REGULAR_CLOSE'
      and o.value_currency='USD'
      and o.provenance_status='PASS'
      and o.observation_value>0
      and o.source_tier='A'
    order by o.session_date desc,o.observed_at desc,o.created_at desc
    limit 1`;
  if(!r.length||!(Number(r[0].price_usd)>0))
    return {ticker,status:"BLOCKED",reason:"DAILY_CLOSE_UNAVAILABLE"};
  const price=Number(r[0].price_usd);
  const observedAt=new Date(r[0].observed_at);
  const thb=price*Number(fx.rate);
  await insertQuote({
    asset_symbol:ticker,asset_class:"Stock",price_native:price,native_currency:"USD",
    fx_rate_thb:Number(fx.rate),price_thb:thb,provider:"FWIOS_DAILY_CLOSE_SYNC",source_tier:"A",
    observed_at:observedAt,valid_until:stockValidity(now),market_status:"LAST_CLOSE",
    raw_payload:{
      daily_close_provider:String(r[0].provider),
      daily_close_observation_id:String(r[0].observation_id),
      session_date:String(r[0].session_date),
      fx_provider:fx.provider,fx_payload:fx.payload,
      fwios_pr7_mvp:{scope:"OPEN_HOLDINGS_ONLY",mode:"DAILY_CLOSE_AFTER_MARKET"}
    }
  });
  return {
    ticker,status:"PASS",price_usd:price,fx_rate_thb:Number(fx.rate),price_thb:thb,
    provider:"FWIOS_DAILY_CLOSE_SYNC",market_status:"LAST_CLOSE",
    observed_at:observedAt.toISOString(),session_date:String(r[0].session_date)
  };
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
  const stockMode=String(body?.stock_mode||"OFF").toUpperCase();
  const refreshCryptoEnabled=body?.refresh_crypto===true;
  const runRows=await sql`insert into fwios.portfolio_mtm_runs(run_source)
    values(${String(body?.source||"SCHEDULED")}) returning run_id`;
  const runId=String(runRows[0].run_id);
  const now=new Date();
  const assets=await currentOpenAssets();
  const crypto=assets.filter((a:any)=>String(a.asset_class).toUpperCase()==="CRYPTO");
  const stocks=assets.filter((a:any)=>String(a.asset_class).toUpperCase()==="STOCK");

  let cryptoResult:any={attempted:false,updated:0,usd_updated:0,missing:[],usd_missing:[],usd_errors:[]};
  let stockResults:any[]=[];
  let fx:any=null;
  let errors:any[]=[];

  if(refreshCryptoEnabled){
    try{cryptoResult=await refreshCrypto(crypto);}catch(e){errors.push({scope:"CRYPTO",error:(e instanceof Error?e.message:String(e)).slice(0,240)});}
  }

  // Phase-1 cost control: no intraday portfolio polling.
  // The dedicated post-close Cron refreshes held crypto once and syncs held stocks from daily close.
  const doStocks=stockMode==="DAILY_CLOSE_ONLY";
  if(doStocks&&stocks.length){
    const p=await provider();
    const key=await secret(p?.secret_name);
    if(!p||p.active!==true||p.readiness_status!=="READY"||p.source_tier!=="A"||!key){
      errors.push({scope:"STOCK",error:"TWELVE_DATA_NOT_READY"});
    }else{
      try{
        fx=await getFxUsdThb(key);
        for(const a of stocks){
          try{stockResults.push(await refreshStockFromDailyClose(String(a.asset_symbol),fx,now));}
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
    detail=${JSON.stringify({crypto:cryptoResult,stocks:stockResults,errors,price_health:health})}::jsonb
    where run_id=${runId}::uuid`;

  await sql`update fwios.system_state set
    state_value=state_value||${JSON.stringify({
      portfolio_mark_to_market_status:String(health.pricing_gate||"BLOCKED"),
      portfolio_mark_to_market_value_thb:value==null?null:Number(value),
      portfolio_mark_to_market_last_refresh:now.toISOString(),
      portfolio_mark_to_market_worker_version:3,
      portfolio_mark_to_market_run_id:runId,
      auto_trade:false
    })}::jsonb,
    updated_at=now(),as_of_text=(now() at time zone 'Asia/Bangkok')::date::text
    where state_key='architecture_consolidation_v1'`;

  return Response.json({
    ok:String(health.pricing_gate)==="PASS",
    worker:WORKER,version:3,run_id:runId,force_all:forceAll,stock_mode:stockMode,refresh_crypto:refreshCryptoEnabled,
    stock_refresh_attempted:doStocks,stock_refresh_policy:"DAILY_POST_CLOSE",crypto_refresh_policy:"DAILY_SNAPSHOT",
    crypto:cryptoResult,stocks:stockResults,
    fx_rate_thb:fx?.rate??null,pricing_gate:health.pricing_gate,
    fresh_asset_count:health.fresh_asset_count,open_asset_count:health.open_asset_count,
    portfolio_value_thb:value,errors,auto_trade:false
  },{status:String(health.pricing_gate)==="PASS"?200:503});
});