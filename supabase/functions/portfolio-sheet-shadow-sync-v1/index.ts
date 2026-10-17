import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.3";

const dbUrl = Deno.env.get("SUPABASE_DB_URL");
const sql = dbUrl ? postgres(dbUrl, { prepare: false, max: 1 }) : null;

const WORKER = "portfolio-sheet-shadow-sync-v1";
const SPREADSHEET_ID = "1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw";
const SHEET_NAME = "_Market_Data";
const SHEET_MAX_ROW = 200;
const GOOGLE_CREDENTIAL_SECRET = "fwios_google_sheets_service_account_json";

type ServiceAccount = {
  client_email: string;
  private_key: string;
  token_uri?: string;
};

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

function base64Url(data: Uint8Array | string) {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToDer(pem: string) {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function vaultSecret(name: string) {
  const rows = await sql!`select decrypted_secret
    from vault.decrypted_secrets
    where name=${name}
    limit 1`;
  return rows.length ? String(rows[0].decrypted_secret) : null;
}

async function getGoogleAccessToken(sa: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64Url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/spreadsheets",
    aud: sa.token_uri || "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  ));
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });
  const res = await fetch(sa.token_uri || "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const json = await res.json();
  if (!res.ok || !json?.access_token) {
    throw new Error(`GOOGLE_OAUTH_FAILED_${res.status}`);
  }
  return String(json.access_token);
}

async function googleJson(url: string, token: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers || {});
  headers.set("Authorization", `Bearer ${token}`);
  if (init.body != null) headers.set("Content-Type", "application/json");
  const res = await fetch(url, { ...init, headers });
  const text = await res.text();
  let data: any = text;
  try { data = text ? JSON.parse(text) : {}; } catch {}
  if (!res.ok) {
    const reason = typeof data === "string" ? data.slice(0, 240) : JSON.stringify(data).slice(0, 240);
    throw new Error(`GOOGLE_SHEETS_HTTP_${res.status}_${reason}`);
  }
  return data;
}

async function loadShadowPayload() {
  const healthRows = await sql!`select *
    from fwios.v_portfolio_market_price_health
    limit 1`;
  const health = healthRows[0] || {};
  if (String(health.pricing_gate || "") !== "PASS") {
    throw new Error(`PRICING_GATE_${String(health.pricing_gate || "MISSING")}`);
  }

  const rows = await sql!`
    with universe as (
      select distinct id.asset_symbol
      from fwios.instruments i
      join fwios.v_instrument_identity_current id on id.instrument_id=i.instrument_id
      where i.lifecycle_status='ACTIVE'
        and i.asset_class in ('Stock','Crypto')
        and i.instrument_type in ('COMMON_STOCK','CRYPTO_ASSET')
        and not (i.metadata ? 'qa_identity')
    ),
    snap as (
      select u.asset_symbol, fwios.pr7_native_usd_price_read_v1(u.asset_symbol) q
      from universe u
    )
    select
      asset_symbol,
      q->>'instrument_id' instrument_id,
      q->>'asset_class' asset_class,
      (q->>'price_usd')::numeric price_usd,
      q->>'currency' currency,
      q->>'status' status,
      q->>'quote_kind' quote_kind,
      q->>'provider' provider,
      q->>'observation_id' observation_id,
      q->>'observed_at' observed_at,
      q->>'session_date' session_date,
      q->>'valid_until' valid_until,
      (q->>'source_native_usd')::boolean source_native_usd,
      (q->>'shadow_only')::boolean shadow_only,
      (q->>'valuation_eligible')::boolean valuation_eligible,
      q->>'checked_at' checked_at
    from snap
    where (q->>'status') not in ('UNSUPPORTED','AMBIGUOUS_INSTRUMENT','MISSING')
    order by asset_symbol
  `;

  const openRows = await sql!`select distinct upper(asset_symbol) asset_symbol
    from fwios.v_portfolio_positions_current
    where upper(source_position_status)='OPEN'
      and coalesce(quantity,0)>0
    order by asset_symbol`;
  const openAssets = openRows.map((r: any) => String(r.asset_symbol));
  const symbols = new Set(rows.map((r: any) => String(r.asset_symbol).toUpperCase()));
  const uncovered = openAssets.filter((s) => !symbols.has(s));
  if (uncovered.length) throw new Error(`OPEN_HOLDING_MARKET_DATA_MISSING_${uncovered.join(",")}`);

  const fxRows = await sql!`select
      observation_value::numeric fx_rate,
      provider,
      observation_id,
      observed_at,
      session_date,
      provenance_status
    from fwios.market_observations
    where observation_type='FX'
      and value_currency='THB'
      and provenance_status='PASS'
      and observation_value>0
    order by observed_at desc,created_at desc
    limit 1`;
  if (!fxRows.length) throw new Error("USDTHB_FX_MISSING");
  const fx = fxRows[0];

  const openSet = new Set(openAssets.map((s) => s.toUpperCase()));
  const values = rows.map((r: any) => {
    const asset = String(r.asset_symbol).toUpperCase();
    const isOpen = openSet.has(asset);
    const nativeEligible = r.valuation_eligible === true;
    return [
      asset,
      String(r.instrument_id),
      String(r.asset_class),
      Number(r.price_usd),
      String(r.currency),
      String(r.status),
      String(r.quote_kind),
      String(r.provider),
      String(r.observation_id),
      String(r.observed_at),
      String(r.session_date),
      String(r.valid_until),
      r.source_native_usd === true,
      !isOpen,
      isOpen && nativeEligible,
      String(r.checked_at),
    ];
  });

  return {
    health,
    openAssets,
    values,
    fx: [
      "USDTHB",
      Number(fx.fx_rate),
      String(fx.provider),
      String(fx.observation_id),
      String(fx.observed_at),
      String(fx.session_date),
      String(fx.provenance_status),
    ],
  };
}

