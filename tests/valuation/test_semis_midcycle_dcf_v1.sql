-- SEMIS_MIDCYCLE_DCF_V1 production parity
select
 fwios.semis_midcycle_dcf_fv_v1(127.006,array[0.15,0.12,0.10,0.08,0.06]::numeric[],0.115,0.03,11.320,24.1) bear,
 fwios.semis_midcycle_dcf_fv_v1(127.006,array[0.30,0.25,0.20,0.15,0.10]::numeric[],0.10,0.035,11.320,24.1) base,
 fwios.semis_midcycle_dcf_fv_v1(127.006,array[0.40,0.32,0.25,0.20,0.15]::numeric[],0.09,0.04,11.320,24.1) bull;
-- expected: 87.03032203 / 166.16708908 / 273.20947981
-- PW 25/50/25 = 173.14349500
-- runtime regression: REG-SEMIS-V1-NVDA-PARITY = PASS.
-- Equity bridge 11.320 = conservative net cash 23.220 less signed Hugging Face purchase consideration 11.900.