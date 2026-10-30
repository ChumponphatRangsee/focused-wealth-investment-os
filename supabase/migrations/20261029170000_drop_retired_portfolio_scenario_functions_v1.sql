-- Retired scenario computation functions, no longer part of price-only runtime.
DROP FUNCTION IF EXISTS fwios.preview_portfolio_scenario_actions_v1(text,numeric,text[],numeric[],text[]) RESTRICT;
DROP FUNCTION IF EXISTS fwios.preview_portfolio_scenario_metrics_v1(text,numeric,text[],numeric[],text[]) RESTRICT;
DROP FUNCTION IF EXISTS fwios.preview_portfolio_scenario_positions_v1(text,numeric,text[],numeric[],text[]) RESTRICT;
DROP FUNCTION IF EXISTS fwios.portfolio_scenario_current_input_gate_v1(text,numeric,text[],numeric[],text[]) RESTRICT;
DROP FUNCTION IF EXISTS fwios.portfolio_scenario_structural_gate_v1(text,numeric,text[],numeric[],text[]) RESTRICT;
