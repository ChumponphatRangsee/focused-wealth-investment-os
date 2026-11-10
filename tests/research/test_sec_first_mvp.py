"""Deterministic offline SEC XBRL evidence and negative-case guards.

No real SEC HTTP, paid provider, Supabase, Sheet or trading calls in this suite.
"""
import copy
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from research.sec_first_mvp.core import (
    SECError, build_evidence, checksum, fetch_company_documents, normalize_cik, sec_urls
)
from research.sec_first_mvp.cli import main as cli_main, save_new_file


CIK = 320193
ACC = "0000320193-25-000101"
AMENDED = "0000320193-25-000102"
UNKNOWN = "0000320193-25-000999"
NOW = "2025-11-10T20:00:00Z"
RETRIEVED = "2025-11-05T20:00:00Z"


def fixture():
    submissions = {
        "cik": CIK, "name": "Example SEC issuer (synthetic)",
        "filings": {"recent": {
            "accessionNumber": [ACC, AMENDED, UNKNOWN],
            "form": ["10-Q", "10-Q/A", "8-K"],
            "filingDate": ["2025-11-03", "2025-11-04", "2025-11-05"],
            "acceptanceDateTime": ["2025-11-03T15:30:00.000Z",
                                   "2025-11-04T15:30:00.000Z",
                                   "2025-11-05T15:30:00.000Z"]
        }}
    }
    def fact(acc, val, form="10-Q", filed="2025-11-03", **more):
        return {"accn": acc, "val": val, "form": form,
                "filed": filed, "end": "2025-09-27", "fy": 2025,
                "fp": "Q3", **more}
    facts = {
        "cik": CIK, "entityName": submissions["name"], "facts": {
            "us-gaap": {
                "Assets": {"units": {"USD": [
                    fact(ACC, 100),
                    fact(AMENDED, 101, form="10-Q/A", filed="2025-11-04"),
                    fact(UNKNOWN, 103, form="10-Q", filed="2025-11-05")
                ]}},
                "NetIncomeLoss": {"units": {"USD": [
                    fact(ACC, 10, start="2025-06-29"),
                    fact(AMENDED, 11, form="10-Q/A", filed="2025-11-04", start="2025-06-29")
                ]}},
                "Liabilities": {"units": {"EUR": [fact(ACC, 60)]}},
            }
        }
    }
    return submissions, facts


def result(s=None, f=None, **kwargs):
    if s is None or f is None:
        s, f = fixture()
    return build_evidence(CIK, s, f, retrieved_at=RETRIEVED, as_of=NOW, **kwargs)


