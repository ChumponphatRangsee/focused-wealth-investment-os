# TTWO AI-Generated Valuation Model Routing — SHADOW Experiment (2026-10-28)

**Result:** RESEARCH/DESIGN EXPERIMENT PASSED; **NOT PRODUCTION-APPROVED, NOT AN ACTIONABLE FAIR VALUE**.
**Owner request:** Test whether ChatGPT can construct a new archetype-based model/routing proposal when existing FWIOS Production Valuation Models cannot legitimately cover TTWO.
**Scope:** TTWO ONLY, source-read and deterministic simulated calculation. No canonical research APPLY, model registry mutation, valuation run, Decision, Opportunity Quality, portfolio changes or trade. Maintain `auto_trade=false`.

## What was actually tested against Supabase

- Database: `ysjbmeukwbfnxnwqchuq`, read-only, execution on 2026-10-28.
- `fwios.thesis_registry` TTWO has archetype `Premium Interactive Entertainment and Live Services`.
- Exact registry join `fwios.valuation_models` + `fwios.valuation_model_versions` finds **ZERO** production-approved model versions matching this archetype. Do not misuse Streaming/SaaS or bind an unreviewed model into production.
- AI proposed **`INTERACTIVE_ENTERTAINMENT_IP_DCF_V1`** — *unregistered, experimental SHADOW ONLY*. The routing gate checks active TTWO identity, absence of production model, 2026-06-30 SEC 10-Q accession, an exact source XBRL Revenue amount and a verified 2026-10-27 EOD close.
- Test SQL executed in live Supabase by SELECT only: `experiments/ttwo_ai_generated_routing_shadow_v1.sql`. Deterministic `generate_series(1,10)` projects hypothetical scenarios. **No data is persisted.**
- Test SQL `tests/valuation/test_ttwo_ai_generated_routing_shadow_v1.sql`: **22/22 PASS**, including model registry, ticker, price/SEC guards, scenarios, non-null positive discount/shares, ordering, no Production version, no valuation runs, no canonical metrics, no Decision or authorized APPLY receipts.
- Negative testing with the actual SELECT query forcibly setting each critical gate FALSE:
  - Verified price missing → **zero scenario rows**.
  - SEC revenue source conflict → **zero scenario rows**.
  - An existing production archetype model → **zero scenario rows**, requiring reroute.
  - Unmodified exact repeat → same three output values, demonstrating deterministic calculation on the same inputs.
- GitHub PR is draft; **CI workflow is not yet confirmed**.

## Primary reported figures versus experimental assumptions

**Issuer facts / bounded context (not yet all canonical metrics):**

| Fact | Amount / date | Source |
|---|---|---|
| FY2027 Net Bookings outlook | **$8.0–8.2B** (management *guidance*, not reported revenue) | 2026-08-07 earnings release |
| FY2027 Operating Cash Flow outlook | **More than $1.0B**, treated as $1.0B *lower-bound proxy* in experiment | 2026-08-07 earnings release |
| FY2027 capital expenditure outlook | Approx **$0.29B**, an estimate, not paid CapEx | 2026-08-07 investor slide deck |
| Q1 FY2027 GAAP revenue | **$1.5339B** | 2026-06-30 10-Q SEC companyfacts |
| Q1 FY2027 actual CFO | **−$0.1688B** | 2026-06-30 10-Q SEC companyfacts |
| 2026-06-30 cash + short investments | **$1.3649B + $0.4617B** | 2026-06-30 10-Q balance sheet |
| 2026-06-30 short + long debt | **$0.6299B + $1.8898B** | 2026-06-30 10-Q balance sheet |
| June 30 outstanding shares | **187M** (not same as diluted weighted-average for loss period) | 2026-06-30 10-Q |
| US EOD close | **$201.25**, independent **$201.28** | live `fwios.market_daily_closes`, 2026-10-27 |

