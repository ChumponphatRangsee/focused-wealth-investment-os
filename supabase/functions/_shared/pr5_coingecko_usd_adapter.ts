/**
 * PR5 CoinGecko native USD batch adapter.
 *
 * PURE ONLY: no fetch(), no Supabase client, no secrets, no DB mutation.
 * Call only from a separately authorized PR4 quota-reserved provider adapter.
 * Do not dispatch when CoinGecko entitlement/endpoint cost is unverified.
 * Validation is fail-closed. Never use THB or stale FX-derived USD as native.
 */
export type CryptoSymbol = "BTC" | "ETH" | "XRP" | "SOL" | "HBAR" | "DOGE";
const ID_BY_SYMBOL: Record<CryptoSymbol, string> = {
  BTC: "bitcoin",
  ETH: "ethereum",
  XRP: "ripple",
  SOL: "solana",
  HBAR: "hedera-hashgraph",
  DOGE: "dogecoin",
};
const MAX_AGE_MS = 15 * 60 * 1000;
const MAX_FUTURE_SKEW_MS = 5_000;

export type UsdCryptoCandidate = {
  asset: CryptoSymbol;
  coinGeckoId: string;
  price_usd: number;
  currency: "USD";
  provider: "COINGECKO";
  observation_type: "LIVE_QUOTE";
  market_status: "24X7";
  source_tier: "B";
  observed_at: string;
  session_date: string;
  source_native_usd: true;
};

export type UsdCryptoResult =
  | { asset: CryptoSymbol; status: "READY"; candidate: UsdCryptoCandidate }
  | { asset: CryptoSymbol; status: "MISSING" | "INVALID" | "STALE"; reason: string };

/** Provider endpoint + parameters, but does not make a request. */
export function buildCoinGeckoUsdBatchUrl(symbols: readonly CryptoSymbol[]): string {
  if (symbols.length < 1 || symbols.length > 6 ||
      new Set(symbols).size !== symbols.length ||
      symbols.some((s) => !Object.prototype.hasOwnProperty.call(ID_BY_SYMBOL, s))) {
    throw new Error("INVALID_CRYPTO_BATCH");
  }
  const url = new URL("https://api.coingecko.com/api/v3/simple/price");
  url.searchParams.set("ids", symbols.map((s) => ID_BY_SYMBOL[s]).join(","));
  url.searchParams.set("vs_currencies", "usd");
  url.searchParams.set("include_last_updated_at", "true");
  return url.toString();
}

function isObject(v: unknown): v is Record<string, unknown> {
  return !!v && typeof v === "object" && !Array.isArray(v);
}

/**
 * Parse a response body obtained by an already quota-authorized caller.
 * Bad/stale values are NEVER returned as READY and must not be persisted.
 */
export function parseCoinGeckoUsdBatch(
  body: unknown,
  symbols: readonly CryptoSymbol[],
  checkedAt: Date,
): UsdCryptoResult[] {
  if (!Number.isFinite(checkedAt.getTime())) throw new Error("INVALID_CAPTURE_TIME");
  if (!isObject(body)) throw new Error("INVALID_PROVIDER_BODY");

  return symbols.map((asset) => {
    const coinGeckoId = ID_BY_SYMBOL[asset];
    if (!coinGeckoId) return { asset, status: "INVALID", reason: "UNKNOWN_SYMBOL" };
    const row = body[coinGeckoId];
    if (!isObject(row)) return { asset, status: "MISSING", reason: "SYMBOL_ABSENT" };
    const price = row.usd;
    if (typeof price !== "number" || !Number.isFinite(price) || price <= 0) {
      return { asset, status: "INVALID", reason: "USD_VALUE_NOT_VALID" };
    }
    const timestamp = row.last_updated_at;
    if (typeof timestamp !== "number" || !Number.isInteger(timestamp) ||
        timestamp <= 0) {
      return { asset, status: "INVALID", reason: "PROVIDER_TIMESTAMP_MISSING" };
    }
    const observedAtMs = timestamp * 1000;
    if (!Number.isFinite(observedAtMs) ||
        observedAtMs > checkedAt.getTime() + MAX_FUTURE_SKEW_MS) {
      return { asset, status: "INVALID", reason: "FUTURE_PROVIDER_TIMESTAMP" };
    }
    if (checkedAt.getTime() - observedAtMs > MAX_AGE_MS) {
      return { asset, status: "STALE", reason: "USD_QUOTE_EXPIRED" };
    }
    const iso = new Date(observedAtMs).toISOString();
    return {
      asset,
      status: "READY",
      candidate: {
        asset, coinGeckoId, price_usd: price, currency: "USD",
        provider: "COINGECKO", observation_type: "LIVE_QUOTE",
        market_status: "24X7", source_tier: "B",
        observed_at: iso, session_date: iso.slice(0, 10),
        source_native_usd: true,
      },
    };
  });
}
