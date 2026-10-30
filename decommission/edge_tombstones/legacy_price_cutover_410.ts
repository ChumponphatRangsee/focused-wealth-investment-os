// Asset Price Data Service v1.0.0 — retired legacy endpoint.
// Do not restore any Research, Scanner, Valuation, Decision, Portfolio, Stock EOD, or obsolete price canary functionality.
Deno.serve((_request: Request) => new Response(JSON.stringify({ok:false,error:"LEGACY_ENDPOINT_RETIRED",contract:"ASSET-PRICE-CONTRACT-1.0.0",auto_trade:false}),{status:410,headers:{"Content-Type":"application/json","Cache-Control":"no-store"}}));