Sources: 
- https://www.sec.gov/Archives/edgar/data/946581/000162828026054870/ttwo-20260630.htm
- https://www.sec.gov/Archives/edgar/data/946581/000162828026037434/ttwo-20260331.htm
- https://www.take2games.com/ir/news/take-two-interactive-software-inc-reports-results-fiscal-first-6
- https://ir.take2games.com/static-files/d790e168-8982-4ac3-ac06-9af093d9cb3c?pubDate=20260807

**All numbers below are unapproved hypothesis inputs, NOT externally validated estimates:** FY2028 Net Bookings shocks −10%/15%/30%; annual subsequent booking trend 2.5%/7%/10%; normalized owner cash proxy margin 12%/19%/25%; discount rates 12%/10.5%/9%; terminal growth 2%/2.5%/3%; prospective dilution 4%/3%/2%; scenario weights 25%/50%/25%. A ten-year cash proxy and terminal value are discounted; net debt is subtracted and shares adjusted. FY2027 cash proxy is floor CFO−guided CapEx **$0.71B** before any further adjustments and is **NOT audited FCFE or proof of normalized earnings**.

## Shadow outputs — illustrative ONLY

| Scenario | Shadow USD/share | Approval |
|---|---:|---|
| Bear | **$40.93** | HYPOTHETICAL / NO DECISION |
| Base | **$134.02** | HYPOTHETICAL / NO DECISION |
| Bull | **$322.78** | HYPOTHETICAL / NO DECISION |

**DO NOT** call these Production Fair Value, price targets or upside and do not compare them to market price to form a BUY. The very wide range is itself evidence of model uncertainty. For Base, terminal PV of ~$14.36B is **54%** of total enterprise-style discounted cashflow components ($12.15B+$14.36B); for Bull it is ~66%. That terminal-value concentration requires explicit review and robustness calibration.

## Missing validation before production eligibility

1. **Economic model review:** Is Net Bookings the right bridge to owner free cash flow? Validate cash conversion/revenue recognition, multi-year games-development capitalization and working capital, deferred revenue, franchise and platform splits, GTA VI launch scenarios, live-services retention and material 2026-09-30 8-K obligations. Distinguish pre-launch and post-launch cashflow shape.
2. **Source provenance / canonical ingest:** Controlled PREVIEW and explicitly authorized APPLY of needed metrics. The current demo uses date-stamped, manually checked issuer figures (some hardcoded solely for demonstration), not a fully source-bound canonical model input resolver.
3. **Dilution/debt:** Reconcile exact shares outstanding versus anti-dilutive securities, SBC and prospective dilution, lease obligations, cash restrictions and subsequent financing events.
4. **Model assumptions:** Set documented forecast-vs-reported identity, conservative calibration, independent valuation sanity checks, extreme-scenario stress tests (including delay/earnings disappointment), discount/terminal bounds, price sensitivity and risk of overfitting. Backtest only with correct point-in-time releases; avoid look-ahead.
5. **Formal registry and approved promotion:** Add a separate model-version and input-contract **proposal**; review the policy, validate tests and shadow behavior, then only with explicit owner approval register/authorize it. Scheduled ChatGPT should never promote a model on its own.
6. **True automation test:** A human-initiated connected ChatGPT session executed this experiment; it does **NOT** prove the existing Scheduled Task automatically generates/models/registers a new model. The scheduled Research Manager was separately verified to READ Supabase and run research PREVIEW; further job scope, permissions, audit receipts and CI are needed for automated candidate generation.

## Outcome / recommended follow-on

**AI can successfully design a prototype archetype routing rule, generate a runnable DCF calculator and regression tests for an unsupported business model. It has NOT yet demonstrated economic correctness or reliable unattended model generation.** Next implement an authorized model-candidate queue + human model-review gate, source-aware input resolver, point-in-time sensitivity and independent checks. Keep production `Valuation`, `Decision` and `auto_trade` unchanged; do not broaden scope beyond TTWO without owner direction.

Link alongside existing TTWO initial E2E proof: https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/96 .
