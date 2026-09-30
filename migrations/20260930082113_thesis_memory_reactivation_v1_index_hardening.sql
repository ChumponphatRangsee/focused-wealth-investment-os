
create index if not exists thesis_decision_memory_instrument_idx
  on fwios.thesis_decision_memory(instrument_id);

create index if not exists thesis_reactivation_rules_ticker_idx
  on fwios.thesis_reactivation_rules(ticker);

create index if not exists thesis_reactivation_rules_instrument_idx
  on fwios.thesis_reactivation_rules(instrument_id);

create index if not exists thesis_reactivation_events_rule_idx
  on fwios.thesis_reactivation_events(rule_id);

create index if not exists thesis_reactivation_events_memory_idx
  on fwios.thesis_reactivation_events(decision_memory_id);

create index if not exists thesis_reactivation_events_instrument_idx
  on fwios.thesis_reactivation_events(instrument_id);

create index if not exists thesis_reactivation_events_thesis_event_idx
  on fwios.thesis_reactivation_events(trigger_thesis_event_id)
  where trigger_thesis_event_id is not null;
