#!/usr/bin/env python3
"""Concurrent staging acceptance for FWIOS PR3; NEVER run against production.

Requires psql in PATH, STAGING database URL in FWIOS_STAGING_DATABASE_URL,
and PR2+PR3 migrations already applied. Creates disposable provider
PR3_STRESS_TEST and clears only its own rows in a finally block.

Run:
  FWIOS_STAGING_DATABASE_URL='postgresql://...STAGING...' \
    python tests/market/pr3_atomic_concurrency_staging.py
"""
from __future__ import annotations

import concurrent.futures
import json
import os
import shutil
import subprocess
import sys
import uuid

PROVIDER = "PR3_STRESS_TEST"
WORKERS = 20


def sql(query: str) -> str:
    url = os.environ["FWIOS_STAGING_DATABASE_URL"]
    proc = subprocess.run(
        ["psql", url, "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-c", query],
        text=True,
        capture_output=True,
        timeout=90,
        check=True,
    )
    return proc.stdout.strip()


def main() -> None:
    if os.environ.get("FWIOS_IS_STAGING") != "YES":
        raise SystemExit("Refusing: explicitly set FWIOS_IS_STAGING=YES.")
    if not os.environ.get("FWIOS_STAGING_DATABASE_URL"):
        raise SystemExit("Missing FWIOS_STAGING_DATABASE_URL.")
    if not shutil.which("psql"):
        raise SystemExit("Missing psql binary.")

    run = str(uuid.uuid4()).replace("-", "")
    fixture = json.dumps(
        {
            "unified_quota_v1": {
                "plan_id": "STAGING_FAKE_PLAN",
                "provider_group": PROVIDER,
                "budget_source": "fwios.decision_refresh_provider_registry.config",
                "entitlement_status": "VERIFIED",
                "endpoint_cost_status": "VERIFIED",
                "vendor_reset_status": "VERIFIED",
                "hourly_limit_status": "VERIFIED",
                "concurrency_limit_status": "VERIFIED",
                "vendor_reset_rule": {"type": "CALENDAR_DAY", "timezone": "UTC"},
                "limits": {"minute": 1, "hour": 1, "day": 1, "concurrent": 1},
                "protected_daily_credits": 0,
                "lease_seconds": 120,
                "routes": {"QUOTE": {"capabilities": ["MARKET_PRICE"], "credit_cost": 1}},
            }
        }
    )
    # psql SQL literals are generated solely from constant keys and json.dumps output.
    safe_fixture = fixture.replace("'", "''")
    create = f"""
      insert into fwios.decision_refresh_provider_registry
        (provider_key,provider_type,provider_name,source_tier,
         requires_secret,active,readiness_status,config)
      values ('{PROVIDER}','STAGING_TEST','PR3 Staging Stress','TEST',
              false,true,'READY','{safe_fixture}'::jsonb);
    """
    occupied = int(sql(
        "select count(*) from fwios.decision_refresh_provider_registry "
        f"where provider_key='{PROVIDER}';"
    ))
    if occupied:
        raise SystemExit("Refusing: staging test provider already exists; no cleanup performed.")
    created = False
    try:
        sql(create)
        created = True
        def reserve(i: int) -> dict:
            key = f"{run}-{i:03d}"
            result = sql(
                "select fwios.reserve_api_quota_unified_v1("
                f"'{PROVIDER}','MARKET_PRICE','QUOTE','pr3-staging',"
                f"'{key}','sig-{key}','P0');"
            )
            return json.loads(result)

        with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
            replies = list(pool.map(reserve, range(WORKERS)))

        granted = [r for r in replies if r.get("allowed") is True]
        assert len(granted) == 1, f"Expected exactly 1 reservation, got {len(granted)}: {replies}"
        count = int(sql(
            "select count(*) from fwios.decision_refresh_api_usage "
            f"where provider_group='{PROVIDER}';"
        ))
        assert count == 1, f"Expected one committed usage row; got {count}"
        print(f"PASS: {WORKERS} simultaneous workers -> 1 allowed, 1 usage row.")
    finally:
        # Disposable fixture ONLY. The run must target STAGING.
        if created:
            sql(f"delete from fwios.decision_refresh_api_usage where provider_group='{PROVIDER}';")
            sql(f"delete from fwios.decision_refresh_provider_registry where provider_key='{PROVIDER}';")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL PR3 staging concurrency: {type(exc).__name__}. Check staging psql logs.", file=sys.stderr)
        sys.exit(1)
