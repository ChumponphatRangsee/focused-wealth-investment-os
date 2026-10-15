// FWIOS PR4 bounded, read-only real market observations.
// Canary USD display: BTC is FX-derived (STALE if FX stale); NVDA/TTWO USD.\n// USDTHB is THB per USD and retains its proper unit (FX reference-only).
// No provider HTTP, quota reservation, portfolio accounting or trade writes.
// Authentication SIGNATURE and expiration are enforced by the Supabase gateway.
// DEPLOY ONLY WITH verify_jwt=true.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const dbUrl = Deno.env.get("SUPABASE_DB_URL");
const sql = dbUrl ? postgres(dbUrl, {
  prepare: false, max: 1, connect_timeout: 5, idle_timeout: 10,
}) : null;

const allowedAssets = new Set(["BTC", "NVDA", "TTWO", "USDTHB"]);
const headers: Record<string, string> = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function verifiedGatewayJwtRole(req: Request): string | null {
  const authHeader = req.headers.get("authorization") ?? "";
  const match = /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/.exec(authHeader);
  if (!match) return null;
  try {
    // Decode role only AFTER Supabase's mandatory verify_jwt=true gateway.
    // Payload decoding alone does NOT verify a JWT.
    const raw = match[1].split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const claims = JSON.parse(atob(raw.padEnd(Math.ceil(raw.length / 4) * 4, "=")));
    return claims.role === "authenticated" || claims.role === "service_role"
      ? claims.role : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {status: 204, headers});
  }
  if (req.method !== "GET") {
    return Response.json({ error: "METHOD_NOT_ALLOWED" }, { status: 405, headers });
  }
  if (verifiedGatewayJwtRole(req) === null) {
    return Response.json({ error: "AUTHENTICATED_JWT_REQUIRED" }, { status: 403, headers });
  }

  const url = new URL(req.url);
  const requested = (url.searchParams.get("asset") ?? "BTC").trim().toUpperCase();
  if (!allowedAssets.has(requested)) {
    return Response.json({
      status: "UNSUPPORTED", asset: requested.slice(0, 32),
      allowlist: [...allowedAssets], canary_only: true,
      accounting_eligible: false, valuation_eligible: false,
    }, { status: 400, headers });
  }
  if (!sql) {
    return Response.json({ error: "CANARY_DB_NOT_CONFIGURED" }, { status: 503, headers });
  }
  try {
    // Single parameterized query, immutable data source; no caller SQL or outbound HTTP.
    const rows = await sql`select fwios.pr4_market_canary_usd_v1(${requested}::text) as data`;
    const data = rows[0]?.data;
    if (!data || data.status === "MISSING") {
      return Response.json(data ?? {status: "MISSING", canary_only: true},
        {status: 404, headers});
    }
    return Response.json(data, {headers});
  } catch (_error) {
    // Do not expose DB URLs, SQL diagnostics, auth tokens or credentials.
    return Response.json({error: "CANARY_READ_UNAVAILABLE"}, {status: 503, headers});
  }
});
