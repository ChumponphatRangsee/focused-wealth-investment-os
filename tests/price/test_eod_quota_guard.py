"""Twelve-only EOD quota and provenance guard contract; no live provider calls."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "supabase/functions/price-market-refresh-v1/index.ts").read_text(encoding="utf-8")
GUARDS = (ROOT / "supabase/functions/price-market-refresh-v1/twelve-eod-guards.ts").read_text(encoding="utf-8")
STOCK = SOURCE.split("async function twelveFallbackRefresh(dry:boolean){", 1)[1].split("\n}\n\nDeno.serve", 1)[0]


class StockEodQuotaGuardContract(unittest.TestCase):
    def test_duplicate_and_dryrun_preflight_precede_key_and_provider(self):
        key = STOCK.index('const apiKey=await vaultSecret("TWELVE_DATA_API_KEY")')
        reserve = STOCK.index('reserveEod("TWELVE_DATA"')
        dispatch = STOCK.index('withReservedProviderCall("TWELVE_DATA"')
        self.assertLess(STOCK.index("const certifiedRows=await sql!"), key)
        self.assertLess(STOCK.index("if(certified.size===symbols.length)"), key)
        self.assertLess(STOCK.index("if(certified.size>0)"), key)
        self.assertLess(STOCK.index("if(dry)return {"), key)
        self.assertLess(key, reserve)
        self.assertLess(reserve, dispatch)
        self.assertIn('reason:"PREFLIGHT_NO_PROVIDER_REQUEST"', STOCK)
        self.assertIn("provider_requests_attempted:0", STOCK)

    def test_existing_certified_observation_provenance_is_strict(self):
        required = (
            "o.session_date=${day}::date",
            "o.observation_type='REGULAR_CLOSE'",
            "o.market_status='CLOSED'",
            "o.provider='TWELVE_DATA'",
            "o.source_tier='A'",
            "o.value_currency='USD'",
            "o.provenance_status='PASS'",
            "o.observation_value>0",
            "normalized.payload->>'price_only_stock_eod'='true'",
            "normalized.payload->>'close_kind'='UNADJUSTED'",
            "normalized.payload->>'adjustment'='none'",
            "s.is_primary=true",
        )
        query = STOCK.split("const certifiedRows=await sql!", 1)[1].split("`;", 1)[0]
        for criterion in required:
            with self.subTest(criterion=criterion):
                self.assertIn(criterion, query)

    def test_partial_certified_session_fails_closed(self):
        self.assertIn('reason:"INCOMPLETE_CERTIFIED_SESSION_REQUIRES_REVIEW"', STOCK)
        self.assertIn("certified.size===symbols.length", STOCK)
        self.assertIn("certified.size>0", STOCK)
        self.assertIn("provider_requests_attempted:0,database_writes:0", STOCK)

    def test_real_eod_validation_and_atomic_write_unchanged(self):
        self.assertIn('interval:"1day"', STOCK)
        self.assertIn('adjust:"none"', STOCK)
        self.assertIn('parseTwelveDailyEod(data,symbol,day)', STOCK)
        self.assertIn("sessions[0]!==day", GUARDS)
        self.assertIn("TWELVE_DATA_SESSION_NOT_READY", GUARDS)
        self.assertIn("from unnest(", STOCK)
        self.assertIn("'REGULAR_CLOSE'", STOCK)
        self.assertIn("'source_session_date'", STOCK)
        self.assertIn("'price_only_stock_eod'", STOCK)

    def test_no_alpha_call_path_or_portfolio_mutations(self):
        self.assertNotIn("ALPHA_VANTAGE", SOURCE)
        self.assertNotIn("alphavantage.co", SOURCE)
        self.assertNotIn("stockCloseRefresh", SOURCE)
        self.assertNotIn("DELETE FROM", STOCK.upper())
        self.assertNotIn("UPDATE FWIOS.", STOCK.upper())
        self.assertIn("portfolio_writes:0,auto_trade:false", SOURCE)


if __name__ == "__main__":
    unittest.main()
