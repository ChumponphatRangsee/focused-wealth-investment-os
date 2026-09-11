update fwios.decision_refresh_provider_registry
set config = config || jsonb_build_object(
  'validator_symbol','AAPL',
  'validator_consensus_symbol','IBM',
  'validator_schedule','17 * * * *',
  'validator_recheck_hours',24
), updated_at=now()
where provider_key in ('TWELVE_DATA','ALPHA_VANTAGE');
