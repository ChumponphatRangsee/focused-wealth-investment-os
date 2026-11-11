"""Offline tests for manual 4-CIK SEC capture. No real HTTP requests."""
from __future__ import annotations

from hashlib import sha256
import json
import os
from pathlib import Path
import tempfile
import unittest

from research.sec_first_mvp.batch_capture import (
    ISSUERS, KINDS, capture_all, fetch_document, valid_contact,
)
from research.sec_first_mvp.core import SECError


UA = "FWIOS SEC Research research-contact@valid-organization.org"


class FakeSECResponse:
    def __init__(self, url, body, *, status=200, content_type="application/json", redirect=None):
        self.status = status
        self.headers = {"Content-Type": content_type}
        self.url = redirect or url
        self.body = body

    def geturl(self):
        return self.url

    def read(self, n):
        return self.body[:n]

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False


class MockSECOpener:
    def __init__(self, *, wrong_cik=False, fail_at=0, redirect=False, bad_json=False):
        self.urls = []
        self.wrong_cik = wrong_cik
        self.fail_at = fail_at
        self.redirect = redirect
        self.bad_json = bad_json
        self.user_agents = []

    def __call__(self, req, timeout=12):
        self.urls.append(req.full_url)
        self.user_agents.append(req.get_header("User-agent"))
        if self.fail_at and len(self.urls) == self.fail_at:
            raise OSError("simulated SEC network outage")
        cik = req.full_url.split("CIK")[-1].split(".json")[0]
        out_cik = int(cik) + 1 if self.wrong_cik else int(cik)
        if "/submissions/" in req.full_url:
            body = {"cik": out_cik, "name": "Synthetic fixture", "filings": {"recent": {}}}
        else:
            body = {"cik": out_cik, "entityName": "Synthetic fixture", "facts": {"us-gaap": {}}}
        raw = b"not-json" if self.bad_json else json.dumps(body).encode("utf-8")
        return FakeSECResponse(
            req.full_url, raw,
            redirect="https://invalid.example.net/redirect" if self.redirect else None,
        )