async function writeShadow(payload: Awaited<ReturnType<typeof loadShadowPayload>>, token: string) {
  const rowCount = payload.values.length;
  if (rowCount < 1 || rowCount >= SHEET_MAX_ROW) throw new Error("SHADOW_ROW_COUNT_OUT_OF_RANGE");
  const endRow = rowCount + 1;
  const formulas = payload.values.map((_, i) => {
    const row = i + 2;
    return [`=IF(AND(D${row}<>"",$S$2<>""),D${row}*$S$2,"")`];
  });

  const batchUrl = `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values:batchUpdate`;
  await googleJson(batchUrl, token, {
    method: "POST",
    body: JSON.stringify({
      valueInputOption: "USER_ENTERED",
      data: [
        { range: `${SHEET_NAME}!A2:P${endRow}`, majorDimension: "ROWS", values: payload.values },
        { range: `${SHEET_NAME}!Q2:Q${endRow}`, majorDimension: "ROWS", values: formulas },
        { range: `${SHEET_NAME}!R2:X2`, majorDimension: "ROWS", values: [payload.fx] },
      ],
    }),
  });

  const verifyRange = encodeURIComponent(`${SHEET_NAME}!A1:X${endRow}`);
  const verify = await googleJson(
    `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/${verifyRange}?majorDimension=ROWS&valueRenderOption=UNFORMATTED_VALUE`,
    token,
  );
  const actual = Array.isArray(verify?.values) ? verify.values : [];
  if (actual.length !== endRow) throw new Error("SHEET_VERIFY_ROW_COUNT_MISMATCH");

  const actualSymbols = new Set(actual.slice(1).map((r: any[]) => String(r?.[0] || "").toUpperCase()));
  const missingOpen = payload.openAssets.filter((s) => !actualSymbols.has(s));
  if (missingOpen.length) throw new Error(`SHEET_VERIFY_OPEN_HOLDING_MISSING_${missingOpen.join(",")}`);
  if (String(actual?.[0]?.[0] || "") !== "asset_symbol") throw new Error("SHEET_VERIFY_HEADER_MISMATCH");

  // Compare the native source values with Google's post-write calculation.
  for (let i = 0; i < payload.values.length; i++) {
    const expected = payload.values[i];
    const readback = actual[i + 1] || [];
    for (const col of [0, 1, 5, 6, 7, 8, 10, 14]) {
      if (String(readback[col] ?? "") !== String(expected[col] ?? "")) {
        throw new Error("SHEET_VERIFY_FIELD_MISMATCH_" + (i + 2) + "_" + col);
      }
    }
    const p = Number(expected[3]), r = Number(readback[3]);
    if (!Number.isFinite(p) || !Number.isFinite(r) ||
        Math.abs(p - r) > 1e-8 * Math.max(1, Math.abs(p))) {
      throw new Error("SHEET_VERIFY_USD_PRICE_MISMATCH_" + (i + 2));
    }
    if (expected[14] === true) {
      const expectedThb = p * Number(payload.fx[1]);
      const readThb = Number(readback[16]);
      if (!Number.isFinite(readThb) ||
          Math.abs(expectedThb - readThb) > 1e-7 * Math.max(1, Math.abs(expectedThb))) {
        throw new Error("SHEET_VERIFY_CONVERTED_PRICE_MISMATCH_" + (i + 2));
      }
    }
  }
  const actualFx = actual[1] || [];
  if (String(actualFx[17]) !== String(payload.fx[0]) ||
      Math.abs(Number(actualFx[18]) - Number(payload.fx[1])) > 1e-9 ||
      String(actualFx[19]) !== String(payload.fx[2]) ||
      String(actualFx[20]) !== String(payload.fx[3]) ||
      String(actualFx[23]) !== String(payload.fx[6])) {
    throw new Error("SHEET_VERIFY_FX_MISMATCH");
  }


  const staleStart = endRow + 1;
  if (staleStart <= SHEET_MAX_ROW) {
    const clearRange = encodeURIComponent(`${SHEET_NAME}!A${staleStart}:X${SHEET_MAX_ROW}`);
    await googleJson(
      `https://sheets.googleapis.com/v4/spreadsheets/${SPREADSHEET_ID}/values/${clearRange}:clear`,
      token,
      { method: "POST", body: "{}" },
    );
  }

  return { rowCount, endRow, openAssets: payload.openAssets };
}

