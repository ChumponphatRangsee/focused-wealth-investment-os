
-- Phase-1 live Holdings projection and operational state repair.
-- This migration NEVER changes accounting transactions, cost basis or portfolio source snapshots.
create table if not exists fwios.portfolio_live_holdings_batches_v1 (
 batch_id uuid primary key default gen_random_uuid(),
 received_at timestamptz not null default now(),
 source_system text not null default 'GOOGLE_SHEET_HOLDINGS_READ_ONLY',
 spreadsheet_id text not null,
 sheet_range text not null,
 source_digest text not null,
 position_count integer not null check (position_count > 0),
 unique_asset_count integer not null check (unique_asset_count > 0),
 constraint live_holdings_digest_unique unique (source_digest)
);
create table if not exists fwios.portfolio_live_holdings_rows_v1 (
 batch_id uuid not null references fwios.portfolio_live_holdings_batches_v1(batch_id) on delete restrict,
 source_row integer not null check (source_row >= 5),
 account_key text not null check (account_key in ('best','loan_money','mom')),
 asset_symbol text not null check (asset_symbol ~ '^[A-Z0-9._-]{1,20}$'),
 asset_class text not null check (asset_class in ('Stock','Crypto')),
 quantity numeric not null check (quantity > 0),
 source_position_status text not null default 'OPEN' check (source_position_status='OPEN'),
 primary key (batch_id,source_row),
 unique(batch_id,account_key,asset_symbol)
);
create index if not exists live_holdings_rows_asset_idx on fwios.portfolio_live_holdings_rows_v1(asset_symbol);
create or replace view fwios.v_portfolio_live_positions_current_v1 as
 with latest as (
  select batch_id,received_at,source_digest from fwios.portfolio_live_holdings_batches_v1
  order by received_at desc,batch_id desc limit 1
 )
 select r.account_key,a.account_name,r.asset_symbol,r.asset_class,r.quantity,
        r.source_row,r.source_position_status,b.batch_id,b.received_at,b.source_digest
 from latest b join fwios.portfolio_live_holdings_rows_v1 r on r.batch_id=b.batch_id
 join fwios.portfolio_accounts a on a.account_key=r.account_key;
create or replace view fwios.v_portfolio_live_account_valuation_v1 as
 select case when grouping(p.account_key)=1 then 'ALL' else p.account_key end account_view_key,
        count(*)::integer open_position_rows,
        count(distinct p.asset_symbol)::integer unique_open_assets,
        sum(p.quantity*q.price_thb) portfolio_value_thb,
        count(*) filter (where q.asset_symbol is null or q.freshness_status<>'FRESH')::integer unpriced_positions,
        min(p.received_at) projection_received_at,
        max(p.batch_id::text) source_batch_id,
        case when count(*) filter (where q.asset_symbol is null or q.freshness_status<>'FRESH')=0
             then 'PASS' else 'BLOCKED' end valuation_gate
 from fwios.v_portfolio_live_positions_current_v1 p
 left join fwios.v_portfolio_market_quote_current q on q.asset_symbol=p.asset_symbol
 group by grouping sets ((p.account_key),());
create or replace view fwios.v_portfolio_live_quantity_reconciliation_v1 as
 with legacy as (
  select account_key,asset_symbol,sum(quantity) quantity
  from fwios.v_portfolio_positions_current
  where upper(source_position_status)='OPEN' and quantity>0
  group by account_key,asset_symbol
 ),
 latest as (
  select account_key,asset_symbol,sum(quantity) quantity
  from fwios.v_portfolio_live_positions_current_v1
  group by account_key,asset_symbol
 )
 select coalesce(l.account_key,s.account_key) account_key,
        coalesce(l.asset_symbol,s.asset_symbol) asset_symbol,
        l.quantity sheet_quantity,s.quantity historical_snapshot_quantity,
        l.quantity-coalesce(s.quantity,0) quantity_difference,
        case when l.quantity is null then 'HISTORICAL_ONLY'
             when s.quantity is null then 'SHEET_ONLY'
             when abs(l.quantity-s.quantity)<0.00000001 then 'MATCH'
             else 'DRIFT' end reconciliation_status
 from latest l full outer join legacy s
  on s.account_key=l.account_key and s.asset_symbol=l.asset_symbol;
revoke all on fwios.portfolio_live_holdings_batches_v1,fwios.portfolio_live_holdings_rows_v1
 from anon,authenticated;
revoke all on fwios.v_portfolio_live_positions_current_v1,
 fwios.v_portfolio_live_account_valuation_v1,fwios.v_portfolio_live_quantity_reconciliation_v1
 from anon,authenticated;

-- Preserve the complete original 145-element journal (including string-encoded JSON)
-- before converting system_state to a standard last-write-wins JSON object.
create table if not exists fwios.system_state_legacy_archive_v1 (
 state_key text primary key,
 legacy_state_value jsonb not null,
 archived_at timestamptz not null default now(),
 migration_note text not null default 'phase1_normalize_current_state_preserve_legacy_journal'
);
revoke all on fwios.system_state_legacy_archive_v1 from anon,authenticated;
insert into fwios.system_state_legacy_archive_v1(state_key,legacy_state_value)
select state_key,state_value from fwios.system_state
where state_key='architecture_consolidation_v1'
  and jsonb_typeof(state_value)='array'
on conflict(state_key) do nothing;
with normalized as (
 select s.state_key,e.ord,
        case when jsonb_typeof(e.v)='string' then (e.v #>> '{}')::jsonb else e.v end obj
 from fwios.system_state s,
 lateral jsonb_array_elements(s.state_value) with ordinality e(v,ord)
 where s.state_key='architecture_consolidation_v1'
   and jsonb_typeof(s.state_value)='array'
), merged as (
 select state_key,jsonb_object_agg(k,v order by ord) result
 from normalized cross join lateral jsonb_each(obj) kv(k,v)
 group by state_key
)
update fwios.system_state s
set state_value=m.result,updated_at=now(),
 source_ref='PHASE1_STATE_NORMALIZED_ARCHIVE_V1'
from merged m
where s.state_key=m.state_key;
