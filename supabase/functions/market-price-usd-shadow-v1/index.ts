// PR5 USD-only canonical-price shadow reader. No external vendor traffic,
// no inserts, no portfolio accounting. Deploy with verify_jwt=true ONLY.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const dbUrl = Deno.env.get("SUPABASE_DB_URL");
const sql = dbUrl
  ? postgres(dbUrl, { prepare: false, max: 1, connect_timeout: 5, idle_timeout: 10 })
  : null;
const headers = {
  "Cache-Control": "no-store",
  "Content-Type": "application/json",
  "X-Content-Type-Options": "nosniff",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function verifiedGatewayJwtRole(req: Request): string | null {
  const header = req.headers.get("authorization") ?? "";
  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(header);
  if (!match) return null;
  try {
    // Payload decoding is NOT signature verification. Signature and expiry
    // MUST be validated by the Supabase gateway with verify_jwt=true.
    const raw = match[1].split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(raw.padEnd(Math.ceil(raw.length / 4) * 4, "=")));
    return claims.role === "authenticated" || claims.role === "service_role"
      ? claims.role : null;
  } catch { return null; }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "GET") {
    return Response.json({ error: "METHOD_NOT_ALLOWED" }, { status: 405, headers });
  }
  if (!verifiedGatewayJwtRole(req)) {
    return Response.json({ error: "AUTHENTICATED_JWT_REQUIRED" }, { status: 403, headers });
  }

  const asset = (new URL(req.url).searchParams.get("asset") ?? "").trim().toUpperCase();
  if (!/^[A-Z0-9.-]{1,24}$/.test(asset)) {
    return Response.json({ status: "UNSUPPORTED", reason: "INVALID_ASSET" },
      { status: 400, headers });
  }
  if (!sql) {
    return Response.json({ error: "SHADOW_DB_NOT_CONFIGURED" }, { status: 503, headers });
  }
  try {
    const rows = await sql`select fwios.pr5_native_usd_price_shadow_v1(${asset}::text) as data`;
    const data = rows[0]?.data;
    if (!data) return Response.json({ error: "SHADOW_READ_UNAVAILABLE" }, { status: 503, headers });
    if (data.shadow_only !== true || data.read_only !== true ||
        data.valuation_eligible !== false || data.accounting_eligible !== false ||
        data.trading_eligible !== false ||
        data.new_provider_calls !== 0 || data.new_quota_reservations !== 0) {
      return Response.json({ error: "SHADOW_CONTRACT_INVALID" }, { status: 503, headers });
    }
    if (data.status === "UNSUPPORTED" || data.status === "AMBIGUOUS_INSTRUMENT") {
      return Response.json(data, { status: 400, headers });
    }
    if (data.status === "MISSING") return Response.json(data, { status: 404, headers });
    if (data.currency !== "USD" || data.source_native_usd !== true ||
        !(Number(data.price_usd) > 0)) {
      return Response.json({ error: "NATIVE_USD_REQUIRED" }, { status: 503, headers });
    }
    return Response.json(data, { headers });
  } catch {
    return Response.json({ error: "SHADOW_READ_UNAVAILABLE" }, { status: 503, headers });
  }
});
