-- Deterministic authority ordering: canonical-evidence hardening wins same-timestamp ties over base refresh.
-- No Quality Hardening threshold changes.

create or replace view fwios.v_candidate_quality_hardening_current as
 SELECT DISTINCT ON (ticker) hardening_snapshot_id,
    ticker,
    valuation_run_id,
    mispricing_snapshot_id,
    policy_version_id,
    business_durability_gate,
    owner_earnings_gate,
    value_trap_gate,
    valuation_robustness_gate,
    overall_gate,
    valuation_confidence,
    sbc_to_revenue,
    bear_upside,
    base_upside,
    probability_weighted_upside,
    durability_anchor_years,
    durability_evidence_count,
    dilution_reconciliation_pass,
    owner_fcf_conversion_pass,
    counter_thesis_evidence_count,
    structural_risk_review_pass,
    growth_anchor_verified,
    evidence_payload,
    source_reference,
    created_at
   FROM fwios.candidate_quality_hardening_snapshots
  ORDER BY ticker, created_at DESC, (
        CASE
            WHEN (evidence_payload ->> 'refresh_policy'::text) = 'POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1'::text THEN 2
            WHEN (evidence_payload ->> 'refresh_policy'::text) = 'POL-QUALITY-HARDENING-REFRESH-V1'::text THEN 1
            ELSE 0
        END) DESC, hardening_snapshot_id DESC;;
