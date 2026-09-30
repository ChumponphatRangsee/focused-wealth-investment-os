-- Metric Observation v2 index hardening
-- Follow-up for Supabase advisor: cover metric_legacy_mappings.metric_code FK.

create index if not exists metric_legacy_mappings_metric_code_idx
  on fwios.metric_legacy_mappings(metric_code);