class SECManualCaptureTests(unittest.TestCase):
    def test_manual_contact_required(self):
        for ua in ("", "Mozilla/5.0", "Research example@example.org", "x@gmail.com"):
            self.assertFalse(valid_contact(ua))
        self.assertTrue(valid_contact(UA))

    def test_four_issuers_have_distinct_10_digit_ciks(self):
        self.assertEqual(len(ISSUERS), 4)
        self.assertEqual({x[0] for x in ISSUERS}, {"MSFT", "NVDA", "TTWO", "TLN"})
        self.assertEqual(len({x[1] for x in ISSUERS}), 4)
        self.assertTrue(all(len(cik) == 10 and cik.isdecimal() for _, cik in ISSUERS))

    def test_capture_eight_files_and_real_byte_sha(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td) / "sec-snapshot"
            opener = MockSECOpener()
            sleeps = []
            manifest = capture_all(dest, UA, opener=opener, sleeper=sleeps.append)
            self.assertEqual(manifest["status"], "CAPTURE_COMPLETE_8_OF_8")
            self.assertEqual(manifest["captured_documents"], 8)
            self.assertEqual(len(opener.urls), 8)
            self.assertEqual(len(sleeps), 7)
            self.assertEqual(sleeps, [0.25] * 7)
            self.assertEqual(len(list(dest.glob("*_submissions.json"))), 4)
            self.assertEqual(len(list(dest.glob("*_companyfacts.json"))), 4)
            self.assertEqual(len(list(dest.glob("*.receipt.json"))), 8)
            self.assertEqual(len(list(dest.glob("manifest.json"))), 1)
            self.assertEqual(len(list(dest.iterdir())), 17)
            self.assertEqual(set(manifest["companies"]), {"MSFT", "NVDA", "TTWO", "TLN"})
            self.assertIsNone(manifest["first_public_at"])
            self.assertFalse(manifest["historical_asof_certified"])
            for r in manifest["receipts"]:
                name = f'{r["ticker"]}_CIK{r["issuer_cik"]}_{r["document_kind"]}.json'
                data = (dest / name).read_bytes()
                self.assertEqual(r["raw_sha256"], sha256(data).hexdigest())
                self.assertEqual(r["body_bytes"], len(data))
                self.assertTrue(r["retrieved_at_utc"].endswith("Z"))
                self.assertTrue(r["request_started_at_utc"].endswith("Z"))
                self.assertLessEqual(r["request_started_at_utc"], r["retrieved_at_utc"])
                self.assertEqual(r["http_status"], 200)
                self.assertTrue(r["source_url"].startswith("https://data.sec.gov/"))
                self.assertNotIn("research-contact@", json.dumps(r))
            if os.name == "posix":
                self.assertEqual(dest.stat().st_mode & 0o777, 0o700)
                for path in dest.iterdir():
                    self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_no_overwrite_or_duplicate_capture(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td) / "data"
            capture_all(dest, UA, opener=MockSECOpener(), sleeper=lambda _: None)
            with self.assertRaisesRegex(SECError, "DESTINATION_ALREADY_EXISTS"):
                capture_all(dest, UA, opener=MockSECOpener(), sleeper=lambda _: None)

    def test_invalid_user_agent_prevents_network_or_files(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td) / "data"
            opener = MockSECOpener()
            with self.assertRaisesRegex(SECError, "IDENTIFYING_USER_AGENT_REQUIRED"):
                capture_all(dest, "fake@example.com", opener=opener)
            self.assertEqual(opener.urls, [])
            self.assertFalse(dest.exists())

    def test_wrong_cik_is_rejected(self):
        with self.assertRaisesRegex(SECError, "SEC_CIK_IDENTITY_MISMATCH"):
            fetch_document("MSFT", "0000789019", "companyfacts", UA,
                           opener=MockSECOpener(wrong_cik=True))

    def test_redirect_is_rejected(self):
        with self.assertRaisesRegex(SECError, "SEC_REDIRECT_BLOCKED"):
            fetch_document("MSFT", "0000789019", "submissions", UA,
                           opener=MockSECOpener(redirect=True))

    def test_invalid_json_is_rejected(self):
        with self.assertRaisesRegex(SECError, "SEC_JSON_INVALID"):
            fetch_document("MSFT", "0000789019", "submissions", UA,
                           opener=MockSECOpener(bad_json=True))

    def test_partial_capture_does_not_claim_eight_of_eight(self):
        with tempfile.TemporaryDirectory() as td:
            dest = Path(td) / "data"
            opener = MockSECOpener(fail_at=3)
            with self.assertRaisesRegex(SECError, "SEC_FETCH_FAILED"):
                capture_all(dest, UA, opener=opener, sleeper=lambda _: None)
            self.assertEqual(len(list(dest.glob("*.receipt.json"))), 2)
            self.assertFalse((dest / "manifest.json").exists())

    def test_unsupported_document_kind_rejected_without_network(self):
        opener = MockSECOpener()
        with self.assertRaisesRegex(SECError, "SEC_DOCUMENT_KIND_UNSUPPORTED"):
            fetch_document("MSFT", "0000789019", "secrets", UA, opener=opener)
        self.assertEqual(opener.urls, [])

    def test_manual_symbol_endpoints_stay_at_sec_host(self):
        opener = MockSECOpener()
        with tempfile.TemporaryDirectory() as td:
            capture_all(Path(td) / "data", UA, opener=opener, sleeper=lambda _: None)
        self.assertTrue(all(url.startswith("https://data.sec.gov/") for url in opener.urls))
        self.assertEqual(len(set(opener.urls)), 8)
        self.assertTrue(all(ua == UA for ua in opener.user_agents))


if __name__ == "__main__":
    unittest.main()
