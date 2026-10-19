-- PR2 Controlled Research Ingestion v1 index hardening
create index if not exists research_ingest_receipts_v1_instrument_idx
  on fwios.research_ingest_receipts_v1(instrument_id, applied_at desc);
