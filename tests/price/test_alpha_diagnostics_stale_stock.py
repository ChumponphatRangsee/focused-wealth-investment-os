import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COLLECTOR = (ROOT/"supabase/functions/price-market-refresh-v1/index.ts").read_text()
SHEET = (ROOT/"supabase/functions/price-sheet-sync-v1/index.ts").read_text()

class ProviderDiagnosticsAndStockStaleness(unittest.TestCase):
    def test_stock_fetch_uses_sanitized_diagnostics(self):
        self.assertIn("async function alphaDailyFetch(uri:string)",COLLECTOR)
        self.assertIn("function alphaProviderRejection(data:any)",COLLECTOR)
        for code in ("ALPHA_VANTAGE_DAILY_RATE_LIMIT",
                     "ALPHA_VANTAGE_FREQUENCY_RATE_LIMIT",
                     "ALPHA_VANTAGE_PLAN_RESTRICTED",
                     "ALPHA_VANTAGE_KEY_REJECTED",
                     "ALPHA_VANTAGE_NON_JSON_RESPONSE_CONTENT_",
                     "ALPHA_VANTAGE_UNEXPECTED_RESPONSE_OBJECT_"):
            with self.subTest(code=code): self.assertIn(code,COLLECTOR)
        self.assertIn("await withReservedProviderCall(",COLLECTOR)
        self.assertIn("rows.length+1",COLLECTOR)
        self.assertIn("if(r.status===429)",COLLECTOR)
        self.assertIn("r.headers.get(\"content-type\")",COLLECTOR)
        self.assertNotIn("throw new Error(why)",COLLECTOR)
        self.assertNotIn("console.log(data)",COLLECTOR)

    def test_dry_run_still_prevents_provider_calls(self):
        start=COLLECTOR.index("async function stockCloseRefresh(dry:boolean)")
        stock=COLLECTOR[start:]
        self.assertLess(stock.index('reason:"PREFLIGHT_NO_PROVIDER_REQUEST"'),
                        stock.index('vaultSecret("ALPHA_VANTAGE_API_KEY")'))
        self.assertLess(stock.index('vaultSecret("ALPHA_VANTAGE_API_KEY")'),
                        stock.index('await withReservedProviderCall('))
        self.assertIn('raw_payload->>\'price_only_stock_eod\'=\'true\'',stock)
        self.assertIn("from unnest(",stock)

    def test_stale_stock_status_only_uses_protected_lineage(self):
        self.assertIn('q.status==="STALE"',SHEET)
        self.assertIn('q.quote_kind==="STOCK_REGULAR_CLOSE"',SHEET)
        self.assertIn('q.provider==="ALPHA_VANTAGE_PRICE"||q.provider==="TWELVE_DATA"',SHEET)
        self.assertIn('STOCK_STALE_LINEAGE_MISMATCH_',SHEET)
        self.assertIn('String(record[8]||"")!==stale.observation_id',SHEET)
        self.assertIn('Number(record[3])!==stale.price_usd',SHEET)
        self.assertIn('String(record[6]||"")!=="STOCK_REGULAR_CLOSE"',SHEET)
        self.assertIn('staleStatusRows.set(row,symbol)',SHEET)
        self.assertIn('snapshot[5]="STALE"',SHEET)
        self.assertIn('values:[["STALE"]]',SHEET)
        self.assertIn("stockProtected.set(row,JSON.stringify(snapshot))",SHEET)
        self.assertIn("if (JSON.stringify((after[row - 1] || []).slice(0, 16)) !== snapshot)",SHEET)
        self.assertIn('stale_status_updated:receipt.staleStatusUpdated',SHEET)
        self.assertIn('stale_status_candidates:payload.stockStaleStatuses.length',SHEET)

    def test_no_price_or_portfolio_accounting_status_mutations(self):
        status_block=SHEET.split("for(const row of staleStatusRows.keys())",1)[1].split("updates.push({ range:",1)[0]
        self.assertIn('!F${row}',status_block)
        self.assertNotIn('!O${row}',status_block)
        self.assertNotIn('!D${row}',status_block)
        self.assertNotIn('Holdings!',status_block)
        self.assertNotIn('Transactions!',status_block)
        self.assertNotIn('Cost Basis!',status_block)

if __name__=="__main__":
    unittest.main()
