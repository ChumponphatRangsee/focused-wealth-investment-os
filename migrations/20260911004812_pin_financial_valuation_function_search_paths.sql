-- Pin search_path for Financials valuation functions.
-- Logic is unchanged; this is security hardening only.

alter function fwios.justified_tbv_fv_v1(numeric,numeric,numeric,numeric)
  set search_path = pg_catalog, fwios;

alter function fwios.bank_rotce_tbv_fv_v1(numeric,numeric,numeric,numeric)
  set search_path = pg_catalog, fwios;

alter function fwios.insurance_book_value_roe_fv_v1(numeric,numeric,numeric,numeric)
  set search_path = pg_catalog, fwios;
