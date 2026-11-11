"""Manual, SEC-only 4-issuer / 8-document snapshot with verifiable byte receipts.

Never invoked by CI or import. Requires a genuine operator contact User-Agent in
FWIOS_SEC_USER_AGENT; a public GitHub profile email is NOT assumed consent.
Creates a NEW private local directory. No Supabase, Google Sheet or trading calls.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.request import Request, urlopen

from .core import MAX_RESPONSE_BYTES, SECError, checksum, normalize_cik, sec_urls


ISSUERS = (
    ("MSFT", "0000789019"),
    ("NVDA", "0001045810"),
    ("TTWO", "0000946581"),
    ("TLN", "0001622536"),
)
KINDS = ("submissions", "companyfacts")
CONTACT_RE = re.compile(r"\S+\s+\S+@\S+\.\S+")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def valid_contact(user_agent: str) -> bool:
    if not isinstance(user_agent, str) or not CONTACT_RE.search(user_agent):
        return False
    return not re.search(r"(?i)@(?:example[.]com|example[.]org|example[.]net)\b", user_agent)


def write_new_private(path: Path, data: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def fetch_document(
    ticker: str,
    cik: str,
    kind: str,
    user_agent: str,
    *,
    opener=urlopen,
) -> tuple[dict, bytes]:
    """Single allowed endpoint. Returns exact HTTP body bytes and a fresh receipt."""
    if not valid_contact(user_agent):
        raise SECError("IDENTIFYING_USER_AGENT_REQUIRED")
    urls = dict(zip(KINDS, sec_urls(cik)))
    if kind not in urls:
        raise SECError("SEC_DOCUMENT_KIND_UNSUPPORTED")
    expected_url = urls[kind]
    request = Request(
        expected_url,
        headers={"User-Agent": user_agent, "Accept": "application/json"},
    )
    started = utc_now()
    try:
        with opener(request, timeout=12) as response:
            if response.status != 200:
                raise SECError(f"SEC_HTTP_{response.status}")
            if response.geturl() != expected_url:
                raise SECError("SEC_REDIRECT_BLOCKED")
            if "json" not in response.headers.get("Content-Type", "").lower():
                raise SECError("SEC_CONTENT_TYPE_INVALID")
            raw = response.read(MAX_RESPONSE_BYTES + 1)
            completed = utc_now()
    except OSError as error:
        raise SECError("SEC_FETCH_FAILED") from error
    if len(raw) > MAX_RESPONSE_BYTES:
        raise SECError("SEC_RESPONSE_TOO_LARGE")
    try:
        body = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as error:
        raise SECError("SEC_JSON_INVALID") from error
    if not isinstance(body, dict) or normalize_cik(body.get("cik")) != cik:
        raise SECError("SEC_CIK_IDENTITY_MISMATCH")
    if kind == "submissions" and not isinstance(body.get("filings", {}).get("recent"), dict):
        raise SECError("SEC_SUBMISSIONS_SHAPE_INVALID")
    if kind == "companyfacts" and not isinstance(body.get("facts", {}).get("us-gaap"), dict):
        raise SECError("SEC_COMPANYFACTS_SHAPE_INVALID")
    receipt = {
        "ticker": ticker,
        "issuer_cik": cik,
        "document_kind": kind,
        "source_url": expected_url,
        "http_status": 200,
        "request_started_at_utc": started,
        "retrieved_at_utc": completed,
        "body_bytes": len(raw),
        "raw_sha256": sha256(raw).hexdigest(),
        "canonical_json_sha256": checksum(body),
        "first_public_at": None,
        "historical_asof_certified": False,
        "capture_scope": "MANUAL_REAL_SEC_JSON",
    }
    return receipt, raw


def capture_all(
    destination: Path,
    user_agent: str,
    *,
    opener=urlopen,
    sleeper=time.sleep,
) -> dict:
    if not valid_contact(user_agent):
        raise SECError("IDENTIFYING_USER_AGENT_REQUIRED")
    if destination.exists():
        raise SECError("DESTINATION_ALREADY_EXISTS")
    # A new private directory is mandatory; never overwrite previous evidence.
    destination.mkdir(mode=0o700, parents=False, exist_ok=False)
    os.chmod(destination, 0o700)
    receipts = []
    for index, (ticker, cik) in enumerate(ISSUERS):
        for kind in KINDS:
            if index or kind != KINDS[0]:
                sleeper(0.25)  # 4 req/s process-local maximum; not a global rate limit.
            receipt, raw = fetch_document(ticker, cik, kind, user_agent, opener=opener)
            stem = f"{ticker}_CIK{cik}_{kind}"
            write_new_private(destination / (stem + ".json"), raw)
            write_new_private(
                destination / (stem + ".receipt.json"),
                json.dumps(receipt, indent=2, sort_keys=True).encode("utf-8") + b"\n",
            )
            receipts.append(receipt)
    manifest = {
        "status": "CAPTURE_COMPLETE_8_OF_8",
        "captured_documents": len(receipts),
        "companies": [ticker for ticker, _ in ISSUERS],
        "receipts": receipts,
        "earliest_retrieved_at_utc": receipts[0]["retrieved_at_utc"],
        "latest_retrieved_at_utc": receipts[-1]["retrieved_at_utc"],
        "first_public_at": None,
        "historical_asof_certified": False,
        "scope": "RAW_SEC_SNAPSHOT_ONLY_NOT_PARSER_E2E",
        "no_database_or_portfolio_writes": True,
    }
    write_new_private(
        destination / "manifest.json",
        json.dumps(manifest, indent=2, sort_keys=True).encode("utf-8") + b"\n",
    )
    return manifest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Manually capture 8 real SEC EDGAR JSON snapshots with immutable local receipts"
    )
    parser.add_argument("--fetch", action="store_true", help="mandatory explicit live opt-in")
    parser.add_argument("--out-dir", required=True, help="new local private output directory")
    args = parser.parse_args(argv)
    if not args.fetch:
        parser.error("No network by default: --fetch required")
    user_agent = os.environ.get("FWIOS_SEC_USER_AGENT", "")
    try:
        result = capture_all(Path(args.out_dir), user_agent)
    except (SECError, OSError, ValueError) as error:
        print(f"SEC capture INCOMPLETE: {error}", file=sys.stderr)
        return 2
    print(
        json.dumps(
            {"status": result["status"], "documents": result["captured_documents"],
             "manifest": str(Path(args.out_dir) / "manifest.json")}
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
