# Research closeout — 2026-09-05

## Outcome and scope

Recovered the cross-system closeout of `SECTOR-CS-FULL-20260905-01`.
This closes the recorded Communication Services research job, not the entire Investment OS.
The project remains ACTIVE; M1 hardening and M2–M4 are not complete.

Supabase already recorded research COMPLETE, while Sheets still showed RUNNING / FAST_DISCOVERY and the repository still instructed an executor to start the run. Repeating research would duplicate effort and could create conflicting histories.

## Reconciled evidence

| Check | Recorded result |
|---|---|
| Fast Discovery | 20 inputs → 8 selected; 235.985 seconds |
| Light Research | 8 inputs → 5 selected; 188.735 seconds |
| Deep Research | 5 inputs → 3 selected; 439.009 seconds |
| Total measured stage time | 863.729 seconds / 14.4 minutes |
| Persisted deep evidence | RDDT 8; PINS 8; NFLX 9; all stored Tier A / VERIFIED / PASS |
| Deferred deep research | TMUS and WMG; top-three-first policy |
| New production promotions | 0; valuation remains blocked |
| Current valuation coverage | 11 / 18 = 61.1% |
| Root model blockers | 7 |
| Controller handoff | MODEL_FACTORY_AFTER_CURRENT_SECTOR |
| Existing model regression records | 11 PASS |
| Existing pipeline regression records | 6 PASS |

These are checks of persisted records and live formulas, not an independent financial-source refresh. The 14.4-minute result is one measured run, not a guaranteed SLA. No cache hits were recorded in this run and parallel worker execution was not independently demonstrated.

## Repairs

- Restored the 20-name research universe to `Sector_Universe!A89:Y108`, preserving formula-owned column T. Rough screening signals were not written as verified expected-return scores.
- Added one final history record at `Sector_Run_History!A9:R9` with zero production promotions and zero immediate buys.
- Restored the three Communication Services blockers at `Data_Quality_Gates!R19:AF21`, preserving AG:AJ formulas. The MANUAL retry choice is explicitly allowed for these documented model-development tasks.
- Reconciled the controller and foundation summaries with 61.1% coverage and seven open blockers. Released the matching run lock to IDLE and paused sector automation for controller-required model work. Financials remains queued.
- Corrected the stale configured-model expectation from 17 to the 20 verified in both the live Sheet registry and Supabase. This changes a documentation/check expectation, not model implementation or promotion.
- Kept the existing five global active candidates; no new candidate qualifies for promotion on the supplied state.
- Corrected the repository roadmap, readme and stale operational pointers.
- Added a read-only no-promotion closeout checker with synthetic failure cases. No live private portfolio snapshot is committed.

## Remaining M1 acceptance failures

1. **Cache freshness:** `v_latest_reusable_evidence` filters stored `FRESH` / `HISTORICAL_REFERENCE` text. It does not recompute aging or detect earnings after research. It also treats a null machine status as PASS in its definition, although no such eligible row was observed. Date fields contain mixed ISO text and legacy Sheet serial dates. A safe fix needs explicit date normalization, fail-closed provenance/status checks, source-specific TTL/event invalidation, and tests proving old or invalid evidence cannot return to eligibility. Until then, independently revalidate eligibility before reuse; do not enable unattended cache reuse.
2. **Controller boundary:** `v_operating_controller` says finish the current sector at 50–70% coverage, while `v_research_pipeline_controller.model_debt_blocks_sector_completion` becomes true whenever mode is not DISCOVERY. The latter should permit completion of the already-running sector in the AFTER_CURRENT_SECTOR state, while still blocking a new sector. Test the transition and critical lower-coverage modes before applying a fix.
3. **Execution enforcement:** persisted source-router/parallelizability flags and six recorded policy checks are not proof of an implemented parallel runner or enforceable stage transitions. Preserve this distinction in future acceptance reports.

## Next implementation order

Repair the M1 failures above, then follow the model-debt controller: Digital Advertising for RDDT/PINS is the highest-ranked model task. An FCF kernel alone is insufficient; normalized inputs, SBC/dilution treatment, forecast assumptions and independent model regression anchors must be documented. Never fill unsupported values simply to raise coverage.

M2 requires native current-price/mispricing and portfolio-fit parity. M3 requires capital-allocation and rebalancing simulation with human execution only. M4 requires tested monitoring, scheduling and recovery. Their roadmap checkboxes remain open.

## Repeatable no-promotion closeout

Use the utility only for a run with zero new promotions. A promoted run requires a separate full decision-gate acceptance workflow.

1. Re-read the exact live run, controller, stages, evidence, blockers, Sheet controller/history/universe and repository version. Keep private snapshots out of Git.
2. Confirm the run IDs agree. If another run owns the lock, stop; never clear it.
3. Ensure terminal stages, actual selected ticker sets, telemetry and evidence lineage agree. A stored COMPLETE label alone is insufficient.
4. Reconcile the missing history/universe/blocker records by stable IDs, avoiding duplicate appends. Preserve formula ownership.
5. Re-read the global active set. Retain it only when no new candidate passes production promotion.
6. Release only the matching completed run; persist the controller-required next action. Read back all changed state.
7. Update the roadmap and repository sync reference, then run the checker on a newly collected snapshot (15-minute maximum age).

```bash
python -m unittest discover -s tests -v
python scripts/check_closeout.py /absolute/path/to/private-snapshot.json
```

Snapshot keys are illustrated by the synthetic `fixture()` in `tests/test_closeout.py`. Map `run`, `stages`, `stage_candidates`, `evidence`, `blockers`, `candidates` and `controller` from their corresponding `fwios` rows/views. Collect the Sheet fields from connector readback, not from the intended write payload. `contracts` must include `github`, `sheet` and `supabase`; `observed_at` must be a timezone-aware collection timestamp. Use `next_action=MODEL_SPRINT` whenever the live controller disallows discovery. A PASS certifies recorded no-promotion closeout consistency only.

The checker deliberately never performs mutations, trades, network calls or credential handling. It fails closed on malformed or missing fields through its command-line interface.

## Security observations

The live security advisor reported informational RLS-without-policy notices for private `fwios` tables. Both `anon` and `authenticated` lacked schema USAGE. This is consistent with the existing internal/service-only access model; no public grants or permissive policies were added. No auth, table, function or view definitions were changed during closeout.
