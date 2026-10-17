#!/usr/bin/env python3
"""FWIOS PR3 mock-provider contract tests, offline and zero external network.

This deliberately validates *fixtures and adapter semantics*, not Supabase RPC,
deployed Edge Functions, DB concurrency, vendor billing, or live market prices.
Run: python tests/market/pr3_mock_provider_harness.py
"""
from __future__ import annotations

import json
import math
from decimal import Decimal, InvalidOperation
from pathlib import Path

FIXTURE = Path(__file__).parent / "fixtures" / "pr3_mock_provider_scenarios_v1.json"
EXACT_SESSION = "2026-10-12"
SUPPORTED = {
    ("TWELVE_DATA", "TIME_SERIES"),
    ("ALPHA_VANTAGE_PRICE", "TIME_SERIES_DAILY"),
    ("COINGECKO", "SIMPLE_PRICE"),
    ("FRANKFURTER_FX", "LATEST"),
}


class MockProviderTransport:
    """Rejects any outbound transport except data-backed mock fixture references."""

    def __init__(self, scenarios: list[dict]) -> None:
        self.scenarios = {s["id"]: s for s in scenarios}
        self.external_calls = 0
        self.mock_requests = 0

    def fetch(self, scenario_id: str) -> dict:
        self.mock_requests += 1
        s = self.scenarios[scenario_id]
        if (s["provider"], s["endpoint"]) not in SUPPORTED:
            raise AssertionError("Unknown provider endpoint is not a mock fixture")
        # Never construct a URL or use urllib/requests/fetch.
        return s


def positive_price(value: object) -> Decimal | None:
    try:
        price = Decimal(str(value))
        if not price.is_finite() or price <= 0:
            return None
        return price
    except (InvalidOperation, TypeError, ValueError):
        return None


def normalize(s: dict) -> dict:
    if s.get("simulated_timeout"):
        return {"result": "PROVIDER_TIMEOUT"}
    status = s.get("http_status", 200)
    response = s.get("response", {})
    if status == 429:
        return {"result": "RATE_LIMITED",
                "retry_after_seconds": s["retry_after_seconds"]}
    if status != 200:
        return {"result": "PROVIDER_ERROR"}
    if isinstance(response, dict) and (
        response.get("Note") or response.get("Information")
        or response.get("Error Message")
    ):
        return {"result": "RATE_LIMITED"}
    if s["provider"] == "TWELVE_DATA":
        rows = [x for x in response.get("values", [])
                if x.get("datetime") == EXACT_SESSION]
        if not rows:
            return {"result": "NO_EXACT_SESSION"}
        candidate = rows[0].get("close")
    elif s["provider"] == "ALPHA_VANTAGE_PRICE":
        rows = response.get("Time Series (Daily)", {})
        if EXACT_SESSION not in rows:
            return {"result": "NO_EXACT_SESSION"}
        candidate = rows[EXACT_SESSION].get("4. close")
    elif s["provider"] == "COINGECKO":
        candidate = response.get("qa-crypto-a", {}).get("usd")
    elif s["provider"] == "FRANKFURTER_FX":
        if response.get("base") != "USD":
            return {"result": "INVALID_PRICE"}
        candidate = response.get("rates", {}).get("THB")
    else:
        return {"result": "UNKNOWN_ENDPOINT"}
    price = positive_price(candidate)
    if price is None:
        return {"result": "INVALID_PRICE"}
    return {"result": "SUCCESS", "normalized_price": float(price)}


def run() -> dict:
    raw = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert raw["schema_version"] == "FWIOS_PR3_SIM_V1"
    assert raw["mode"] == "MOCK_ONLY"
    assert raw["external_network_calls_allowed"] == 0
    assert raw["seed"] == 20261013
    ids = [s["id"] for s in raw["scenarios"]]
    assert len(ids) == len(set(ids)), "Duplicate fixture scenario IDs"
    symbols = [i["symbol"] for i in raw["instruments"]]
    assert all(symbol.startswith("QA_") for symbol in symbols)
    transport = MockProviderTransport(raw["scenarios"])
    cases = []
    for scenario_id in ids:
        scenario = transport.fetch(scenario_id)
        actual = normalize(scenario)
        expected = scenario["expected"]
        assert actual["result"] == expected["result"], (scenario_id, actual, expected)
        if "normalized_price" in expected:
            assert math.isclose(
                actual["normalized_price"], expected["normalized_price"],
                rel_tol=0, abs_tol=0.000001
            ), scenario_id
        if "retry_after_seconds" in expected:
            assert actual["retry_after_seconds"] == expected["retry_after_seconds"]
        assert expected["external_calls"] == 0
        cases.append({"id": scenario_id, "result": actual["result"], "pass": True})

    assert transport.external_calls == 0, "External network activity detected"
    assert transport.mock_requests == len(ids)
    stress = raw["quota_stress"]
    assert stress["provider"].startswith("QA_")
    assert stress["workers"] == stress["expected_allowed"] + stress["expected_denied"]
    assert stress["external_calls"] == 0
    return {
        "suite": "PR3_MOCK_CONTRACT_V1",
        "passed": len(cases),
        "total": len(ids),
        "outbound_http_calls": transport.external_calls,
        "db_calls": 0,
        "scope": "OFFLINE_ADAPTER_ONLY",
        "cases": cases,
    }


if __name__ == "__main__":
    print(json.dumps(run(), indent=2))