class SECFirstEvidenceTests(unittest.TestCase):
    def test_cik_zero_padding_and_bad_cik(self):
        self.assertEqual(normalize_cik(320193), "0000320193")
        self.assertEqual(normalize_cik("0000320193"), "0000320193")
        for bad in (0, "0", "", "-1", "AAPL", "10000000000", True, None):
            with self.subTest(bad=bad), self.assertRaises(SECError):
                normalize_cik(bad)

    def test_sec_urls_are_fixed_no_ticker_guess(self):
        self.assertEqual(sec_urls(CIK), (
            "https://data.sec.gov/submissions/CIK0000320193.json",
            "https://data.sec.gov/api/xbrl/companyfacts/CIK0000320193.json"))

    def test_accepts_original_and_amendment_separately(self):
        v = result()
        self.assertEqual(v["status"], "PASS_CURRENT_RESEARCH_ONLY")
        self.assertEqual(v["coverage"]["accepted"], 4)
        self.assertEqual({x["accession"] for x in v["facts"]}, {ACC, AMENDED})
        a = [x for x in v["facts"] if x["tag"] == "Assets"]
        self.assertEqual({x["value"] for x in a}, {100, 101})
        self.assertTrue(all(x["first_public_at"] is None for x in a))
        self.assertTrue(all(not x["historical_backtest_certified"] for x in a))

    def test_unknown_accession_quarantined_not_promoted(self):
        v = result()
        self.assertTrue(any(x["reason"] == "ACCEPTANCE_NOT_VERIFIED_IN_RECENT"
                            for x in v["quarantined"]))
        self.assertEqual(v["coverage"]["submission_scope"], "recent_only")

    def test_historical_as_of_before_observation_blocks_all(self):
        s, f = fixture()
        v = build_evidence(CIK, s, f, retrieved_at=RETRIEVED,
                           as_of="2025-11-04T23:59:59Z")
        self.assertEqual(v["status"], "BLOCKED_NO_VERIFIED_FACTS")
        self.assertEqual(v["coverage"]["accepted"], 0)
        self.assertTrue(any(x["reason"] == "SOURCE_NOT_OBSERVED_AS_OF"
                            for x in v["quarantined"]))

    def test_filing_future_relative_to_as_of(self):
        s, f = fixture()
        v = build_evidence(CIK, s, f,
                           retrieved_at="2025-11-03T00:00:00Z",
                           as_of="2025-11-03T12:00:00Z")
        self.assertEqual(v["coverage"]["accepted"], 0)
        self.assertTrue(any(x["reason"] == "FILING_AFTER_AS_OF"
                            for x in v["quarantined"]))

    def test_nan_and_bool_are_quarantined(self):
        s, f = fixture()
        f["facts"]["us-gaap"]["Assets"]["units"]["USD"][0]["val"] = float("nan")
        f["facts"]["us-gaap"]["Assets"]["units"]["USD"][1]["val"] = True
        # Source hashing rejects non-JSON NaN documents: fail closed at document boundary.
        with self.assertRaises(ValueError):
            result(s, f)
        f["facts"]["us-gaap"]["Assets"]["units"]["USD"][0]["val"] = 0
        v = result(s, f)
        self.assertTrue(any(x["reason"] == "VALUE_INVALID" for x in v["quarantined"]))

    def test_duration_requires_start(self):
        s, f = fixture()
        del f["facts"]["us-gaap"]["NetIncomeLoss"]["units"]["USD"][0]["start"]
        v = result(s, f)
        self.assertIn("DURATION_START_MISSING", {x["reason"] for x in v["quarantined"]})

    def test_instant_rejects_start(self):
        s, f = fixture()
        f["facts"]["us-gaap"]["Assets"]["units"]["USD"][0]["start"] = "2025-06-29"
        v = result(s, f)
        self.assertIn("INSTANT_HAS_START", {x["reason"] for x in v["quarantined"]})

    def test_wrong_filing_date_quarantines(self):
        s, f = fixture()
        f["facts"]["us-gaap"]["Assets"]["units"]["USD"][0]["filed"] = "2025-11-02"
        v = result(s, f)
        self.assertIn("FILING_IDENTITY_OR_DATE_CONFLICT",
                      {x["reason"] for x in v["quarantined"]})

    def test_company_cik_mismatch_blocks(self):
        s, f = fixture()
        f["cik"] = 999
        with self.assertRaisesRegex(SECError, "CIK_IDENTITY_MISMATCH"):
            result(s, f)

    def test_submissions_columns_misaligned_blocks(self):
        s, f = fixture()
        s["filings"]["recent"]["form"].pop()
        with self.assertRaisesRegex(SECError, "COLUMNS_MISALIGNED"):
            result(s, f)

    def test_naive_acceptance_not_eligible(self):
        s, f = fixture()
        s["filings"]["recent"]["acceptanceDateTime"][0] = "2025-11-03T15:30:00"
        v = result(s, f)
        self.assertIn("INVALID_RECENT_TIME:" + ACC, v["coverage"]["review_warnings"])
        self.assertTrue(any(x["reason"] == "ACCEPTANCE_NOT_VERIFIED_IN_RECENT"
                            for x in v["quarantined"]))

    def test_retrieved_at_naive_rejected(self):
        s, f = fixture()
        with self.assertRaisesRegex(SECError, "RETRIEVED_AT_MISSING_TZ"):
            build_evidence(CIK, s, f,
                           retrieved_at="2025-11-05T20:00:00", as_of=NOW)

    def test_exact_duplicate_collapses(self):
        s, f = fixture()
        usd = f["facts"]["us-gaap"]["Assets"]["units"]["USD"]
        usd.append(copy.deepcopy(usd[0]))
        v = result(s, f)
        self.assertEqual(v["coverage"]["accepted"], 4)

    def test_conflicting_same_accession_is_quarantined(self):
        s, f = fixture()
        usd = f["facts"]["us-gaap"]["Assets"]["units"]["USD"]
        bad = copy.deepcopy(usd[0])
        bad["val"] = 888
        usd.append(bad)
        v = result(s, f)
        self.assertFalse(any(x["accession"] == ACC and x["tag"] == "Assets" for x in v["facts"]))
        self.assertEqual(sum(x["reason"] == "CONFLICTING_VALUES_SAME_ACCESSION"
                             for x in v["quarantined"]), 2)

    def test_limit_declares_partial_not_full_coverage(self):
        v = result(limit=2)
        self.assertEqual(v["coverage"]["rows_examined"], 2)
        self.assertTrue(v["coverage"]["truncated"])
        with self.assertRaisesRegex(SECError, "LIMIT_INVALID"):
            result(limit=501)

    def test_hashes_stable_ignore_json_key_order(self):
        s, f = fixture()
        self.assertEqual(checksum(f), checksum(dict(reversed(list(f.items())))))
        v = result(s, f)
        self.assertEqual(v["source_hashes"]["companyfacts_sha256"], checksum(f))

    def test_explicit_fetch_uses_two_sec_calls_without_background(self):
        s, f = fixture()
        with patch("research.sec_first_mvp.core._fetch_json", side_effect=[s, f]) as fetch:
            with patch("research.sec_first_mvp.core.time.sleep") as sleep:
                x, y, ts = fetch_company_documents(CIK, "Org person@example.com")
        self.assertEqual((x, y), (s, f))
        self.assertEqual(fetch.call_count, 2)
        self.assertTrue(all(c.args[0].startswith("https://data.sec.gov/") for c in fetch.call_args_list))
        sleep.assert_called_once_with(0.25)
        self.assertEqual(ts.tzinfo, timezone.utc)

    def test_immutable_output_cannot_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            path = str(Path(temp) / "evidence.json")
            save_new_file(path, {"first": 1})
            with self.assertRaises(FileExistsError):
                save_new_file(path, {"first": 2})
            self.assertIn('"first": 1', Path(path).read_text())

    def test_cli_defaults_to_offline_without_files(self):
        with self.assertRaises(SystemExit) as e:
            cli_main(["--cik", str(CIK)])
        self.assertEqual(e.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
