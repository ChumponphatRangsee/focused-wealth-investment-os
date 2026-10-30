# Changelog — Asset Price Data Service

## 1.0.0 — 2026-10-30: Operational price-only cutover verified

- Verified naturally scheduled Crypto/FX/Sheet sync: all three Edge HTTP responses 200, Crypto 6/6, FX 1/1, Sheet readback PASS and no Portfolio writes.
- Reduced production `fwios` to five canonical price/identity tables, one view and 13 routines. Quarantined 87 historical tables in private legacy archive without deleting accounting history; unscheduled seven inactive jobs, keeping only #14/#15/#16.
- Retired legacy SQL functions/views; 16 old Edge slugs deployed as HTTP 410 responses. Pinned former archive-only trigger search_path.
- Removed 187 out-of-scope tracked source/CI/test/migration files from the current working tree, with Git history retained and retirement receipt. Replaced inactive CI with price-only source checks.
- **Do not claim permanent data cleanup:** 87 historical tables retained, no independently verified database dump/restore on current Free tier.

## 1.0.0 — 2026-10-29: Documentation scope reset

- Restrict product contract to native Crypto USD + USD/THB FX → Supabase → Google Sheet.
- Remove obsolete investment roadmap, thesis/valuation/decision and portfolio accounting scope.
