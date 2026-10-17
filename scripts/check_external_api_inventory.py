#!/usr/bin/env python3
"""Static completeness guard for declared FWIOS external-API callers.

This is an inventory check, NOT runtime quota, auth, RLS, or provider-cost validation.
Existing legacy paths are recorded as debt so adding more untracked callers fails CI.
No API keys, Supabase credentials, network calls or database access are required.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INVENTORY = ROOT / "config" / "external_api_inventory.json"
FUNCTIONS = ROOT / "supabase" / "functions"
QUOTA_MODES = {
    "NOT_APPLICABLE",
    "PARTIAL_LEGACY",
    "LEGACY_DAILY_CLOSE_POLICY",
    "PARTIAL_UNMETERED_PROVIDER",
    "VERIFIED_UNIFIED_QUOTA",
}


def validate(root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    manifest_path = root / "config" / "external_api_inventory.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [f"Cannot load inventory: {exc}"]

    if manifest.get("schema_version") != 1:
        errors.append("Unsupported schema_version; expected 1")
    if manifest.get("contract_status") != "BASELINE_NOT_CUT_OVER":
        errors.append("Inventory must not imply production cutover")

    records = manifest.get("function_paths")
    if not isinstance(records, list):
        return errors + ["function_paths must be a list"]

    tracked: set[str] = set()
    for item in records:
        if not isinstance(item, dict):
            errors.append("Inventory function entry must be an object")
            continue
        name = item.get("slug", "")
        if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
            errors.append(f"Invalid function slug: {name!r}")
            continue
        if name in tracked:
            errors.append(f"Duplicate function: {name}")
        tracked.add(name)
        if not isinstance(item.get("external_http"), bool):
            errors.append(f"{name}: external_http must be boolean")
        if item.get("quota_mode") not in QUOTA_MODES:
            errors.append(f"{name}: unrecognized quota mode")
        providers = item.get("providers")
        if not isinstance(providers, list) or not all(isinstance(p, str) and p for p in providers):
            errors.append(f"{name}: providers must be a list of provider identifiers")
        if item.get("external_http") and not providers:
            errors.append(f"{name}: network caller requires a provider inventory")
        if item.get("external_http") and not item.get("finding") and item.get("quota_mode") != "VERIFIED_UNIFIED_QUOTA":
            errors.append(f"{name}: legacy caller missing tracked finding ID")
        if not item.get("auth_observation") or not item.get("consumer"):
            errors.append(f"{name}: missing auth or consumer boundary")
        code_path = root / "supabase" / "functions" / name / "index.ts"
        if code_path.exists():
            code = code_path.read_text(encoding="utf-8")
            direct_fetch = bool(re.search(r"\bfetch\s*\(", code))
            if direct_fetch and not item.get("external_http"):
                errors.append(f"{name}: code contains fetch() but inventory says external_http=false")
            for literal, canonical in (
                ("api.coingecko.com", "COINGECKO"),
                ("twelvedata.com", "TWELVE_DATA"),
                ("alphavantage.co", "ALPHA_VANTAGE"),
            ):
                if literal in code.lower() and canonical not in (providers or []):
                    errors.append(f"{name}: provider {canonical} mentioned in code but absent from inventory")
        if item.get("quota_mode") == "VERIFIED_UNIFIED_QUOTA" and not item.get("verification_ref"):
            errors.append(f"{name}: claiming unified quota requires verification_ref")

    actual = {
        path.parent.name
        for path in (root / "supabase" / "functions").glob("*/index.ts")
    }
    missing = sorted(actual - tracked)
    extra = sorted(tracked - actual)
    if missing:
        errors.append(f"Untracked Edge Functions: {', '.join(missing)}")
    if extra:
        errors.append(f"Missing source directories for tracked functions: {', '.join(extra)}")

    # Inventory data must not carry callable secret-bearing URLs or credentials.
    contents = manifest_path.read_text(encoding="utf-8")
    if re.search(r"(?i)[?&](?:token|api_key|apikey|key)=", contents):
        errors.append("Do not store credential-bearing URLs in inventory")
    if re.search(r"(?i)(?:service_role|supabase_secret_key)\s*[:=]\s*['\"][A-Za-z0-9._-]{15,}", contents):
        errors.append("Possible credential literal in inventory")

    return errors


if __name__ == "__main__":
    failures = validate()
    if failures:
        print("FWIOS external API inventory: FAIL")
        for failure in failures:
            print(f" - {failure}")
        sys.exit(1)
    print("FWIOS external API inventory: PASS (static coverage only; quota runtime not verified)")
