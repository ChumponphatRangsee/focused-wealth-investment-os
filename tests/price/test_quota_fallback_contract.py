import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COLLECTOR = (ROOT / "supabase/functions/price-market-refresh-v1/index.ts").read_text()
GUARDS = (ROOT / "supabase/functions/price-market-refresh-v1/twelve-eod-guards.ts").read_text()
SYNC = (ROOT / "supabase/functions/price-sheet-sync-v1/index.ts").read_text()
QUOTA = (ROOT / "supabase/migrations/20261103100000_price_provider_quota_ledger_v1.sql").read_text()
SCHEDULE = (ROOT / "supabase/migrations/20261103103000_schedule_twelve_eod_fallback_v1.sql").read_text()

class QuotaAndFallbackContract(unittest.TestCase):
    def test_quota_schema_is_private_and_distinct_from_price_history(self):
        self.assertIn("CREATE SCHEMA IF NOT EXISTS fwios_quota", QUOTA)
        self.assertIn("fwios_quota.api_call_ledger", QUOTA)
        self.assertIn("REVOKE ALL ON SCHEMA fwios_quota FROM PUBLIC, anon, authenticated", QUOTA)
        self.assertIn("REVOKE ALL ON TABLE fwios_quota.api_call_ledger", QUOTA)
        self.assertNotIn("CREATE TABLE fwios.market_observations", QUOTA)
        self.assertNotIn("DELETE FROM fwios.market_observations", QUOTA)
        self.assertIn("UNIQUE(provider,key_alias,batch_id,symbol)", QUOTA)
        self.assertNotIn("decrypted_secret", QUOTA)

    def test_quota_reservation_is_atomic_and_budgeted(self):
        self.assertIn("pg_advisory_xact_lock", QUOTA)
        self.assertIn("v_daily:=20;v_minute:=4", QUOTA)
        self.assertIn("v_daily:=700;v_minute:=6", QUOTA)
        self.assertIn("interval '24 hours'", QUOTA)
        self.assertIn("interval '60 seconds'", QUOTA)
        self.assertIn("DUPLICATE_BATCH_ALREADY_RESERVED", QUOTA)
        self.assertIn("PROVIDER_COOLDOWN", QUOTA)
        self.assertIn("INTERNAL_24H_QUOTA_EXHAUSTED", QUOTA)
        self.assertIn("INTERNAL_MINUTE_QUOTA_EXHAUSTED", QUOTA)
        self.assertIn("IF v_rolling+v_count>v_daily", QUOTA)
        self.assertIn("IF v_short+v_count>v_minute", QUOTA)

    def test_only_undispatched_slots_can_be_canceled(self):
        self.assertIn("cancel_eod_undispatched_v1", QUOTA)
        cancel = QUOTA.split("CREATE OR REPLACE FUNCTION fwios_quota.cancel_eod_undispatched_v1",1)[1].split("END;$$",1)[0]
        self.assertIn("state='RESERVED'", cancel)
        self.assertIn("state='CANCELED'", cancel)
        self.assertNotIn("state='DISPATCHED'", cancel)

    def test_eod_requests_are_preceded_by_quota_guard(self):
        stock = COLLECTOR.split("async function stockCloseRefresh(dry:boolean){",1)[1].split("async function cancelUndispatched",1)[0]
        twelve = COLLECTOR.split("async function twelveFallbackRefresh(dry:boolean){",1)[1].split("\n}\n",1)[0]
        self.assertLess(stock.index('reason:"PREFLIGHT_NO_PROVIDER_REQUEST"'),stock.index('reserveEod("ALPHA_VANTAGE_PRICE"'))
        self.assertLess(stock.index('reserveEod("ALPHA_VANTAGE_PRICE"'),stock.index('withReservedProviderCall("ALPHA_VANTAGE_PRICE"'))
        self.assertLess(twelve.index('reason:"PREFLIGHT_NO_PROVIDER_REQUEST"'),twelve.index('reserveEod("TWELVE_DATA"'))
        self.assertLess(twelve.index('reserveEod("TWELVE_DATA"'),twelve.index('withReservedProviderCall("TWELVE_DATA"'))
        self.assertIn('cancelUndispatched("ALPHA_VANTAGE_PRICE"',stock)
        self.assertIn('cancelUndispatched("TWELVE_DATA"',twelve)

    def test_twelve_price_semantics_and_validation(self):
        for required in ('interval:"1day"','adjust:"none"','previousNyBusinessDay','TWELVE_DATA_SYMBOL_CURRENCY_MISMATCH',
                         'TWELVE_DATA_EXCHANGE_TIMEZONE_MISMATCH','CURRENT_SESSION_EOD_NOT_AVAILABLE',
                         'source:"TWELVE_DATA"','"REGULAR_CLOSE"','price_only_stock_eod:true',
                         "raw_payload->>'price_only_stock_eod'='true'"):
            with self.subTest(required=required):
                self.assertIn(required.replace('"REGULAR_CLOSE"',"'REGULAR_CLOSE'"),COLLECTOR+"\n"+GUARDS)
        self.assertIn('parseTwelveDailyEod(data,symbol,day)',COLLECTOR)
        self.assertIn('sessions[0]!==day',GUARDS)
        self.assertIn("from unnest(",COLLECTOR)
        self.assertIn('"TWELVE_STOCK_EOD_FALLBACK"',COLLECTOR)

    def test_sheet_accepts_only_certified_unadjusted_rows(self):
        self.assertIn("provider IN ('ALPHA_VANTAGE_PRICE','TWELVE_DATA')",SYNC)
        self.assertIn("raw_payload->>'price_only_stock_eod'='true'",SYNC)
        self.assertIn("raw_payload->>'adjustment'='none'",SYNC)
        self.assertIn("STOCK_STALE_LINEAGE_MISMATCH_",SYNC)
        self.assertIn('stale.provider',SYNC)
        self.assertIn("stock_count:receipt.stockSynced",SYNC)

    def test_cron_reuses_existing_two_jobs(self):
        self.assertIn("cron.alter_job",SCHEDULE)
        self.assertIn("job_id=>17",SCHEDULE)
        self.assertIn("job_id=>18",SCHEDULE)
        self.assertIn("01:55",SCHEDULE)
        self.assertIn("02:10",SCHEDULE)
        self.assertIn("America/New_York",SCHEDULE)
        self.assertNotIn("cron.schedule(",SCHEDULE)
        self.assertNotIn("cron.unschedule(",SCHEDULE)

if __name__ == "__main__":
    unittest.main()
