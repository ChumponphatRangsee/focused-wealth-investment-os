#!/usr/bin/env python3
"""Read-only reconciliation of a freshly collected, private run snapshot.

This validates recorded workflow state, not investment facts or eligibility.
It never connects to a broker, changes a database, or releases a run lock.
"""
import argparse
import json
import math
from datetime import datetime, timezone
from pathlib import Path


STAGES = (("FAST_DISCOVERY", 20, 8), ("LIGHT_RESEARCH", 8, 5),
          ("DEEP_RESEARCH", 5, 5))


def timestamp(value):
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        raise ValueError("Timezone required")
    return dt


def check(snapshot, now=None):
    """Return diagnostics only; missing evidence cannot pass by default."""
    errors = []
    def require(condition, code):
        if not condition:
            errors.append(code)

    now = now or datetime.now(timezone.utc)
    age = (now - timestamp(snapshot["observed_at"])).total_seconds()
    require(0 <= age <= 900, "SNAPSHOT_NOT_RECENT")
    require(len(set(snapshot["contracts"].values())) == 1 and
            set(snapshot["contracts"]) == {"github", "sheet", "supabase"},
            "CONTRACT_DRIFT")
    run = snapshot["run"]
    run_id = run["run_id"]
    require(run["status"] == "COMPLETE", "DATABASE_RUN_INCOMPLETE")
    stages = snapshot["stages"]
    require(len(stages) == 3 and {s["stage_code"] for s in stages} ==
            {s[0] for s in STAGES}, "STAGE_SET_INVALID")
    elapsed = 0
    previous_end = None
    previous_selected = None
    universe = set()
    deep = set()
    for code, max_in, max_out in STAGES:
        matches = [s for s in stages if s["stage_code"] == code]
        if len(matches) != 1:
            continue
        stage = matches[0]
        rows = [c for c in snapshot["stage_candidates"] if c["stage_code"] == code]
        tickers = {c["ticker"] for c in rows}
        selected = {c["ticker"] for c in rows if c["selected"] is True}
        require(all(c["selected"] in (True, False) and type(c["selected"]) is bool
                    for c in rows), "SELECTION_NOT_BOOLEAN")
        require(stage["run_id"] == run_id and all(c["run_id"] == run_id for c in rows),
                "CROSS_RUN_DATA")
        require(stage["status"] == "PASS", "STAGE_NOT_PASS")
        require(len(tickers) == len(rows) == stage["candidates_in"] <= max_in,
                "STAGE_INPUT_COUNT_INVALID")
        require(len(selected) == stage["candidates_out"] <= max_out, "STAGE_OUTPUT_COUNT_INVALID")
        if previous_selected is not None:
            require(tickers == previous_selected, "FUNNEL_LINEAGE_BROKEN")
        start, end = timestamp(stage["started_at"]), timestamp(stage["completed_at"])
        seconds = (end - start).total_seconds()
        recorded = stage["duration_seconds"]
        require(math.isfinite(recorded) and seconds >= 0 and abs(recorded - seconds) < 0.001,
                "TELEMETRY_INVALID")
        require(end <= now, "FUTURE_COMPLETION")
        if previous_end is not None:
            require(start >= previous_end, "STAGE_ORDER_INVALID")
        elapsed += seconds
        previous_end, previous_selected = end, selected
        if code == "FAST_DISCOVERY":
            universe = tickers
        if code == "LIGHT_RESEARCH":
            require(set(run["shortlist"]) == selected and len(run["shortlist"]) == len(selected),
                    "SHORTLIST_DRIFT")
        if code == "DEEP_RESEARCH":
            deep = selected
            if len(deep) > 3:
                require(bool(stage.get("raw_payload", {}).get("expansion_reason")),
                        "DEEP_EXPANSION_UNJUSTIFIED")
    require(len(universe) == run["universe_count"], "UNIVERSE_COUNT_DRIFT")
    require(len(deep) == run["deep_researched_count"], "DEEP_COUNT_DRIFT")
    evidence = snapshot["evidence"]
    ids = [e["evidence_id"] for e in evidence]
    require(len(ids) == len(set(ids)), "DUPLICATE_EVIDENCE")
    for ticker in deep:
        facts = [e for e in evidence if e["ticker"] == ticker and e["run_id"] == run_id]
        require(bool(facts), "DEEP_EVIDENCE_MISSING")
        require(all(e["source_tier"] == "A" and e["verification_status"] == "VERIFIED"
                    and e["machine_status"] == "PASS" and
                    e["source_url"].startswith("https://") for e in facts),
                "DEEP_EVIDENCE_NOT_VERIFIED")
    blockers = {b["block_id"] for b in snapshot["blockers"]}
    require(set(run["blocker_ids"]).issubset(blockers), "BLOCKER_NOT_PERSISTED")
    require(set(run["blocker_ids"]).issubset(set(snapshot["sheet_blocker_ids"])),
            "SHEET_BLOCKER_MISSING")
    candidate_tickers = [c["ticker"] for c in snapshot["candidates"]]
    require(deep.issubset(set(candidate_tickers)) and
            len(candidate_tickers) == len(set(candidate_tickers)), "CANDIDATE_RECORDS_INVALID")
    for c in snapshot["candidates"]:
        if c["ticker"] in deep:
            require(c["promotion_gate"] == "BLOCKED", "UNEXPECTED_PROMOTION_REQUIRES_REVIEW")
    require(run["immediate_buy_count"] == 0, "IMMEDIATE_COUNT_UNVERIFIED")
    sheet = snapshot["sheet"]
    require(sheet["last_completed_sector"] == run["sector"] and sheet["stage"] == "DONE"
            and sheet["sector_status"] == "COMPLETE", "SHEET_RUN_NOT_CLOSED")
    require(sheet["run_lock"] == "IDLE" and not sheet["current_run_id"], "SHEET_LOCK_NOT_RELEASED")
    require(snapshot["sheet_history_ids"].count(run_id) == 1, "HISTORY_MISSING_OR_DUPLICATED")
    require(set(snapshot["sheet_universe_tickers"]) == universe and
            len(snapshot["sheet_universe_tickers"]) == len(universe), "SHEET_UNIVERSE_DRIFT")
    controller = snapshot["controller"]
    next_action = ("DISCOVERY" if controller["operating_mode"] == "DISCOVERY" else "MODEL_SPRINT")
    require(snapshot["next_action"] == next_action, "NEXT_ACTION_BYPASSES_CONTROLLER")
    require(len(snapshot["global_active"]) <= 5 and len(set(snapshot["global_active"])) ==
            len(snapshot["global_active"]), "GLOBAL_CANDIDATE_CAP")
    return {"status": "BLOCKED" if errors else "PASS", "errors": sorted(set(errors)),
            "duration_seconds": round(elapsed, 3), "next_action": next_action,
            "scope": "Recorded research-run closeout only; not whole-project completion or investment approval"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    args = parser.parse_args()
    try:
        result = check(json.loads(args.snapshot.read_text()))
    except (KeyError, TypeError, ValueError, AttributeError, OSError):
        result = {"status": "BLOCKED", "errors": ["SNAPSHOT_INVALID_OR_MISSING_FIELDS"]}
    print(json.dumps(result, indent=2))
    return int(result["status"] != "PASS")


if __name__ == "__main__":
    raise SystemExit(main())
