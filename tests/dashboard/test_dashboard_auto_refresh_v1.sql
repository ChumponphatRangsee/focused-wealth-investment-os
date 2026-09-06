with p as (select fwios.dashboard_refresh_payload_v1() payload),
     c as (select * from fwios.dashboard_refresh_cache where cache_key='PRIMARY'),
     a as (select * from fwios.dashboard_refresh_access where access_key='GOOGLE_SHEET_IMPORTDATA'),
     tests as (
select 'R01_PAYLOAD_GATE' test, ((select payload->>'refresh_gate' from p)='PASS') pass
union all select 'R02_CONTRACT', ((select payload->>'contract_id' from p)='FWIOS-CONTRACT-0.87.10')
union all select 'R03_PORTFOLIO_BATCH', ((select payload->>'portfolio_batch_id' from p)='PORTFOLIO-M2-20260905-01')
union all select 'R04_ACCOUNT_ROWS', (jsonb_array_length((select payload#>'{data,account_summary}' from p))=4)
union all select 'R05_HOLDING_ROWS', (jsonb_array_length((select payload#>'{data,holdings}' from p))=25)
union all select 'R06_OPPORTUNITY_ROWS', (jsonb_array_length((select payload#>'{data,opportunities}' from p))=2)
union all select 'R07_ALERT_ROWS', (jsonb_array_length((select payload#>'{data,alerts}' from p))=4)
union all select 'R08_CACHE_PRESENT', exists(select 1 from c)
union all select 'R09_CACHE_FINGERPRINT', ((select source_fingerprint from c)=(select payload->>'source_fingerprint' from p))
union all select 'R10_ACCESS_HASH_ONLY', ((select active from a)=true and length((select token_sha256 from a))=64)
union all select 'R11_HUMAN_ONLY', (((select payload#>>'{data,system_health,0,human_execution_only}' from p))::boolean=true)
union all select 'R12_NO_AUTO_TRADE', (((select payload#>>'{data,system_health,0,auto_trade}' from p))::boolean=false)
union all select 'R13_29_29_TX', ((select payload#>>'{data,system_health,0,source_transaction_count}' from p)=(select payload#>>'{data,system_health,0,transaction_pass_count}' from p))
union all select 'R14_16_16_POS', ((select payload#>>'{data,system_health,0,source_position_count}' from p)=(select payload#>>'{data,system_health,0,position_pass_count}' from p))
)
select test, case when pass then 'PASS' else 'FAIL' end status from tests order by test;
