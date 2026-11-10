# SEC-first Research Evidence MVP v0 (isolated)

**Implementation state:** code and offline tests only. **No Supabase deployment, database tables, worker, Cron, portfolio write, paid API or trading.** The user authorized starting the MVP on 2026-11-10; this does **not** authorize Production activation.

This independent Python 3.12 standard-library pilot reads **two SEC EDGAR JSON documents for one CIK**: Submissions and Company Facts. It produces evidence of USD, US-GAAP facts from 10-K/10-Q and amendments (10-K/A, 10-Q/A), including the complete source SHA-256s, SEC accession, original filing form, fiscal period, unit/value, verified SEC acceptance timestamp, first observed time, SEC URLs, and quarantine reasons.

**No historical backtest certification:** SEC XBRL filed date and fiscal period end are not publication timestamps. Submissions acceptanceDateTime documents SEC acceptance but is not by itself proof of the exact earliest public availability of every fact. Historical first_public_at remains null. A fact can pass current observed research only after its SEC accepted time **and** first FWIOS observation have passed the as-of time. Never use this pilot for historical point-in-time backtests.

## Run offline by default — no network

Use SEC-compatible JSON files with the **real** time the files were obtained, not a fabricated timestamp:

    python -m research.sec_first_mvp.cli --cik 320193 \
      --submissions-file /path/to/CIK0000320193_submissions.json \
      --companyfacts-file /path/to/CIK0000320193_companyfacts.json \
      --retrieved-at 2026-11-10T04:00:00Z \
      --as-of 2026-11-10T04:01:00Z \
      --out-file /path/to/new-evidence.json

Default output: stdout JSON. The optional --out-file creates a new file with mode 0600 and fails if the path already exists. No overwrites, database, Sheet writes or trading.

Unit tests:

    python -m unittest discover -s tests/research -p 'test_*.py' -v

## Explicit manual SEC-only fetch (not invoked in CI)

To fetch **exactly two** public SEC JSON documents for one known CIK:

    python -m research.sec_first_mvp.cli --cik 320193 --fetch \
      --user-agent "Your Actual Organization research-contact@example.org" \
      --out-file /path/to/new-evidence.json

Replace the placeholder with a genuine operator or organization and reachable email. Never invent an identifying User-Agent. The client calls only https://data.sec.gov, checks HTTPS, response type and size, serializes the two requests with 250ms spacing, and does not automatically retry. SEC fair access limit is **10 requests/second**; per-process pacing does not coordinate independent clients.

The SEC "recent" submissions arrays omit older filings. Facts whose accession is outside this array are quarantined with ACCEPTANCE_NOT_VERIFIED_IN_RECENT; the pilot does not guess their timestamps or silently fetch historical submission pages. Broader archival coverage requires a separate reviewed capability.

## Hard MVP boundaries

- No new paid API, optional Massive subscription, new Supabase research schema, queue, Cron or Edge Worker.
- Current Production price contract, three price tables, six Crons, two Edge Functions and Google Sheet accounting remain untouched.
- Candidate fact count capped at 500 and truncation explicitly disclosed; no complete filing or S&P 500 coverage claim.
- Preserve separate original and amended accession facts. No automatic winner/latest override.
- Fail closed on CIK mismatch, form/date mismatch, missing SEC acceptance time, invalid units/periods, future filings, uncertain availability and conflicting same-accession values.
- First live 3–5 company evidence pilot, durable private storage, actual RLS/grants and production deployment need separately reviewed authorization.
- SEC source and access policy: https://www.sec.gov/search-filings/edgar-application-programming-interfaces and https://www.sec.gov/search-filings/edgar-search-assistance/accessing-edgar-data

See planned architecture: docs/database/planned/DB-ARCH-2.0/ (PLANNED, NOT_DEPLOYED).
