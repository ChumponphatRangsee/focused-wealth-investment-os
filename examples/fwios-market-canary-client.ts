/**
 * FWIOS PR4: read-only canary client for authenticated Supabase users.
 * Copy into the actual frontend ONLY when the consumer is ready.
 * This module never sends a service-role key or a database password.
 * It does not authorize trading or accounting use.
 */
export type CanaryAsset = "BTC" | "NVDA" | "TTWO" | "USDTHB";

export type CanaryStatus =
  | "FRESH" | "LAST_CLOSE" | "FRESH_REFERENCE" | "STALE"
  | "MISSING" | "UNSUPPORTED";

export type MarketCanaryQuote = {
  asset: CanaryAsset;
  status: CanaryStatus;
  price?: number;
  currency?: "USD" | "THB";
  provider?: string;
  observation_type?: "LIVE_QUOTE" | "REGULAR_CLOSE" | "FX";
  quote_kind?: "CRYPTO_QUOTE" | "STOCK_REGULAR_CLOSE" | "FX_ATTACHED_REFERENCE";
  session_date?: string;
  observed_at?: string;
  valid_until?: string;
  canary_only: true;
  read_only?: true;
  new_provider_calls?: 0;
  new_quota_reservations?: 0;
  accounting_eligible: false;
  valuation_eligible: false;
  trading_eligible?: false;
};

type MinimalSupabaseSessionClient = {
  auth: {
    getSession(): Promise<{
      data: { session: { access_token: string } | null };
      error: { message: string } | null;
    }>;
  };
};

const endpoint =
  "https://ysjbmeukwbfnxnwqchuq.supabase.co/functions/v1/market-price-canary-v1";

export async function readMarketCanary(
  client: MinimalSupabaseSessionClient,
  publishableKey: string,
  asset: CanaryAsset = "BTC",
): Promise<MarketCanaryQuote> {
  const { data, error } = await client.auth.getSession();
  if (error || !data.session) throw new Error("Supabase user sign-in required");

  const url = new URL(endpoint);
  url.searchParams.set("asset", asset);
  const response = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${data.session.access_token}`,
      apikey: publishableKey, // ONLY the public/publishable key, not service_role
      Accept: "application/json",
    },
    cache: "no-store",
  });

  const quote = (await response.json()) as MarketCanaryQuote & {error?: string};
  if (!response.ok)
    throw new Error(quote.error ?? `Canary HTTP ${response.status}`);
  if (quote.canary_only !== true || quote.accounting_eligible !== false
    || quote.valuation_eligible !== false)
    throw new Error("Unexpected canary authorization contract");

  return quote;
}
