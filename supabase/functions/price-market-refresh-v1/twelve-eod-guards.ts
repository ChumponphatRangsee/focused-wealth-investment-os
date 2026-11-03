export type NyBusinessClock={day:string;weekday:string;hour:number;minute:number};
export type StockEodRow={symbol:string;close:number;session_date:string};

/** Twelve Data publishes prior US trading day's historical EOD after midnight ET. */
export function previousNyBusinessDay(ny:Pick<NyBusinessClock,"day"|"weekday">):string|null{
 if(["Sat","Sun"].includes(ny.weekday))return null;
 if(!/^\d{4}-\d{2}-\d{2}$/.test(ny.day))return null;
 const date=new Date(ny.day+"T12:00:00Z");
 if(!Number.isFinite(date.getTime()))return null;
 date.setUTCDate(date.getUTCDate()-(ny.weekday==="Mon"?3:1));
 return date.toISOString().slice(0,10);
}

/** Cron's desired New York window; manual calls must honor the same boundary. */
export function twelveFallbackWindow(ny:NyBusinessClock):boolean{
 return !["Sat","Sun"].includes(ny.weekday)&&ny.hour===1&&ny.minute>=15&&ny.minute<=59;
}

/**
 * Parse one authoritative unadjusted US equity daily bar.
 * Throws SAFE codes only. No live HTTP, no provider credentials.
 */
export function parseTwelveDailyEod(data:unknown,symbol:string,day:string):StockEodRow{
 if(!data||typeof data!=="object"||Array.isArray(data))
  throw new Error("TWELVE_DATA_MALFORMED_EOD");
 const value=data as Record<string,unknown>;
 const meta=value.meta as Record<string,unknown>|undefined;
 const raw=value.values;
 if(!meta||typeof meta!=="object"||!Array.isArray(raw))
  throw new Error("TWELVE_DATA_MALFORMED_EOD");
 if(String(meta.symbol||"").toUpperCase()!==symbol
    ||String(meta.currency||"").toUpperCase()!=="USD")
  throw new Error("TWELVE_DATA_SYMBOL_CURRENCY_MISMATCH");
 if(String(meta.exchange_timezone||"")!=="America/New_York")
  throw new Error("TWELVE_DATA_EXCHANGE_TIMEZONE_MISMATCH");
 const sessions=raw.map((v:unknown)=>{
  if(!v||typeof v!=="object")return "";
  return String((v as Record<string,unknown>).datetime||"").slice(0,10);
 }).filter((v:string)=>/^\d{4}-\d{2}-\d{2}$/.test(v)).sort().reverse();
 if(sessions[0]!==day||sessions.filter((v:string)=>v===day).length!==1)
  throw new Error("TWELVE_DATA_SESSION_NOT_READY");
 const candidate=raw.find((v:unknown)=>v&&typeof v==="object"&&
  String((v as Record<string,unknown>).datetime||"").slice(0,10)===day) as Record<string,unknown>|undefined;
 const close=Number(candidate?.close);
 if(!(close>0)||!Number.isFinite(close)||close>10_000_000)
  throw new Error("TWELVE_DATA_INVALID_CLOSE");
 return {symbol,close,session_date:day};
}
