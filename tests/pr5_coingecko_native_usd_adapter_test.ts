// Run locally via: deno test tests/pr5_coingecko_native_usd_adapter_test.ts
// Unit only: no vendor network, no DB writes and no vendor quota. CI also type-checks the MVP worker integration.
import { buildCoinGeckoUsdBatchUrl, buildCoinGeckoUsdThbCompatBatchUrl, parseCoinGeckoUsdBatch } from
  "../supabase/functions/_shared/pr5_coingecko_usd_adapter.ts";
import type { CryptoSymbol } from
  "../supabase/functions/_shared/pr5_coingecko_usd_adapter.ts";

function check(ok: boolean, label: string): void {
  if (!ok) throw new Error(label);
}
const assets: CryptoSymbol[] = ["BTC","ETH","XRP","SOL","HBAR","DOGE"];
const ids: Record<CryptoSymbol,string> = {
  BTC:"bitcoin",ETH:"ethereum",XRP:"ripple",SOL:"solana",
  HBAR:"hedera-hashgraph",DOGE:"dogecoin"
};
const at = new Date("2026-10-15T08:25:00.000Z");
const sec = Math.floor(at.getTime()/1000)-120;
const valid = Object.fromEntries(assets.map((s,i)=>
  [ids[s],{usd:1000/(i+1),last_updated_at:sec}]));

Deno.test("batch contract requests USD for 6 crypto ids",()=>{
 const u=new URL(buildCoinGeckoUsdBatchUrl(assets));
 check(u.hostname==="api.coingecko.com","provider host");
 check(u.searchParams.get("vs_currencies")==="usd","must request native USD");
 check(u.searchParams.get("ids")===assets.map(s=>ids[s]).join(","),"id map");
 check(u.searchParams.get("include_last_updated_at")==="true","timestamp required");
 check(!u.searchParams.toString().includes("thb"),"no THB");
});
Deno.test("compat batch requests USD and THB in one provider call",()=>{
 const u=new URL(buildCoinGeckoUsdThbCompatBatchUrl(assets));
 check(u.searchParams.get("vs_currencies")==="usd,thb","same call must request usd,thb");
 check(u.searchParams.get("ids")===assets.map(s=>ids[s]).join(","),"same six ids");
});
Deno.test("all 6 USD responses validated and sourced",()=>{
 const z=parseCoinGeckoUsdBatch(valid,assets,at);
 check(z.length===6 && z.every(x=>x.status==="READY"),"all six READY");
 for(const x of z){
  if(x.status!=="READY")throw Error("not ready");
  check(x.candidate.currency==="USD"&&x.candidate.source_native_usd===true,"native USD");
  check(x.candidate.price_usd>0&&x.candidate.provider==="COINGECKO","source");
 }
});
Deno.test("THB-only payload is not native USD",()=>{
 const z=parseCoinGeckoUsdBatch({bitcoin:{thb:2711893,last_updated_at:sec}},["BTC"],at);
 check(z[0].status==="INVALID","THB-only must fail");
});
Deno.test("stale source cannot be READY",()=>{
 const z=parseCoinGeckoUsdBatch({bitcoin:{usd:80_000,last_updated_at:sec-3600}},["BTC"],at);
 check(z[0].status==="STALE","old timestamp");
});
Deno.test("future timestamp cannot be READY",()=>{
 const z=parseCoinGeckoUsdBatch({bitcoin:{usd:80_000,last_updated_at:sec+3600}},["BTC"],at);
 check(z[0].status==="INVALID","future timestamp");
});
Deno.test("partial batch returns MISSING, not invented prices",()=>{
 const z=parseCoinGeckoUsdBatch({bitcoin:{usd:80_000,last_updated_at:sec}},["BTC","ETH"],at);
 check(z[0].status==="READY"&&z[1].status==="MISSING","partial reply");
});
Deno.test("invalid prices are rejected",()=>{
 for(const price of [-10,0,Number.NaN,Number.POSITIVE_INFINITY,"80000"]){
   const z=parseCoinGeckoUsdBatch({bitcoin:{usd:price,last_updated_at:sec}},["BTC"],at);
   check(z[0].status==="INVALID","bad price");
 }
});
Deno.test("duplicate crypto symbols not allowed",()=>{
 let rejected=false;
 try{buildCoinGeckoUsdBatchUrl(["BTC","BTC"]);}catch{rejected=true;}
 check(rejected,"duplicate symbol batch");
});
