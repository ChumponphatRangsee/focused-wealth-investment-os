"""Run SEC-first evidence MVP with local JSON (default) or explicit SEC-only GETs.

Examples:
    python -m research.sec_first_mvp.cli --cik 320193 \
        --submissions-file /tmp/apple_submissions.json \
        --companyfacts-file /tmp/apple_facts.json

    python -m research.sec_first_mvp.cli --cik 320193 --fetch \
        --user-agent "Research Org researcher@example.com" \
        --out-file /tmp/sec-evidence-apple.json

No Supabase, Google Sheet, cron, trading or paid-provider integration.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys

from .core import SECError, build_evidence, fetch_company_documents, iso_utc

MAX_LOCAL_JSON = 25_000_000


def local_json(path: str) -> dict:
    item = Path(path)
    if not item.is_file() or item.stat().st_size > MAX_LOCAL_JSON:
        raise SECError("LOCAL_FILE_MISSING_OR_TOO_LARGE")
    with item.open("r", encoding="utf-8") as f:
        document = json.load(f)
    if not isinstance(document, dict):
        raise SECError("LOCAL_JSON_OBJECT_REQUIRED")
    return document


def save_new_file(path: str, payload: dict) -> None:
    """Explicit immutable audit export. Exclusive creation; never overwrite."""
    data = (json.dumps(payload, indent=2, ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
    except BaseException:
        # An interrupted export must never be misrepresented as verified evidence.
        try:
            os.unlink(path)
        except OSError:
            pass
        raise


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="SEC-first offline-first evidence MVP; no production integration")
    p.add_argument("--cik", required=True, help="SEC issuer CIK; never infer from an unverified ticker")
    p.add_argument("--submissions-file")
    p.add_argument("--companyfacts-file")
    p.add_argument("--retrieved-at", help="Explicit UTC/offset ISO timestamp for local documents")
    p.add_argument("--as-of", help="UTC/offset ISO decision time; defaults to current time")
    p.add_argument("--fetch", action="store_true", help="Explicitly allow exactly 2 SEC API GET requests")
    p.add_argument("--user-agent", help="Must contain real organization/name and email for SEC fair access")
    p.add_argument("--out-file", help="New immutable JSON file. Existing file is never overwritten")
    p.add_argument("--limit", type=int, default=500, help="Max rows examined, 1..500")
    opts = p.parse_args(argv)
    if opts.fetch:
        if opts.submissions_file or opts.companyfacts_file or opts.retrieved_at:
            p.error("--fetch cannot mix with local files or a fabricated retrieval time")
        if not opts.user_agent:
            p.error("--fetch requires an operator-supplied identifying --user-agent")
    elif not (opts.submissions_file and opts.companyfacts_file and opts.retrieved_at):
        p.error("offline mode requires --submissions-file, --companyfacts-file and --retrieved-at")
    try:
        if opts.fetch:
            submissions, facts, retrieved_at = fetch_company_documents(opts.cik, opts.user_agent)
        else:
            submissions = local_json(opts.submissions_file)
            facts = local_json(opts.companyfacts_file)
            retrieved_at = iso_utc(opts.retrieved_at, "RETRIEVED_AT")
        as_of = iso_utc(opts.as_of, "AS_OF") if opts.as_of else datetime.now(timezone.utc)
        output = build_evidence(opts.cik, submissions, facts,
                                retrieved_at=retrieved_at, as_of=as_of, limit=opts.limit)
        if opts.out_file:
            save_new_file(opts.out_file, output)
            print(json.dumps({"status": output["status"], "cik": output["cik"],
                              "accepted": output["coverage"]["accepted"],
                              "quarantined": output["coverage"]["quarantined"],
                              "out_file": opts.out_file}, sort_keys=True))
        else:
            print(json.dumps(output, indent=2, ensure_ascii=False, allow_nan=False))
        return 0 if output["coverage"]["accepted"] else 2
    except (SECError, OSError, json.JSONDecodeError) as err:
        print(f"SEC_FIRST_MVP_BLOCKED: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
