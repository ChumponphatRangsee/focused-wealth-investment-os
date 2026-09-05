import copy
import unittest
from datetime import datetime, timezone
from scripts.check_closeout import check

NOW = datetime(2026, 1, 1, 0, 4, tzinfo=timezone.utc)


def fixture():
    stages, rows = [], []
    for i, code in enumerate(("FAST_DISCOVERY", "LIGHT_RESEARCH", "DEEP_RESEARCH")):
        stages.append(dict(stage_code=code, run_id="synthetic", status="PASS",
                           candidates_in=1, candidates_out=1, duration_seconds=60,
                           started_at=f"2026-01-01T00:0{i}:00Z",
                           completed_at=f"2026-01-01T00:0{i+1}:00Z"))
        rows.append(dict(stage_code=code, run_id="synthetic", ticker="TEST", selected=True))
    return dict(observed_at="2026-01-01T00:04:00Z",
        contracts=dict(github="v1", sheet="v1", supabase="v1"),
        run=dict(run_id="synthetic", status="COMPLETE", sector="Synthetic", shortlist=["TEST"],
                 universe_count=1, deep_researched_count=1, blocker_ids=["model"], immediate_buy_count=0),
        stages=stages, stage_candidates=rows,
        evidence=[dict(evidence_id="fact", run_id="synthetic", ticker="TEST", source_tier="A",
                       verification_status="VERIFIED", machine_status="PASS", source_url="https://example.com/fact")],
        blockers=[dict(block_id="model")], sheet_blocker_ids=["model"],
        candidates=[dict(ticker="TEST", promotion_gate="BLOCKED")],
        sheet=dict(last_completed_sector="Synthetic", stage="DONE", sector_status="COMPLETE",
                   run_lock="IDLE", current_run_id=""), sheet_history_ids=["synthetic"],
        sheet_universe_tickers=["TEST"], controller=dict(operating_mode="MODEL_FACTORY_AFTER_CURRENT_SECTOR"),
        next_action="MODEL_SPRINT", global_active=[])


class CloseoutTests(unittest.TestCase):
    def test_valid_no_action_run_can_close_despite_model_debt(self):
        self.assertEqual(check(fixture(), NOW)["status"], "PASS")

    def test_original_stuck_lock_is_blocked(self):
        s = fixture()
        s["sheet"].update(run_lock="RUNNING", current_run_id="synthetic", stage="FAST_DISCOVERY")
        self.assertIn("SHEET_LOCK_NOT_RELEASED", check(s, NOW)["errors"])

    def test_failure_cases(self):
        cases = [
            (lambda s: s["contracts"].update(sheet="old"), "CONTRACT_DRIFT"),
            (lambda s: s.update(observed_at="2025-12-31T00:00:00Z"), "SNAPSHOT_NOT_RECENT"),
            (lambda s: s["sheet_history_ids"].append("synthetic"), "HISTORY_MISSING_OR_DUPLICATED"),
            (lambda s: s.update(sheet_blocker_ids=[]), "SHEET_BLOCKER_MISSING"),
            (lambda s: s.update(next_action="DISCOVERY"), "NEXT_ACTION_BYPASSES_CONTROLLER"),
            (lambda s: s["stage_candidates"][1].update(ticker="OTHER"), "FUNNEL_LINEAGE_BROKEN"),
            (lambda s: s["stages"][0].update(duration_seconds=10), "TELEMETRY_INVALID"),
            (lambda s: s["evidence"][0].update(machine_status="BLOCKED"), "DEEP_EVIDENCE_NOT_VERIFIED"),
            (lambda s: s.update(evidence=[]), "DEEP_EVIDENCE_MISSING"),
            (lambda s: s.update(candidates=[]), "CANDIDATE_RECORDS_INVALID"),
            (lambda s: s["candidates"][0].update(promotion_gate="PASS"), "UNEXPECTED_PROMOTION_REQUIRES_REVIEW"),
            (lambda s: s["run"].update(immediate_buy_count=None), "IMMEDIATE_COUNT_UNVERIFIED"),
            (lambda s: s.update(global_active=["A", "B", "C", "D", "E", "F"]), "GLOBAL_CANDIDATE_CAP"),
            (lambda s: s["stages"].append(copy.deepcopy(s["stages"][0])), "STAGE_SET_INVALID"),
        ]
        for mutate, expected in cases:
            with self.subTest(expected=expected):
                s = fixture()
                mutate(s)
                self.assertIn(expected, check(s, NOW)["errors"])


if __name__ == "__main__":
    unittest.main()
