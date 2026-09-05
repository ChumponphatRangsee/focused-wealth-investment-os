-- REG-M3-NEWCASH-V1-* deterministic regression suite.
-- Expected production context: PORTFOLIO-M2-20260905-01 + OPPRANK-M3-20260905-01.

begin;

do $$
declare
  n numeric;
  t text;
  add_amt numeric;
  hold_amt numeric;
  c integer;
  before_v numeric;
  after_v numeric;
  gate_v text;
begin
  -- 1. New position cap = 5% post-money.
  n := fwios.new_cash_capacity_v1(false,0,400000,'Stock');
  if abs(n-20000) >= 0.01 then raise exception 'CAP-NEW failed: %', n; end if;

  -- 2. Existing position staged add = max 5pp.
  n := fwios.new_cash_capacity_v1(true,100000,500000,'Stock');
  if abs(n-25000) >= 0.01 then raise exception 'CAP-EXIST failed: %', n; end if;

  -- 3. 30% headroom binds.
  n := fwios.new_cash_capacity_v1(true,148000,500000,'Stock');
  if abs(n-2000) >= 0.01 then raise exception 'CAP-HEADROOM failed: %', n; end if;

  -- 4. Already-over-30 receives zero capacity.
  n := fwios.new_cash_capacity_v1(true,160000,500000,'Stock');
  if n <> 0 then raise exception 'CAP-OVER30 failed: %', n; end if;

  -- 5. Unsupported asset class fails closed.
  n := fwios.new_cash_capacity_v1(false,0,400000,'Crypto');
  if n <> 0 then raise exception 'CAP-ASSETCLASS failed: %', n; end if;

  -- 6. Valid pure input gate passes.
  t := fwios.new_cash_input_gate_v1(10000,'B1','PASS','B1','PASS','ACTIVE');
  if t <> 'PASS' then raise exception 'INPUT-PASS failed: %', t; end if;

  -- 7. Zero cash blocks.
  t := fwios.new_cash_input_gate_v1(0,'B1','PASS','B1','PASS','ACTIVE');
  if t <> 'BLOCKED - INVALID NEW CASH' then raise exception 'INPUT-ZERO failed: %', t; end if;

  -- 8. Stale ranking blocks.
  t := fwios.new_cash_input_gate_v1(10000,'B2','PASS','B1','PASS','ACTIVE');
  if t <> 'BLOCKED - STALE PORTFOLIO/RANKING' then raise exception 'INPUT-STALE failed: %', t; end if;

  -- 9. Current production context is ready.
  t := fwios.new_cash_current_input_gate_v1(50000);
  if t <> 'PASS' then raise exception 'CURRENT-GATE failed: %', t; end if;

  -- 10. At most one ADD asset.
  select count(distinct asset_symbol) into c from fwios.preview_new_cash_allocation_v1(100000) where action_type='ADD';
  if c > 1 then raise exception 'ONE-ASSET failed: %', c; end if;

  -- 11. RDDT Value-Wait receives zero.
  select count(*) into c from fwios.preview_new_cash_allocation_v1(100000) where action_type='ADD' and asset_symbol='RDDT';
  if c <> 0 then raise exception 'WATCHLIST-NOADD failed'; end if;

  -- 12. Every ADD traces to ranking + Decision Snapshot.
  select count(*) into c from fwios.preview_new_cash_allocation_v1(50000)
   where action_type='ADD' and (ranking_candidate_id is null or decision_snapshot_id is null);
  if c <> 0 then raise exception 'TRACE failed: %', c; end if;

  -- 13. THB 10k parity.
  select coalesce(sum(amount_thb),0) into add_amt from fwios.preview_new_cash_allocation_v1(10000) where action_type='ADD' and asset_symbol='PINS';
  select coalesce(sum(amount_thb),0) into hold_amt from fwios.preview_new_cash_allocation_v1(10000) where action_type='HOLD';
  if abs(add_amt-10000)>=0.01 or hold_amt<>0 then raise exception 'PINS-10K failed: add %, hold %',add_amt,hold_amt; end if;

  -- 14. THB 50k parity.
  select coalesce(sum(amount_thb),0) into add_amt from fwios.preview_new_cash_allocation_v1(50000) where action_type='ADD' and asset_symbol='PINS';
  select coalesce(sum(amount_thb),0) into hold_amt from fwios.preview_new_cash_allocation_v1(50000) where action_type='HOLD';
  if abs(add_amt-19545.30)>=0.01 or abs(hold_amt-30454.70)>=0.01 then raise exception 'PINS-50K failed: add %, hold %',add_amt,hold_amt; end if;

  -- 15. THB 100k parity.
  select coalesce(sum(amount_thb),0) into add_amt from fwios.preview_new_cash_allocation_v1(100000) where action_type='ADD' and asset_symbol='PINS';
  select coalesce(sum(amount_thb),0) into hold_amt from fwios.preview_new_cash_allocation_v1(100000) where action_type='HOLD';
  if abs(add_amt-22045.30)>=0.01 or abs(hold_amt-77954.70)>=0.01 then raise exception 'PINS-100K failed: add %, hold %',add_amt,hold_amt; end if;

  -- 16. Concentration direction improves for 50k preview.
  select before_value,after_value into before_v,after_v from fwios.preview_new_cash_metrics_v1(50000) where metric_name='max_single_stock_weight';
  if not(after_v < before_v) then raise exception 'CONCENTRATION-DIRECTION failed: % -> %',before_v,after_v; end if;

  -- 17. Crypto direction improves for 50k preview.
  select before_value,after_value into before_v,after_v from fwios.preview_new_cash_metrics_v1(50000) where metric_name='crypto_weight';
  if not(after_v < before_v) then raise exception 'CRYPTO-DIRECTION failed: % -> %',before_v,after_v; end if;

  -- 18. Focus deviation remains visible.
  select after_value,gate into after_v,gate_v from fwios.preview_new_cash_metrics_v1(50000) where metric_name='unique_open_assets';
  if after_v<>11 or gate_v<>'REVIEW - OUTSIDE 5-8 PREFERENCE' then raise exception 'FOCUS-REVIEW failed: %, %',after_v,gate_v; end if;

  -- 19. Preview creates no allocation run.
  select count(*) into c from fwios.capital_allocation_runs;
  if c<>0 then raise exception 'NO-RUN-MUTATION failed: %',c; end if;

  -- 20. Reconciled portfolio total remains unchanged.
  select abs((select source_total_value_thb from fwios.v_latest_portfolio_batch limit 1)
           - (select total_value_thb from fwios.v_portfolio_guardrails_current limit 1)) into n;
  if n>=0.0001 then raise exception 'NO-PORTFOLIO-MUTATION failed: %',n; end if;
end $$;

rollback;
