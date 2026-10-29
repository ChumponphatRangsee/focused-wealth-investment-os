import "jsr:@supabase/functions-js/edge-runtime.d.ts";
// Tombstone for legacy workflows after user-directed price-only cutover.
// Does not read/write Supabase data and does not expose credentials.
Deno.serve(() => Response.json(
 {ok:false,error:"RETIRED_PRICE_ONLY_MODE",message:"Legacy scanner/research/portfolio-sync API disabled. Use dedicated price-only services."},
 {status:410,headers:{"Cache-Control":"no-store"}}
));
