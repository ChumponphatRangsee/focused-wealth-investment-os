-- Apply only after REG-M3-NEWCASH-V1-* passes completely.

insert into fwios.policy_registry(policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status)
values (
  'NEW_CASH_ALLOCATION',
  'CAPITAL_ALLOCATION',
  'New-Cash Capital Allocation',
  'Deterministically deploy new THB cash into the highest-ranked allocatable Immediate candidate while respecting staged position caps, portfolio concentration rules, focus controls and fail-closed traceability.',
  'fwios.preview_new_cash_allocation_v1',
  'ACTIVE'
)
on conflict (policy_key) do update
set lifecycle_status='ACTIVE',
    policy_domain=excluded.policy_domain,
    policy_name=excluded.policy_name,
    purpose=excluded.purpose,
    backing_object=excluded.backing_object,
    updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
)
values (
  'POL-NEW-CASH-ALLOCATION-V1',
  'NEW_CASH_ALLOCATION',
  '1.0',
  'ACTIVE',
  true,
  jsonb_build_object(
    'source_ranking_policy','POL-OPPORTUNITY-RANKING-V1',
    'eligible_bucket','IMMEDIATE_BUY_CANDIDATE',
    'supported_asset_classes',jsonb_build_array('Stock'),
    'max_deployed_assets_per_run',1,
    'new_position_post_money_cap',0.05,
    'existing_position_increment_cap',0.05,
    'exceptional_single_stock_max',0.30,
    'unallocated_cash_action','HOLD CASH_THB',
    'watchlist_allocation',false,
    'force_fill',false,
    'new_cash_first',true,
    'portfolio_mutation',false,
    'auto_trade',false,
    'human_review_required',true,
    'regression_suite','20/20 PASS',
    'activation_gate','BOUNDARY_PRODUCTION_PARITY_AND_NONMUTATION_PASS'
  ),
  'FWIOS M3.2 New-Cash Capital Allocation v1; activated after 20/20 deterministic regressions and security review',
  now()
)
on conflict (policy_version_id) do update
set lifecycle_status='ACTIVE',
    deterministic_scoring=true,
    config=excluded.config,
    source_reference=excluded.source_reference,
    effective_at=excluded.effective_at;
