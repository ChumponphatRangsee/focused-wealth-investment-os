# Physical deletion of retired Edge Functions — remaining manual task

Verified against Supabase Edge deployment inventory on 2026-10-30. **Sixteen obsolete slugs remain deployed with inert HTTP 410 handlers.** Their `ACTIVE` metadata refers to a deployed tombstone, not the legacy business logic.

The connected Supabase integration supports only listing, reading and deploying functions, **not deleting deployed functions**, so this step could not be completed programmatically from ChatGPT.

Open **[Supabase Edge Functions dashboard](https://supabase.com/dashboard/project/ysjbmeukwbfnxnwqchuq/functions)** for production project `focused-wealth-investment-os`. On each obsolete function, use the function's management/settings menu and Delete function option (UI wording may vary). Verify the exact slug before confirming. Avoid other projects.

## DELETE ONLY these 16 retired Edge slugs

- `dashboard-refresh-csv-v1`
- `dashboard-refresh-probe-v1`
- `dashboard-refresh-env-probe-v1`
- `dashboard-refresh-db-probe-v1`
- `dashboard-refresh-query-probe-v1`
- `dashboard-refresh-role-probe-v1`
- `decision-refresh-worker-v1`
- `decision-refresh-provider-validator-v1`
- `decision-refresh-price-lag-retry-v1`
- `market-daily-close-worker-v1`
- `portfolio-mtm-refresh-v1`
- `market-refresh-orchestrator-v1`
- `market-price-canary-v1`
- `market-price-usd-shadow-v1`
- `portfolio-sheet-shadow-sync-v1`
- `scanner-refresh-csv-v1`

## KEEP these two supported functions

- `price-market-refresh-v1` (Crypto/FX collector v2)
- `price-sheet-sync-v1` (Sheet price sync v2)

When finished, **only two Edge functions should remain** in Supabase. Confirm Cron #14 and #15 invoke `price-market-refresh-v1` and #16 invokes `price-sheet-sync-v1`. Run a fresh Crypto/FX → Supabase → Google Sheet readback and re-check the six price database functions and five tables.

This physical deployment step is distinct from SQL schema cleanup, which was verified complete. Do not use database `DROP SCHEMA` for Edge Functions.