async function recordState(status: string, detail: Record<string, unknown>) {
  try {
    await sql!`update fwios.system_state
      set state_value=state_value||${JSON.stringify({
        portfolio_tracker_shadow_sync_status: status,
        portfolio_tracker_shadow_sync_last_attempt: new Date().toISOString(),
        portfolio_tracker_shadow_sync_detail: detail,
        portfolio_tracker_shadow_sync_worker: WORKER,
        portfolio_tracker_shadow_sync_price_data_cutover: true,
      })}::jsonb,
      updated_at=now(),
      as_of_text=(now() at time zone 'Asia/Bangkok')::date::text
      where state_key='architecture_consolidation_v1'`;
  } catch {
    // The sync result is still returned even if the compatibility state receipt cannot be updated.
  }
}

Deno.serve(async (req: Request) => {
  if (!sql || !dbUrl) return Response.json({ ok: false, error: "DB_UNAVAILABLE" }, { status: 503 });
  if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

  const token = req.headers.get("x-fwios-automation-token") || "";
  const access = await sql!`select token_sha256
    from fwios.decision_refresh_automation_access
    where access_key='DECISION_REFRESH_WORKER' and active=true
    limit 1`;
  if (token.length < 32 || !access.length ||
      !safeEqual(await sha256Hex(token), String(access[0].token_sha256))) {
    return new Response("Unauthorized", { status: 401 });
  }

  let body: any = {};
  try { body = await req.json(); } catch {}
  const dryRun = body?.dry_run === true;
  const source = String(body?.source || "SCHEDULED");

  try {
    const payload = await loadShadowPayload();
    const base = {
      source,
      dry_run: dryRun,
      row_count: payload.values.length,
      open_asset_count: payload.openAssets.length,
      open_assets: payload.openAssets,
      pricing_gate: String(payload.health?.pricing_gate || ""),
      fx_rate_thb_per_usd: Number(payload.fx[1]),
      price_data_cutover: true,
      auto_trade: false,
    };

    if (dryRun) {
      await recordState("DRY_RUN_PASS", base);
      return Response.json({ ok: true, ...base, write_attempted: false });
    }

    const rawCredential = await vaultSecret(GOOGLE_CREDENTIAL_SECRET);
    if (!rawCredential) {
      await recordState("BLOCKED_GOOGLE_CREDENTIAL_MISSING", base);
      return Response.json({
        ok: false,
        ...base,
        write_attempted: false,
        error: "GOOGLE_SERVICE_ACCOUNT_CREDENTIAL_MISSING",
        required_vault_secret: GOOGLE_CREDENTIAL_SECRET,
      }, { status: 503 });
    }

    let sa: ServiceAccount;
    try { sa = JSON.parse(rawCredential); }
    catch { throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON_INVALID"); }
    if (!sa?.client_email || !sa?.private_key) throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON_INCOMPLETE");

    const googleToken = await getGoogleAccessToken(sa);
    const receipt = await writeShadow(payload, googleToken);
    await recordState("PASS", {
      ...base,
      sheet: SHEET_NAME,
      row_count: receipt.rowCount,
      service_account_email: sa.client_email,
    });

    return Response.json({
      ok: true,
      ...base,
      write_attempted: true,
      sheet: SHEET_NAME,
      verified_row_count: receipt.rowCount,
      service_account_email: sa.client_email,
    });
  } catch (error) {
    const message = (error instanceof Error ? error.message : String(error)).slice(0, 500);
    await recordState("ERROR", { source, dry_run: dryRun, error: message });
    return Response.json({
      ok: false,
      source,
      dry_run: dryRun,
      write_attempted: !dryRun,
      error: message,
      price_data_cutover: true,
      auto_trade: false,
    }, { status: 503 });
  }
});
