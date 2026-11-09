"""Static regression: guarded Crypto job rename keeps canonical history untouched.

Does not invoke a Worker, mutate an account, or request a provider quote.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIG = (ROOT / "supabase/migrations/20261109045146_rename_crypto_daily_snapshot_cron_to_price_refresh_v1.sql").read_text()
CONTRACT = (ROOT / "contracts/system-contract.yaml").read_text()
MARKET = (ROOT / "supabase/functions/price-market-refresh-v1/index.ts").read_text()


class CryptoCronRenameContract(unittest.TestCase):
    def test_cron_rename_atomic_guards_and_single_active_dispatch(self):
        self.assertIn("DO $rename_crypto$", MIG)
        self.assertIn("pg_advisory_xact_lock", MIG)
        self.assertIn("fwios-portfolio-crypto-daily-snapshot", MIG)
        self.assertIn("fwios-crypto-price-daily-refresh", MIG)
        self.assertIn("v_new_id := cron.schedule(", MIG)
        self.assertIn("cron.unschedule('fwios-portfolio-crypto-daily-snapshot')", MIG)
        self.assertIn("v_old.schedule, v_old.command", MIG)
        self.assertIn("v_new_id=14", MIG)
        self.assertIn("v_receipts_before", MIG)
        self.assertIn("CRYPTO_PRICE_CRON_RENAME_POSTFLIGHT_FAILED", MIG)
        self.assertIn("10 21,22 * * *", MIG)
        self.assertIn("'CRYPTO'", MIG)
        self.assertIn("current_database()", MIG)
        self.assertIn("current_user", MIG)

    def test_renamed_id_but_historical_id_remains_evidence(self):
        self.assertIn("new_job_id: 20", CONTRACT)
        self.assertIn("old_job_id: 14", CONTRACT)
        self.assertIn("active_cron_ids: [15,16,17,18,19,20]", CONTRACT)
        self.assertIn("scheduled_job_ids: [20, 15, 17]", CONTRACT)
        self.assertIn("portfolio_valuation_snapshot_active: false", CONTRACT)
        self.assertIn("crypto_and_stock_canonical_price_history_preserved: true", CONTRACT)

    def test_no_price_accounting_or_worker_mutation(self):
        for disallowed in (
            "DELETE FROM fwios.market_observations",
            "TRUNCATE fwios.market_observations",
            "DELETE FROM fwios_quota.api_call_ledger",
            "UPDATE Holdings",
            "UPDATE Transactions",
            "net.http_post(",
            "price-market-refresh-v1(", 
        ):
            with self.subTest(disallowed=disallowed):
                self.assertNotIn(disallowed, MIG)
        self.assertIn('["CRYPTO","FX","TWELVE_STOCK_EOD_FALLBACK"]', MARKET)
        self.assertIn("portfolio_writes:0,auto_trade:false", MARKET)


if __name__ == "__main__":
    unittest.main()
