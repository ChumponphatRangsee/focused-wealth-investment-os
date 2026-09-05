-- Security hardening for FWIOS-CONTRACT-0.87.4 M2 policy functions.
-- Supabase security advisor flagged mutable search_path on the new immutable SQL functions.
-- Keep functions invoker-only and pin lookup resolution explicitly.

alter function fwios.score_revision_delta_v1(numeric) set search_path = pg_catalog, fwios;
alter function fwios.calculate_revision_score_v1(numeric,numeric,numeric,numeric) set search_path = pg_catalog, fwios;
alter function fwios.revision_gate_v1(numeric,numeric,numeric,numeric,text,text) set search_path = pg_catalog, fwios;
alter function fwios.score_chase_excess_v1(numeric) set search_path = pg_catalog, fwios;
alter function fwios.score_price_vs_fv_risk_v1(numeric) set search_path = pg_catalog, fwios;
alter function fwios.calculate_chase_risk_v1(numeric,numeric,numeric,numeric) set search_path = pg_catalog, fwios;
alter function fwios.chase_gate_v1(numeric,numeric,numeric,numeric,numeric) set search_path = pg_catalog, fwios;
