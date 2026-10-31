import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / "supabase" / "functions" / "price-market-refresh-v1" / "index.ts").read_text(encoding="utf-8")
STOCK = SOURCE.split("async function stockCloseRefresh(dry:boolean){", 1)[1].split("\n}\n\nDeno.serve", 1)[0]

class StockEodQuotaGuardContract(unittest.TestCase):
    def test_duplicate_and_dryrun_preflights_precede_key_and_provider(self):
        key = STOCK.index('const apiKey=await vaultSecret("ALPHA_VANTAGE_API_KEY")')
        self.assertLess(STOCK.index("const already=await sql!"), key)
        self.assertLess(STOCK.index("if(certified.size===symbols.length)"), key)
        self.assertLess(STOCK.index("if(certified.size>0)"), key)
        self.assertLess(STOCK.index("if(dry)return {"), key)
        self.assertLess(key, STOCK.index("await jsonFetch(url.toString())"))
        self.assertIn('reason:"PREFLIGHT_NO_PROVIDER_REQUEST"', STOCK)
        self.assertIn("provider_called:false", STOCK)
        self.assertIn("provider_requests_attempted:0", STOCK)

    def test_existing_certified_obs_provenance_is_strict(self):
        required = (
            "o.session_date=${ny.day}::date",
            "o.observation_type='REGULAR_CLOSE'",
            "o.market_status='CLOSED'",
            "o.provider='ALPHA_VANTAGE_PRICE'",
            "o.source_tier='A'",
            "o.value_currency='USD'",
            "o.provenance_status='PASS'",
            "o.observation_value>0",
            "o.raw_payload->>'price_only_stock_eod'='true'",
            "s.is_primary=true",
        )
        query = STOCK.split("const already=await sql!", 1)[1].split("`;", 1)[0]
        for criterion in required:
            with self.subTest(criterion=criterion):
                self.assertIn(criterion, query)

    def test_partial_certified_session_fails_closed(self):
        self.assertIn('reason:"INCOMPLETE_CERTIFIED_SESSION_REQUIRES_REVIEW"', STOCK)
        self.assertIn("certified.size===symbols.length", STOCK)
        self.assertIn("certified.size>0", STOCK)
        self.assertIn("provider_requests_attempted:0,database_writes:0", STOCK)

    def test_real_EOD_validation_and_atomic_write_unchanged(self):
        self.assertIn('url.searchParams.set("function","TIME_SERIES_DAILY")', STOCK)
        self.assertIn('["4. close"]', STOCK)
        self.assertIn('rows.every(x=>x.session_date===ny.day)', STOCK)
        self.assertIn("from unnest(", STOCK)
        self.assertIn('provider_function:"TIME_SERIES_DAILY"', STOCK)
        self.assertIn("price_only_stock_eod:true", STOCK)

    def test_no_new_legacy_or_portfolio_mutations(self):
        self.assertNotIn("DELETE FROM", STOCK.upper())
        self.assertNotIn("UPDATE FWIOS.", STOCK.upper())
        self.assertIn("portfolio_writes:0,auto_trade:false", SOURCE)
        self.assertIn('ALPHA_VANTAGE_DAILY_RATE_LIMIT', STOCK)
        self.assertIn('ALPHA_VANTAGE_RATE_LIMIT', STOCK)

if __name__ == "__main__":
    unittest.main()
