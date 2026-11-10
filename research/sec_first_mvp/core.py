"""SEC-first research evidence MVP v0.

Offline-first, no database writes, no trading, and no price-service integration.
SEC "filed" is NOT the first-known/first-public timestamp. The as-of gate
conservatively uses FWIOS first observation (retrieved_at), so this pilot
cannot be mistaken for a certified historical backtest.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from hashlib import sha256
import json
import math
import re
import time
from typing import Any
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

SEC_ORIGIN = "https://data.sec.gov"
SEC_FORMS = frozenset({"10-K", "10-Q", "10-K/A", "10-Q/A"})
# An allowlist, not an assertion of semantic equivalence of different revenue tags.
CONCEPTS = {
    "Assets": "instant",
    "Liabilities": "instant",
    "StockholdersEquity": "instant",
    "NetIncomeLoss": "duration",
    "OperatingIncomeLoss": "duration",
    "NetCashProvidedByUsedInOperatingActivities": "duration",
    "Revenues": "duration",
    "RevenueFromContractWithCustomerExcludingAssessedTax": "duration",
}
ACC_RE = re.compile(r"^\d{10}-\d{2}-\d{6}$")
MAX_RESPONSE_BYTES = 25_000_000
MAX_FACT_ROWS = 500  # bounded report, not a statement of complete filing coverage


class SECError(ValueError):
    """Fail-closed SEC data, identity, transport or timestamp error."""


def normalize_cik(cik: object) -> str:
    if isinstance(cik, bool):
        raise SECError("CIK_BOOL_INVALID")
    s = str(cik).strip()
    if not s.isascii() or not s.isdecimal() or not 1 <= len(s) <= 10 or int(s) == 0:
        raise SECError("CIK_INVALID")
    return s.zfill(10)


def iso_utc(value: str | datetime, label: str) -> datetime:
    try:
        d = value if isinstance(value, datetime) else datetime.fromisoformat(value.replace("Z", "+00:00"))
    except (ValueError, AttributeError, TypeError) as e:
        raise SECError(f"{label}_INVALID") from e
    if d.tzinfo is None or d.utcoffset() is None:
        raise SECError(f"{label}_MISSING_TZ")
    return d.astimezone(timezone.utc)


def iso_date(value: object, label: str) -> date:
    try:
        if not isinstance(value, str):
            raise ValueError()
        return date.fromisoformat(value)
    except (ValueError, TypeError) as e:
        raise SECError(f"{label}_INVALID") from e


def checksum(document: object) -> str:
    raw = json.dumps(document, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
    return sha256(raw.encode("utf-8")).hexdigest()


def sec_urls(cik: object) -> tuple[str, str]:
    key = normalize_cik(cik)
    return (f"{SEC_ORIGIN}/submissions/CIK{key}.json",
            f"{SEC_ORIGIN}/api/xbrl/companyfacts/CIK{key}.json")


def _fetch_json(url: str, user_agent: str, *, timeout_seconds: float = 12.0) -> dict:
    """Fixed SEC origin only. Explicit manual caller; never called at import."""
    urlparts = urlsplit(url)
    if urlparts.scheme != "https" or urlparts.netloc != "data.sec.gov" or urlparts.query or urlparts.fragment:
        raise SECError("NON_SEC_URL_BLOCKED")
    # A real, operator-provided organization + email are required (not stored in repo).
    if not re.search(r"\S+\s+\S+@\S+\.\S+", user_agent):
        raise SECError("IDENTIFYING_USER_AGENT_REQUIRED")
    req = Request(url, headers={"User-Agent": user_agent, "Accept": "application/json"})
    try:
        with urlopen(req, timeout=timeout_seconds) as resp:
            final = urlsplit(resp.geturl())
            if final.scheme != "https" or final.netloc != "data.sec.gov":
                raise SECError("SEC_REDIRECT_BLOCKED")
            if resp.status != 200:
                raise SECError(f"SEC_HTTP_{resp.status}")
            content_type = resp.headers.get("Content-Type", "").lower()
            if "json" not in content_type:
                raise SECError("SEC_CONTENT_TYPE_INVALID")
            raw = resp.read(MAX_RESPONSE_BYTES + 1)
            if len(raw) > MAX_RESPONSE_BYTES:
                raise SECError("SEC_RESPONSE_TOO_LARGE")
        body = json.loads(raw)
    except (OSError, json.JSONDecodeError, UnicodeDecodeError) as e:
        raise SECError("SEC_FETCH_OR_JSON_INVALID") from e
    if not isinstance(body, dict):
        raise SECError("SEC_JSON_OBJECT_REQUIRED")
    return body


def fetch_company_documents(cik: object, user_agent: str) -> tuple[dict, dict, datetime]:
    """Manual opt-in only: two GETs, spaced >= 250ms, no retries/schedulers.
    
    The service has a 10 requests/second fair-access ceiling across client activity.
    This local 4 req/s spacing does NOT claim enforcement across other processes.
    """
    submissions_url, facts_url = sec_urls(cik)
    s = _fetch_json(submissions_url, user_agent)
    time.sleep(0.25)
    f = _fetch_json(facts_url, user_agent)
    return s, f, datetime.now(timezone.utc)


def _filings_from_recent(submissions: dict) -> tuple[dict[str, dict], list[str]]:
    try:
        recent = submissions["filings"]["recent"]
        columns = ("accessionNumber", "form", "filingDate", "acceptanceDateTime")
        values = [recent[c] for c in columns]
    except (KeyError, TypeError) as e:
        raise SECError("SUBMISSIONS_RECENT_FIELDS_MISSING") from e
    if any(not isinstance(v, list) for v in values) or len({len(v) for v in values}) != 1:
        raise SECError("SUBMISSIONS_RECENT_COLUMNS_MISALIGNED")
    result: dict[str, dict] = {}
    warnings: list[str] = []
    for accn, form, filed, accepted in zip(*values):
        if form not in SEC_FORMS:
            continue
        if not isinstance(accn, str) or not ACC_RE.fullmatch(accn):
            warnings.append("RECENT_ACCESSION_INVALID")
            continue
        try:
            filed_date = iso_date(filed, "FILED_ON")
            accepted_at = iso_utc(accepted, "ACCEPTED_AT").isoformat()
        except SECError:
            warnings.append(f"INVALID_RECENT_TIME:{accn}")
            continue
        entry = {"accession": accn, "form": form, "filed_on": filed_date.isoformat(),
                 "accepted_at": accepted_at}
        if accn in result and result[accn] != entry:
            warnings.append(f"CONFLICTING_RECENT_FILING:{accn}")
            result.pop(accn, None)
            continue
        result[accn] = entry
    return result, warnings


def _is_valid_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and (
        not isinstance(value, float) or math.isfinite(value)
    )


def build_evidence(
    cik: object,
    submissions: dict,
    companyfacts: dict,
    *,
    retrieved_at: str | datetime,
    as_of: str | datetime,
    limit: int = MAX_FACT_ROWS,
) -> dict[str, Any]:
    """Pure function: validates SEC docs and produces a deterministic evidence report.

    Never writes to DB/Sheet. FAIL CLOSED for unknown acceptance timestamps, missing
    accession, mismatch, and as-of prior to first FWIOS observation.
    """
    key = normalize_cik(cik)
    if not isinstance(submissions, dict) or not isinstance(companyfacts, dict):
        raise SECError("SEC_DOC_OBJECT_REQUIRED")
    if normalize_cik(submissions.get("cik")) != key or normalize_cik(companyfacts.get("cik")) != key:
        raise SECError("SEC_CIK_IDENTITY_MISMATCH")
    observed = iso_utc(retrieved_at, "RETRIEVED_AT")
    decision = iso_utc(as_of, "AS_OF")
    if not isinstance(limit, int) or isinstance(limit, bool) or not 1 <= limit <= MAX_FACT_ROWS:
        raise SECError("LIMIT_INVALID")
    filing_map, warnings = _filings_from_recent(submissions)
    evidence_sha = checksum(companyfacts)
    filing_sha = checksum(submissions)
    taxonomies = companyfacts.get("facts")
    if not isinstance(taxonomies, dict):
        raise SECError("COMPANYFACTS_FACTS_MISSING")
    gaap = taxonomies.get("us-gaap", {})
    if not isinstance(gaap, dict):
        raise SECError("COMPANYFACTS_GAAP_MALFORMED")
    accepted, quarantined = [], []
    candidates: list[tuple[str, dict]] = []
    for tag, duration in CONCEPTS.items():
        concept = gaap.get(tag)
        if concept is None:
            continue
        if not isinstance(concept, dict) or not isinstance(concept.get("units"), dict):
            raise SECError("CONCEPT_UNITS_MALFORMED")
        usd = concept["units"].get("USD", [])
        if not isinstance(usd, list):
            raise SECError("CONCEPT_USD_UNITS_MALFORMED")
        for item in usd:
            if not isinstance(item, dict):
                raise SECError("FACT_ROW_MALFORMED")
            if item.get("form") in SEC_FORMS:
                candidates.append((tag, item))
    # Deterministically cap the *input*, not just PASS rows. Report that sampling occurred.
    candidates.sort(key=lambda x: (
        str(x[1].get("filed", "")), str(x[1].get("accn", "")),
        x[0], str(x[1].get("end", "")), str(x[1].get("start", "")),
        str(x[1].get("val", ""))
    ), reverse=True)
    input_count = len(candidates)
    for tag, item in candidates[:limit]:
        accn = item.get("accn")
        base = {"accession": accn, "taxonomy": "us-gaap", "tag": tag, "unit": "USD",
                "source_sha256": evidence_sha}
        reason = None
        try:
            if not isinstance(accn, str) or not ACC_RE.fullmatch(accn):
                raise SECError("ACCESSION_INVALID")
            form = item.get("form")
            if form not in SEC_FORMS:
                raise SECError("FORM_INVALID")
            if not _is_valid_number(item.get("val")):
                raise SECError("VALUE_INVALID")
            end = iso_date(item.get("end"), "END")
            start = item.get("start")
            if CONCEPTS[tag] == "duration":
                if start is None:
                    raise SECError("DURATION_START_MISSING")
                start_date = iso_date(start, "START")
                if start_date > end:
                    raise SECError("DURATION_PERIOD_INVALID")
                start = start_date.isoformat()
            elif start is not None:
                raise SECError("INSTANT_HAS_START")
            source_filed = iso_date(item.get("filed"), "FACT_FILED")
            if end > source_filed:
                raise SECError("FISCAL_END_AFTER_FILING")
            entry = filing_map.get(accn)
            if not entry:
                raise SECError("ACCEPTANCE_NOT_VERIFIED_IN_RECENT")
            if entry["form"] != form or entry["filed_on"] != source_filed.isoformat():
                raise SECError("FILING_IDENTITY_OR_DATE_CONFLICT")
            accepted_at = iso_utc(entry["accepted_at"], "ACCEPTED_AT")
            if accepted_at > decision:
                raise SECError("FILING_AFTER_AS_OF")
            if observed < accepted_at:
                raise SECError("SOURCE_OBSERVED_BEFORE_FILING_ACCEPTANCE")
            if observed > decision:
                raise SECError("SOURCE_NOT_OBSERVED_AS_OF")
            base.update({"form": form, "filing_date": source_filed.isoformat(),
                         "accepted_at": accepted_at.isoformat(), "period_start": start,
                         "period_end": end.isoformat(), "value": item["val"],
                         "fy": item.get("fy"), "fp": item.get("fp"),
                         "frame": item.get("frame"), "first_seen_at": observed.isoformat(),
                         "first_public_at": None, "historical_backtest_certified": False,
                         "availability_policy": "OBSERVED_AT_OR_AFTER_RETRIEVAL",
                         "source_filing_sha256": filing_sha})
        except SECError as error:
            reason = str(error)
        if reason:
            quarantined.append({**base, "reason": reason})
        else:
            accepted.append(base)
    # Preserve both original and amended filings; never pick latest as historical truth.
    # Do not silently certify multiple conflicting values within the same accession/period.
    grouped: dict[tuple, list[dict]] = {}
    for record in accepted:
        g = (record["accession"], record["tag"], record["period_start"],
             record["period_end"], record["unit"])
        grouped.setdefault(g, []).append(record)
    safe = []
    for rows in grouped.values():
        if len({str(x["value"]) for x in rows}) > 1:
            quarantined.extend({**x, "reason": "CONFLICTING_VALUES_SAME_ACCESSION"} for x in rows)
        else:
            safe.append(rows[0])
    safe.sort(key=lambda x: (x["accession"], x["tag"], x["period_end"], str(x["period_start"])))
    quarantined.sort(key=lambda x: (str(x.get("accession")), x["tag"], x["reason"]))
    return {
        "contract": "SEC-FIRST-RESEARCH-MVP-0.1",
        "status": "PASS_CURRENT_RESEARCH_ONLY" if safe else "BLOCKED_NO_VERIFIED_FACTS",
        "cik": key,
        "company_name": submissions.get("name"),
        "retrieved_at": observed.isoformat(),
        "as_of": decision.isoformat(),
        "source_urls": {"submissions": sec_urls(key)[0], "companyfacts": sec_urls(key)[1]},
        "source_hashes": {"submissions_sha256": filing_sha, "companyfacts_sha256": evidence_sha},
        "coverage": {"submission_scope": "recent_only", "concept_allowlist": sorted(CONCEPTS),
                     "eligible_rows_before_limit": input_count, "rows_examined": min(input_count, limit),
                     "truncated": input_count > limit, "accepted": len(safe),
                     "quarantined": len(quarantined), "review_warnings": warnings},
        "filings": sorted(filing_map.values(), key=lambda x: x["accession"]),
        "facts": safe,
        "quarantined": quarantined,
        "guardrails": {"point_in_time_backtest_certified": False,
                       "no_automatic_price_or_portfolio_writes": True,
                       "no_live_database_or_trading_integration": True}
    }
