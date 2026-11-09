
-- Alpha Vantage Retirement: delete only its server-side credential after Worker v14
-- and Twelve-only Cron cutover were verified. Never read the plaintext secret.
DO $retire_vault$
DECLARE removed integer;
BEGIN
  IF (SELECT count(*) FROM vault.secrets WHERE name='ALPHA_VANTAGE_API_KEY')<>1
    OR (SELECT count(*) FROM cron.job WHERE jobid IN (17,18) AND active)<>2
    OR NOT EXISTS (SELECT 1 FROM cron.job WHERE jobid=17
             AND schedule='55 5,6 * * *'
             AND command LIKE '%TWELVE_STOCK_EOD_FALLBACK%'
             AND command NOT LIKE '%US_STOCK_EOD%')
    OR NOT EXISTS (SELECT 1 FROM cron.job WHERE jobid=18
             AND schedule='10 6,7 * * *')
    OR (SELECT count(*) FROM vault.secrets WHERE name='TWELVE_DATA_API_KEY')<>1
  THEN
    RAISE EXCEPTION 'ALPHA_RETIREMENT_CREDENTIAL_PREFLIGHT_FAILED';
  END IF;
  DELETE FROM vault.secrets WHERE name='ALPHA_VANTAGE_API_KEY';
  GET DIAGNOSTICS removed = ROW_COUNT;
  IF removed<>1 OR EXISTS(SELECT 1 FROM vault.secrets WHERE name='ALPHA_VANTAGE_API_KEY')
  THEN RAISE EXCEPTION 'ALPHA_RETIREMENT_CREDENTIAL_POSTFLIGHT_FAILED';
  END IF;
END $retire_vault$;

