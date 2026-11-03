import {parseTwelveDailyEod,previousNyBusinessDay,twelveFallbackWindow} from "../../supabase/functions/price-market-refresh-v1/twelve-eod-guards.ts";
function assert(condition:unknown,label:string):asserts condition {if(!condition)throw new Error(label)}
function errorCode(fn:()=>unknown,code:string){
 let actual="";
 try{fn()}catch(e){actual=e instanceof Error?e.message:"UNKNOWN"}
 assert(actual===code,"Expected "+code+" got "+actual);
}
const good={
 meta:{symbol:"MSFT",currency:"USD",exchange_timezone:"America/New_York"},
 values:[{datetime:"2026-11-02",close:"531.21"},{datetime:"2026-10-30",close:"528.10"}]
};
Deno.test("Twelve accepts only exact USD NY unadjusted date",()=>{
 const r=parseTwelveDailyEod(good,"MSFT","2026-11-02");
 assert(r.symbol==="MSFT"&&r.session_date==="2026-11-02"&&r.close===531.21,"valid EOD parsed");
});
Deno.test("Twelve rejects previous session with no write",()=>{
 errorCode(()=>parseTwelveDailyEod(good,"MSFT","2026-11-03"),"TWELVE_DATA_SESSION_NOT_READY");
});
Deno.test("Twelve rejects newer bar instead of backdating",()=>{
 const newer={...good,values:[{datetime:"2026-11-03",close:"540"},{datetime:"2026-11-02",close:"531.21"}]};
 errorCode(()=>parseTwelveDailyEod(newer,"MSFT","2026-11-02"),"TWELVE_DATA_SESSION_NOT_READY");
});
Deno.test("Twelve rejects duplicate session rows",()=>{
 const dup={...good,values:[...good.values,good.values[0]]};
 errorCode(()=>parseTwelveDailyEod(dup,"MSFT","2026-11-02"),"TWELVE_DATA_SESSION_NOT_READY");
});
Deno.test("Twelve rejects different ticker and non USD currency",()=>{
 errorCode(()=>parseTwelveDailyEod(good,"NVDA","2026-11-02"),"TWELVE_DATA_SYMBOL_CURRENCY_MISMATCH");
 errorCode(()=>parseTwelveDailyEod({...good,meta:{...good.meta,currency:"EUR"}},"MSFT","2026-11-02"),"TWELVE_DATA_SYMBOL_CURRENCY_MISMATCH");
});
Deno.test("Twelve rejects non-NY exchange timezone",()=>{
 errorCode(()=>parseTwelveDailyEod({...good,meta:{...good.meta,exchange_timezone:"UTC"}},"MSFT","2026-11-02"),"TWELVE_DATA_EXCHANGE_TIMEZONE_MISMATCH");
});
Deno.test("Twelve rejects malformed JSON, missing prices and invalid close",()=>{
 errorCode(()=>parseTwelveDailyEod(null,"MSFT","2026-11-02"),"TWELVE_DATA_MALFORMED_EOD");
 errorCode(()=>parseTwelveDailyEod({...good,values:{} as unknown},"MSFT","2026-11-02"),"TWELVE_DATA_MALFORMED_EOD");
 for(const close of ["0","NaN","-1","99999999999"]){
  errorCode(()=>parseTwelveDailyEod({...good,values:[{datetime:"2026-11-02",close}]},"MSFT","2026-11-02"),"TWELVE_DATA_INVALID_CLOSE");
 }
});
Deno.test("Twelve only admits next NY trading day's 01:15-01:59 window",()=>{
 assert(previousNyBusinessDay({day:"2026-11-03",weekday:"Tue"})==="2026-11-02","Tuesday targets Monday");
 assert(previousNyBusinessDay({day:"2026-11-02",weekday:"Mon"})==="2026-10-30","Monday targets Friday");
 assert(previousNyBusinessDay({day:"2026-11-01",weekday:"Sun"})===null,"Sunday never runs");
 const clock={day:"2026-11-03",weekday:"Tue",hour:1,minute:15};
 assert(twelveFallbackWindow(clock),"01:15 admitted");
 assert(!twelveFallbackWindow({...clock,minute:14}),"01:14 blocked");
 assert(!twelveFallbackWindow({...clock,hour:2}),"02:15 blocked");
 assert(!twelveFallbackWindow({...clock,weekday:"Sat"}),"Saturday blocked");
 assert(!twelveFallbackWindow({...clock,weekday:"Sun"}),"Sunday blocked");
});
