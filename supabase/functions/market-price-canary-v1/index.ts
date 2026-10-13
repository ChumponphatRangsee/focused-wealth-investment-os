// FWIOS PR4 bounded live-data canary — READ ONLY, BTC/THB only.
// No direct provider HTTP, no quota reservation, no holdings/accounting writes.
// The Edge gateway must verify the Supabase JWT (deploy verify_jwt=true).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const dbUrl = Deno.env.get("SUPABASE_DB_URL");
const sql = dbUrl ? postgres(dbUrl, {prepare:false,max:1,connect_timeout:5,idle_timeout:10}) : null;

function verifiedJwtRole(req:Request):string|null {
  const h=req.headers.get("authorization")??"";
  const m=/^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(h);
  if(!m)return null;
  try{
    // Authentication SIGNATURE and expiration MUST be checked by the Supabase
    // Edge gateway (verify_jwt=true); this extracts only the already-verified role.
    const segment=m[1].split(".")[1].replace(/-/g,"+").replace(/_/g,"/");
    const claims=JSON.parse(atob(segment.padEnd(Math.ceil(segment.length/4)*4,"=")));
    if(claims.role!=="authenticated"&&claims.role!=="service_role")return null;
    return claims.role;
  }catch{return null;}
}

Deno.serve(async(req:Request)=>{
  const headers={"Cache-Control":"no-store","X-Content-Type-Options":"nosniff"};
  if(req.method!=="GET")
    return Response.json({error:"METHOD_NOT_ALLOWED"},{status:405,headers});
  if(verifiedJwtRole(req)===null)
    return Response.json({error:"AUTHENTICATED_JWT_REQUIRED"},{status:403,headers});
  if(!sql)
    return Response.json({error:"CANARY_DB_NOT_CONFIGURED"},{status:503,headers});
  try{
    const rows=await sql`select fwios.pr4_btc_canary_market_quote_v1() as data`;
    if(!rows.length)
      return Response.json({status:"MISSING",canary_only:true},{status:503,headers});
    return Response.json(rows[0].data,{headers});
  }catch(_e){
    return Response.json({error:"CANARY_READ_UNAVAILABLE"},{status:503,headers});
  }
});
