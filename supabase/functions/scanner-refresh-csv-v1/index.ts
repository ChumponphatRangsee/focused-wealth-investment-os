import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const sql = postgres(Deno.env.get("SUPABASE_DB_URL")!, { prepare: false, max: 1 });

const HEADERS = [
  "scan_rank",
  "ticker",
  "company",
  "sector",
  "scanner_score",
  "quality_score",
  "latest_price",
  "price_as_of",
  "bear_fv",
  "base_fv",
  "high_fv",
  "probability_weighted_fv",
  "upside_pct",
  "valuation_status",
  "thesis_score",
  "scan_status",
  "refreshed_at",
  "price_verification_status",
  "price_provenance_status",
];

async function sha256Hex(input: string) {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(bytes))
    .map((x) => x.toString(16).padStart(2, "0"))
    .join("");
}

function safeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function bangkokTime(value: unknown) {
  if (!value) return "";
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) return String(value);
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const get = (type: string) => parts.find((x) => x.type === type)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")} ${get("hour")}:${get("minute")} Asia/Bangkok`;
}

function csvCell(value: unknown) {
  const raw = value == null ? "" : String(value);
  return /[",\n\r]/.test(raw) ? `"${raw.replaceAll('"', '""')}"` : raw;
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "GET") return new Response("Method Not Allowed", { status: 405 });

    const url = new URL(req.url);
    const token = url.searchParams.get("token") ?? "";
    if (!token || token.length < 24) return new Response("Unauthorized", { status: 401 });

    const access = await sql`
      select token_sha256
      from fwios.dashboard_refresh_access
      where access_key = 'GOOGLE_SHEET_IMPORTDATA'
        and active = true
      limit 1
    `;
    if (!access.length) return new Response("Unauthorized", { status: 401 });

    const actual = await sha256Hex(token);
    if (!safeEqual(actual, String(access[0].token_sha256))) {
      return new Response("Unauthorized", { status: 401 });
    }

    const rows = await sql`
      select
        scan_rank, ticker, company, sector, scanner_score, quality_score,
        latest_price, price_as_of, bear_fv, base_fv, high_fv,
        probability_weighted_fv, upside_pct, valuation_status, thesis_score,
        scan_status, refreshed_at, price_verification_status, price_provenance_status
      from fwios.v_scanner_current_v1
      order by scan_rank nulls last, upside_pct desc nulls last, ticker
    `;

    const matrix = [
      HEADERS,
      ...rows.map((row: Record<string, unknown>) =>
        HEADERS.map((header) =>
          header === "refreshed_at" ? bangkokTime(row[header]) : row[header] ?? ""
        )
      ),
    ];

    return new Response(
      matrix.map((row) => row.map(csvCell).join(",")).join("\n"),
      {
        status: 200,
        headers: {
          "content-type": "text/csv; charset=utf-8",
          "cache-control": "no-store, max-age=0",
          "x-fwios-read-model": "SCANNER_V1",
          "x-fwios-portfolio-dependent": "false",
        },
      },
    );
  } catch {
    return new Response("Scanner refresh unavailable", {
      status: 503,
      headers: { "cache-control": "no-store" },
    });
  }
});
