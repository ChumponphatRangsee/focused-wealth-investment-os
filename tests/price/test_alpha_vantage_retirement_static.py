"""Static guard: no active Alpha Vantage collector after retirement.

No provider calls, database connections, cron invocations or production writes.
"""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORKER = ROOT / "supabase/functions/price-market-refresh-v1/index.ts"
MIGRATION = ROOT / "supabase/migrations/20261109040630_retire_alpha_vantage_cron_v1.sql"


def test_stock_collector_has_no_alpha_dispatch():
    source = WORKER.read_text(encoding="utf-8")
    assert "ALPHA_VANTAGE" not in source
    assert "alphavantage.co" not in source
    assert "stockCloseRefresh" not in source
    assert "alphaDailyFetch" not in source
    assert '["CRYPTO","FX","TWELVE_STOCK_EOD_FALLBACK"]' in source
    assert '"TWELVE_DATA_API_KEY"' in source
    assert "portfolio_writes:0,auto_trade:false" in source


def test_cron_cutover_keeps_dst_and_twelve_only_schedule():
    sql = MIGRATION.read_text(encoding="utf-8")
    assert "cron.alter_job" in sql
    assert "schedule=>'55 5,6 * * *'" in sql
    assert "schedule=>'10 6,7 * * *'" in sql
    assert "'TWELVE_STOCK_EOD_FALLBACK'" in sql
    assert "01:55" in sql
    assert "02:10" in sql
    assert "America/New_York" in sql
    assert "ALPHA_VANTAGE_API_KEY" not in sql
