import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 1 });

const ACCOUNT_HEADERS = ["account_view_key","account_view_name","portfolio_value_thb","open_cost_basis_thb","unrealized_pnl_thb","realized_pnl_thb","total_pnl_thb","unique_open_assets","crypto_weight","largest_position_symbol","largest_position_weight","phase1_goal_thb","phase1_goal_progress","batch_id","observed_at","batch_status"];
const HOLDING_HEADERS = ["account_view_key","account_view_name","asset_symbol","asset_class","quantity","cost_basis_thb","value_thb","unrealized_pnl_thb","unrealized_return_pct","view_weight","batch_id","observed_at"];
const OPPORTUNITY_HEADERS = ["opportunity_bucket","bucket_rank","ticker","core_score","business_thesis_score","expected_return_score","portfolio_fit_score","downside_risk_score","eligibility_gate","rationale_code","decision_state","promotion_gate","current_price","pw_fair_value","pw_upside","mispricing_gate","mispricing_class","ranking_run_id","decision_snapshot_id","created_at"];
const ACTION_HEADERS = ["action_state","candidate_ticker","source_ticker","new_cash_thb","add_amount_thb","trim_amount_thb","approval_state","traceability_gate","freshness_gate","candidate_core_score","candidate_portfolio_fit_score","action_note","auto_trade","human_execution_only"];
const ALERT_HEADERS = ["alert_order","alert_type","label","subject","current_value","lower_threshold","upper_threshold","status","note"];
const HEALTH_HEADERS = ["foundation_version","contract_id","foundation_status","github_merge_sha","m3_status","approval_policy","approval_regressions","cutover_traceability","sector_automation_mode","next_queued_sector","next_action","portfolio_batch_id","portfolio_batch_status","source_transaction_count","transaction_pass_count","source_position_count","position_pass_count","open_model_blockers","auto_trade","human_execution_only"];

async function sha256Hex(input: string) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(b)).map(x => x.toString(16).padStart(2, "0")).join("");
}

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

function bangkokTime(v: unknown) {
  if (!v) return "";
  const d = new Date(String(v));
  if (Number.isNaN(d.getTime())) return String(v);
  const p = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok", year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hourCycle: "h23"
  }).formatToParts(d);
  const g = (t: string) => p.find(x => x.type === t)?.value ?? "";
  return `${g("year")}-${g("month")}-${g("day")} ${g("hour")}:${g("minute")} Asia/Bangkok`;
}

function norm(row: any, headers: string[]) {
  return headers.map(h => {
    let k = h;
    if (h === "pw_fair_value") k = "probability_weighted_fv_per_share";
    if (h === "pw_upside") k = "probability_weighted_upside";
    const v = row?.[k];
    if (h === "observed_at" || h === "created_at") return bangkokTime(v);
    if (typeof v === "boolean") return v ? "TRUE" : "FALSE";
    return v ?? "";
  });
}

function cell(v: unknown) {
  const s = v == null ? "" : String(v);
  return /[\",\n\r]/.test(s) ? `"${s.replaceAll('"','""')}"` : s;
}

function toCsv(payload: any) {
  const matrix: any[][] = Array.from({ length: 65 }, () => Array(20).fill(""));
  const put = (row: number, rows: any[][]) => rows.forEach((x, i) => x.forEach((v, j) => {
    if (row - 1 + i < 65 && j < 20) matrix[row - 1 + i][j] = v;
  }));
  const d = payload?.data ?? {};
  put(1, [ACCOUNT_HEADERS, ...(d.account_summary ?? []).map((r: any) => norm(r, ACCOUNT_HEADERS))]);
  put(11, [HOLDING_HEADERS, ...(d.holdings ?? []).map((r: any) => norm(r, HOLDING_HEADERS))]);
  put(38, [OPPORTUNITY_HEADERS, ...(d.opportunities ?? []).map((r: any) => norm(r, OPPORTUNITY_HEADERS))]);
  put(44, [ACTION_HEADERS, ...(d.current_action ?? []).map((r: any) => norm(r, ACTION_HEADERS))]);
  put(49, [ALERT_HEADERS, ...(d.alerts ?? []).map((r: any) => norm(r, ALERT_HEADERS))]);
  put(57, [HEALTH_HEADERS, ...(d.system_health ?? []).map((r: any) => norm(r, HEALTH_HEADERS))]);
  put(61, [
    ["worker","worker_id","last_checked_at","status","source_fingerprint","refresh_gate"],
    ["SUPABASE_EDGE_IMPORTDATA","dashboard-refresh-csv-v1",bangkokTime(payload?.served_at ?? payload?.generated_at),payload?.served_status ?? "PASS",payload?.source_fingerprint ?? "",payload?.refresh_gate ?? ""]
  ]);
  return matrix.map(r => r.map(cell).join(",")).join("\n");
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "GET") return new Response("Method Not Allowed", { status: 405 });
    const u = new URL(req.url);
    const token = u.searchParams.get("token") ?? "";
    if (!token || token.length < 24) return new Response("Unauthorized", { status: 401 });

    const access = await sql`select token_sha256 from fwios.dashboard_refresh_access where access_key='GOOGLE_SHEET_IMPORTDATA' and active=true limit 1`;
    if (!access.length) return new Response("Unauthorized", { status: 401 });
    const actual = await sha256Hex(token);
    if (!safeEqual(actual, String(access[0].token_sha256))) return new Response("Unauthorized", { status: 401 });

    const current = await sql`select fwios.dashboard_refresh_payload_v1() as payload`;
    if (!current.length || !current[0]?.payload) return new Response("Refresh unavailable", { status: 503 });
    let payload = current[0].payload;

    if (payload?.refresh_gate !== "PASS") {
      const cached = await sql`select payload,last_good_at from fwios.dashboard_refresh_cache where cache_key='PRIMARY' limit 1`;
      if (!cached.length || !cached[0]?.payload) return new Response("Refresh blocked", { status: 503 });
      payload = {
        ...cached[0].payload,
        refresh_gate: "BLOCKED",
        served_status: "STALE_BLOCKED",
        served_at: new Date().toISOString(),
        last_good_at: cached[0].last_good_at,
        served_from: "LAST_GOOD_CACHE"
      };
    } else {
      try {
        await sql`insert into fwios.dashboard_refresh_cache(cache_key,payload,source_fingerprint,contract_id,portfolio_batch_id,last_good_at,updated_at)
          values('PRIMARY',${payload},${payload.source_fingerprint},${payload.contract_id},${payload.portfolio_batch_id},now(),now())
          on conflict(cache_key) do update set payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,contract_id=excluded.contract_id,portfolio_batch_id=excluded.portfolio_batch_id,last_good_at=excluded.last_good_at,updated_at=excluded.updated_at`;
      } catch { /* cache is fail-safe only; a cache write must not break a valid read */ }
      payload = { ...payload, served_status: "PASS", served_at: new Date().toISOString(), served_from: "CURRENT_PAYLOAD" };
    }

    return new Response(toCsv(payload), {
      status: 200,
      headers: {
        "content-type": "text/csv; charset=utf-8",
        "cache-control": "no-store, max-age=0",
        "x-fwios-refresh-gate": String(payload?.refresh_gate ?? "UNKNOWN"),
        "x-fwios-served-status": String(payload?.served_status ?? "UNKNOWN")
      }
    });
  } catch {
    return new Response("Refresh unavailable", { status: 503, headers: { "cache-control": "no-store" } });
  }
});
