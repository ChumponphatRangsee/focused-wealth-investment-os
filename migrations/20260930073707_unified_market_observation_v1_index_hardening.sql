
create index if not exists market_daily_closes_secondary_observation_idx
  on fwios.market_daily_closes(secondary_observation_id);
create index if not exists market_daily_closes_verification_idx
  on fwios.market_daily_closes(market_verification_id);

create index if not exists market_price_snapshots_crosscheck_observation_idx
  on fwios.market_price_snapshots(crosscheck_observation_id);
create index if not exists market_price_snapshots_selected_observation_idx
  on fwios.market_price_snapshots(selected_observation_id);
create index if not exists market_price_snapshots_verification_idx
  on fwios.market_price_snapshots(market_verification_id);

create index if not exists portfolio_market_quote_snapshots_fx_observation_idx
  on fwios.portfolio_market_quote_snapshots(fx_observation_id);

create index if not exists market_verification_sets_primary_observation_idx
  on fwios.market_verification_sets(primary_observation_id);
create index if not exists market_verification_sets_secondary_observation_idx
  on fwios.market_verification_sets(secondary_observation_id)
  where secondary_observation_id is not null;
create index if not exists market_verification_sets_selected_observation_idx
  on fwios.market_verification_sets(selected_observation_id)
  where selected_observation_id is not null;
