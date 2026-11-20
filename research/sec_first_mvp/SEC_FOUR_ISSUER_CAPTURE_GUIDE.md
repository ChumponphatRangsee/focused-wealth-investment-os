# Manually capture 8 SEC JSON files (Phase 2)

**Status: OPERATOR-READY, NOT EXECUTED AGAINST SEC.** This is not a background job and cannot be scheduled. The Phase 2 capture does not require, create or touch Supabase, Google Sheets, Price Service, portfolio accounting or any trade.

## One explicit live capture (only in a network-capable terminal)

This workflow intentionally requires the operator to specify **their own real name/organization and reachable email**. A public GitHub commit email must NOT be reused as implied consent. The variable's value is never written into the evidence directory or printed in stdout. Do not enter a placeholder email and do not commit this value.

Linux/macOS:

~~~bash
export FWIOS_SEC_USER_AGENT='YourRealOrganization YourRealContact@your-real-domain.tld'
python -m research.sec_first_mvp.batch_capture --fetch \
  --out-dir ./private-sec-snapshot-20261111-a
unset FWIOS_SEC_USER_AGENT
~~~

PowerShell:

~~~powershell
$env:FWIOS_SEC_USER_AGENT = 'YourRealOrganization YourRealContact@your-real-domain.tld'
python -m research.sec_first_mvp.batch_capture --fetch --out-dir .\private-sec-snapshot-20261111-a
Remove-Item Env:\FWIOS_SEC_USER_AGENT
~~~

Replace both example name and email with the **real operator's** values before running. Requires Python 3.12 and SEC network access. The directory must not already exist. This module is **never called from CI** and fails closed without \`--fetch\`. No automatic retry. Exactly eight GETs, fixed to:

| Issuer | CIK | JSON |
|---|---|---|
| MSFT | 0000789019 | submissions + companyfacts |
| NVDA | 0001045810 | submissions + companyfacts |
| TTWO | 0000946581 | submissions + companyfacts |
| TLN | 0001622536 | submissions + companyfacts |

Origin is fixed to \`https://data.sec.gov\`. SEC requests are serialized with 250 ms spacing (at most four per second from this process, **not** a cross-process rate-limit guarantee). Each reply must be HTTP 200, JSON content-type, no cross-URL redirect, no larger than 25,000,000 bytes, parseable JSON and matching CIK. A missing/invalid submission or US-GAAP facts shape is blocked. No vendor/SEC payload is silently inferred.

## Expected artifacts, only AFTER successful execution

- Eight **raw, exact HTTP JSON byte** files: \`MSFT_CIK0000789019_submissions.json\`, \`MSFT_CIK0000789019_companyfacts.json\`, and corresponding NVDA, TTWO, TLN files.
- Eight private \`*.receipt.json\` sidecars with source URL, fixed ticker+CIK, HTTP status 200, \`request_started_at_utc\`, \`retrieved_at_utc\`, response bytes, \`raw_sha256\`, \`canonical_json_sha256\`, \`first_public_at=null\`, \`historical_asof_certified=false\`.
- One final private \`manifest.json\`, emitted **only if all eight requests and validations finish**, reporting \`CAPTURE_COMPLETE_8_OF_8\`.
- All files created non-overwriting with POSIX mode 0600 in a new 0700 directory. A partial failure leaves the already written valid files and receipts but **no** complete manifest; do not call it PASS.

The SHA-256 of the original exact bytes establishes integrity of **this capture**, not that the SEC knew about the facts at a past date. The separate canonical-json SHA-256 matches existing Phase-1 \`checksum\` semantics. The observed retrieval timestamp is from this run only, not a fabricated historical first-public timestamp.

## Evidence verification (after capture)

~~~bash
python -m unittest discover -s tests/research -p 'test_*.py' -v
python - <<'PY'
from pathlib import Path
import hashlib, json
root = Path('private-sec-snapshot-20261111-a')
m = json.loads((root/'manifest.json').read_text())
assert m['status'] == 'CAPTURE_COMPLETE_8_OF_8'
assert len(m['receipts']) == 8
for receipt in m['receipts']:
    f = root / f"{receipt['ticker']}_CIK{receipt['issuer_cik']}_{receipt['document_kind']}.json"
    assert hashlib.sha256(f.read_bytes()).hexdigest() == receipt['raw_sha256']
print('8 raw-byte SHA-256 hashes verified')
PY
~~~

**Next, and not included in capture acceptance:** Run Phase-1 \`build_evidence\` separately for each original JSON pair using the *real* \`retrieved_at_utc\` from both receipts. Use the later of the two timestamps as the conservative evidence-observed time. Only a parser result with accession, CIK, SEC filing date and acceptance corroboration plus quarantine counts may claim current research acceptance. \`first_public_at\` is still unknown, so historical PIT backtests remain uncertified.

## Security / rollback

- Do not upload raw snapshots publicly, print operator contact, push them into GitHub, or use them as held-stock market prices. Raw SEC rights/retention require review before any durable shared storage.
- Stop instantly on unexpected source/certificate, rate limit, wrong CIK, malformed JSON or transport error. Partial local evidence remains; do not overwrite to 'fix' receipts.
- Rollback is local only: revoke terminal contact environment variable and quarantine or securely remove the new private output directory *under a separate user approval of evidence disposal*. There is **no production DB / Worker / Cron / Sheet state to roll back**.
- Online HTTP requests were not possible from the research tool's current runtime at 2026-11-11, and an operator-supplied real contact string was absent. Never claim that this document or mock tests constitute a live SEC fetch.

See: [SEC official APIs](https://www.sec.gov/search-filings/edgar-application-programming-interfaces) and [fair access](https://www.sec.gov/about/developer-resources).
