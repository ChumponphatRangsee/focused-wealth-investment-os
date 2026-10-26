-- EOG + NFLX period-aware v2 live regression
-- READ ONLY.

do $$
begin
  -- 1: semantic share identity exists.
  if not exists (
    select 1 from fwios.metric_definitions
    where metric_code='DILUTED_SHARES'
      and active
      and value_kind='NUMERIC'
      and canonical_unit='M shares'
      and metadata->>'share_semantics'='DILUTED_WEIGHTED_AVERAGE'
  ) then raise exception 'T01 DILUTED_SHARES semantic definition missing'; end if;

  -- 2: EOG v2 remains experimental/no cutover.
  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='E&P_NORMALIZED_FCF_YIELD_V1::2.0'
      and status='EXPERIMENTAL'
      and input_contract->>'production_read_cutover'='false'
  ) then raise exception 'T02 EOG v2 contract invalid'; end if;

  -- 3: NFLX v2 remains experimental/no cutover.
  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='STREAMING_FCF_DCF_V1::2.0'
      and status='EXPERIMENTAL'
      and input_contract->>'production_read_cutover'='false'
  ) then raise exception 'T03 NFLX v2 contract invalid'; end if;

  -- 4: production authority remains singular for both models.
  if exists (
    select model_id
    from fwios.valuation_model_versions
    where model_id in ('E&P_NORMALIZED_FCF_YIELD_V1','STREAMING_FCF_DCF_V1')
    group by model_id
    having count(*) filter(where status='PRODUCTION')<>1
  ) then raise exception 'T04 production authority changed'; end if;

  -- 5: NFLX Q3 controlled APPLY receipt is present and exact.
  if not exists (
    select 1 from fwios.research_ingest_receipts_v1
    where payload_fingerprint='1660dc6c3ba9a084e26194f41d89f48d'
      and receipt_id='d442ba44-c090-4d14-aec7-c7bc38c31c75'::uuid
      and status='APPLIED'
      and evidence_inserted=1
      and observations_inserted=7
  ) then raise exception 'T05 NFLX Q3 APPLY receipt missing'; end if;

  -- 6: EOG shadow is semantic parity and non-production.
  if not exists (
    select 1 from fwios.valuation_runs
    where run_id='VAL-SHADOW-EOG-EP-V2-20261026'
      and model_version_id='E&P_NORMALIZED_FCF_YIELD_V1::2.0'
      and production_eligible=false
      and abs(bear_fv_per_share-43.55440384)<0.000001
      and abs(base_fv_per_share-170.2097883)<0.000001
      and abs(bull_fv_per_share-294.1920388)<0.000001
      and abs(probability_weighted_fv_per_share-169.5415048)<0.000001
  ) then raise exception 'T06 EOG shadow parity failed'; end if;

  -- 7: EOG resolver-backed shadow inputs are 8/8 PASS.
  if (select count(*) from fwios.valuation_run_inputs
      where run_id='VAL-SHADOW-EOG-EP-V2-20261026'
        and required and gate_status='PASS')<>8
  then raise exception 'T07 EOG required inputs are not 8/8 PASS'; end if;

  -- 8: NFLX Q3 shadow is expected and non-production.
  if not exists (
    select 1 from fwios.valuation_runs
    where run_id='VAL-SHADOW-NFLX-STREAM-V2-20261026'
      and model_version_id='STREAMING_FCF_DCF_V1::2.0'
      and production_eligible=false
      and abs(bear_fv_per_share-38.34206692)<0.000001
      and abs(base_fv_per_share-73.14268190)<0.000001
      and abs(bull_fv_per_share-121.18105874)<0.000001
      and abs(probability_weighted_fv_per_share-76.4521223650)<0.000001
  ) then raise exception 'T08 NFLX shadow values failed'; end if;

  -- 9: NFLX required resolver-backed inputs are 6/6 PASS and use DILUTED_SHARES.
  if (select count(*) from fwios.valuation_run_inputs
      where run_id='VAL-SHADOW-NFLX-STREAM-V2-20261026'
        and required and gate_status='PASS')<>6
     or not exists (
       select 1 from fwios.valuation_run_inputs
       where run_id='VAL-SHADOW-NFLX-STREAM-V2-20261026'
         and input_key='diluted_shares'
         and source_key='AI-OBS-4AC23C23E25C23E3FFB142D2'
         and gate_status='PASS'
     )
  then raise exception 'T09 NFLX required inputs/share semantics failed'; end if;

  -- 10: user-facing production dashboard is unchanged.
  if not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='EOG' and valuation_run_id='VAL-EOG-20260904-P087'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='NFLX' and valuation_run_id='VAL-NFLX-STREAM-20260911'
  ) then raise exception 'T10 production dashboard cutover occurred unexpectedly'; end if;
end $$;

select 'FWIOS EOG + NFLX PERIOD-AWARE V2: PASS (10/10, SHADOW/NON-PRODUCTION)' result;
