/** Sentinel profit values that must never surface in telemetry or UI. */
export const PLACEHOLDER_PROFIT_VALUES = new Set([
  9_999_999,
  9_999_999.0,
  99_999_999,
  Number.MAX_SAFE_INTEGER,
]);

export function isPlaceholderProfit(value: unknown): boolean {
  if (value === null || value === undefined) return false;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return true;
  if (n <= 0) return false;
  return PLACEHOLDER_PROFIT_VALUES.has(n);
}

export function sanitizeProfitUsd(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n) || n <= 0 || isPlaceholderProfit(n)) return null;
  return n;
}

export function sanitizeDebtUsd(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n) || n < 0) return null;
  return n;
}
