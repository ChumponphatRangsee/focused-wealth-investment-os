#!/usr/bin/env python3
"""Guarded PR4 20-INDEPENDENT-POSTGRES-SESSION QA stress test.

NO provider HTTP, NO broker/holdings/transaction writes, NO Supabase CLI.
Connect ONLY to owner-approved Production-as-test with a short-lived
restricted database credential supplied in FWIOS_QA_DATABASE_URL.
Do not run on regular CI; manual ephemeral cloud runner recommended.

Required explicit gates:
 FWIOS_PR4_PRODUCTION_AS_TEST=YES
 FWIOS_EXPECTED_SUPABASE_REF=ysjbmeukwbfnxnwqchuq
 FWIOS_QA_DATABASE_URL=<connection secret supplied only to runner>

psql needs to be available. No network API endpoints are called other than DB.
Creates 1 disposable QA instrument/provider, 1 work item, 1 QA PR3 usage row.
20 parallel psql processes each use an independent PostgreSQL connection.
Cleanup is finally-guarded, and every created row is QA-identity scoped.
"""
from __future__ import annotations

import concurrent.futures as futures
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import uuid
from urllib.parse import urlparse

PROJECT_REF = "ysjbmeukwbfnxnwqchuq"
N = 20


def ql(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def db_call(query: str) -> str:
    # Credentials are environment-bound; they must never be printed/logged.
    # -X prevents invoking a user .psqlrc or side-effectful session startup.
    proc = subprocess.run(
        ["psql", "-X", "-A", "-t", "-q", "-v", "ON_ERROR_STOP=1", "-c", query],
        env=os.environ.copy(), text=True, capture_output=True, timeout=90
    )
    if proc.returncode != 0:
        raise RuntimeError("QA DB query failed; check protected runner logs.")
    return proc.stdout.strip()


def jcall(query: str) -> dict:
    return json.loads(db_call(query).splitlines()[-1])


def count(query: str) -> int:
    return int(db_call(query).splitlines()[-1])


def main() -> None:
    if os.environ.get("FWIOS_PR4_PRODUCTION_AS_TEST") != "YES":
        raise SystemExit("Refusing without explicit Production-as-test QA authorization gate.")
    if os.environ.get("FWIOS_EXPECTED_SUPABASE_REF") != PROJECT_REF:
        raise SystemExit("Unexpected project ref; refusing.")
    if not shutil.which("psql"):
        raise SystemExit("psql missing on ephemeral runner. Do not use Supabase CLI.")
    url = os.environ.get("FWIOS_QA_DATABASE_URL", "")
    uri = urlparse(url)
    if uri.scheme not in ("postgresql", "postgres") or not url:
        raise SystemExit("Missing or invalid QA database connection URL.")
    # Direct db hostname or session pooler username contains project ref.
    if PROJECT_REF not in (uri.hostname or "") and PROJECT_REF not in (uri.username or ""):
        raise SystemExit("Connection project ref cannot be verified. Refusing.")
    # Pass URI via env so DB password does not appear in subprocess command argv.
    os.environ["PGOPTIONS"] = "-c statement_timeout=60000"
    os.environ["PGHOST"] = uri.hostname or ""
    os.environ["PGPORT"] = str(uri.port or 5432)
    os.environ["PGUSER"] = uri.username or ""
    os.environ["PGPASSWORD"] = uri.password or ""
    os.environ["PGDATABASE"] = uri.path.lstrip("/") or "postgres"
    os.environ["PGSSLMODE"] = "require"
    os.environ.pop("FWIOS_QA_DATABASE_URL", None)

    run_id = uuid.uuid4().hex[:12].upper()
    provider = f"QA_PR4_STRESS_{run_id}"
    flight_key = hashlib.sha256((provider + "-flight").encode()).hexdigest()
    signature = hashlib.sha256((provider + "-signature").encode()).hexdigest()
    instrument: str | None = None
    fixture_created = False
    config = json.dumps({"unified_quota_v1": {
        "plan_id": "QA_SIMULATION_ONLY", "provider_group": provider,
        "budget_source": "fwios.decision_refresh_provider_registry.config",
        "migration_state": "QA_ONLY", "entitlement_status": "VERIFIED",
        "endpoint_cost_status": "VERIFIED", "vendor_reset_status": "VERIFIED",
        "hourly_limit_status": "VERIFIED", "concurrency_limit_status": "VERIFIED",
        "protected_daily_credits": 0, "lease_seconds": 120,
        "vendor_reset_rule": {"type": "CALENDAR_DAY", "timezone": "UTC"},
        "limits": {"minute": 1, "hour": 1, "day": 1, "concurrent": 1},
        "routes": {"SIMPLE_PRICE": {
            "capabilities": ["MARKET_PRICE"], "credit_cost": 1
        }}
    }}, separators=(",", ":"))

    def cleanup() -> None:
        if not fixture_created:
            return
        if instrument is None:
            raise RuntimeError("QA fixture instrument was not captured; manual inspection required")
        # Only run-specific random QA identity; no wildcards or broad cleanup.
        db_call(f"""
          begin;
          delete from fwios.market_refresh_flights_v1
           where flight_key={ql(flight_key)} and provider_key={ql(provider)}
             and qa_only=true and instrument_id={ql(instrument)}::uuid;
          delete from fwios.decision_refresh_api_usage
           where provider_group={ql(provider)}
             and quota_request_key like {ql('QA_PR4_STRESS_' + run_id + '_%')};
          delete from fwios.decision_refresh_provider_registry
           where provider_key={ql(provider)}
             and config->'unified_quota_v1'->>'plan_id'='QA_SIMULATION_ONLY';
          delete from fwios.instruments
           where instrument_id={ql(instrument)}::uuid
             and metadata->>'qa_identity'={ql(provider)};
          commit;
        """)
        residual = count(f"""
          select
            (select count(*) from fwios.market_refresh_flights_v1
                where provider_key={ql(provider)})
          + (select count(*) from fwios.decision_refresh_api_usage
                where provider_group={ql(provider)})
          + (select count(*) from fwios.decision_refresh_provider_registry
                where provider_key={ql(provider)})
          + (select count(*) from fwios.instruments
                where metadata->>'qa_identity'={ql(provider)});
        """)
        if residual:
            raise RuntimeError("QA cleanup FAILED; isolated residual rows need manual review")
        print("PASS QA cleanup: 0 QA flights, usage rows, providers and instruments")

    if count(f"select count(*) from fwios.decision_refresh_provider_registry where provider_key={ql(provider)}") != 0:
        raise SystemExit("Unexpected random QA provider collision; refusing")

    try:
        # One session creates two QA-only rows. No holdings or prices inserted.
        instrument = db_call(f"""
          insert into fwios.instruments(asset_class,instrument_type,primary_venue,
          trading_currency,metadata) values
          ('QA_CRYPTO','QA_SPOT','QA_ONLY','THB',
           jsonb_build_object('qa_identity',{ql(provider)},'ephemeral',true))
          returning instrument_id;
        """).splitlines()[-1]
        fixture_created = True
        db_call(f"""
          insert into fwios.decision_refresh_provider_registry
          (provider_key,provider_type,provider_name,source_tier,active,readiness_status,config)
          values ({ql(provider)},'QA_ONLY','QA PR4 independent sessions','B',
            true,'READY',{ql(config)}::jsonb);
        """)
        def enqueue(_: int) -> dict:
            return jcall(f"""
              select fwios.pr4_request_market_refresh_v1(
               {ql(flight_key)},{ql(signature)},{ql(instrument)}::uuid,{ql(provider)},
               'MARKET_PRICE','SIMPLE_PRICE','LIVE_QUOTE','THB',current_date,
               'P0',45,null,null,true);
            """)
        with futures.ThreadPoolExecutor(max_workers=N) as pool:
            joined = list(pool.map(enqueue,range(N)))
        assert sum(r.get("status")=="QUEUED" for r in joined)==1,joined
        assert sum(r.get("status")=="JOIN" for r in joined)==N-1,joined
        assert count(f"select count(*) from fwios.market_refresh_flights_v1 where provider_key={ql(provider)}")==1
        assert count(f"select count(*) from fwios.v_api_usage_unified_v1 where provider_key={ql(provider)}")==0
        print("PASS: 20 independent sessions -> 1 QUEUED + 19 JOIN, 0 quota reservations")

        def reserve(i: int) -> dict:
            key = f"QA_PR4_STRESS_{run_id}_{i:03d}"
            return jcall(f"""
              select fwios.reserve_api_quota_unified_v1(
                {ql(provider)},'MARKET_PRICE','SIMPLE_PRICE','pr4-qa-stress',
                {ql(key)},{ql(signature)},'P0');
            """)
        with futures.ThreadPoolExecutor(max_workers=N) as pool:
            reservations = list(pool.map(reserve,range(N)))
        winners = [r for r in reservations if r.get("allowed") is True]
        assert len(winners)==1, "Expected exactly one granted PR3 reservation"
        assert count(f"select count(*) from fwios.v_api_usage_unified_v1 where provider_key={ql(provider)}")==1
        uid = str(winners[0]["usage_id"])

        def dispatch(_: int) -> dict:
            return jcall(f"select fwios.mark_api_quota_dispatched_v1({ql(uid)}::uuid,30);")
        with futures.ThreadPoolExecutor(max_workers=N) as pool:
            dispatches = list(pool.map(dispatch,range(N)))
        assert sum(d.get("allowed") is True for d in dispatches)==1
        assert sum(d.get("allowed") is False for d in dispatches)==N-1
        print("PASS: 20 independent sessions -> 1 PR3 reservation, 1 dispatch permit, 0 provider HTTP")

        c=jcall("select fwios.pr4_claim_market_refresh_v1(gen_random_uuid(),true);")
        assert c.get("status")=="CLAIMED" and c.get("flight_key")==flight_key,c
        assert jcall("select fwios.pr4_claim_market_refresh_v1(gen_random_uuid(),true);").get("status")=="EMPTY"
        print("PASS: one QA-only flight claim and no duplicate dispatch")
    finally:
        cleanup()


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        # Never emit URL/password or PostgreSQL stderr containing connection details.
        print("FAIL PR4 QA independent-session stress:",type(exc).__name__,file=sys.stderr)
        sys.exit(1)
