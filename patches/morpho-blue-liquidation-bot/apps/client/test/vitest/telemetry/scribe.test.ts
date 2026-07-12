import { describe, expect, test } from "vitest";

import { Scribe } from "../../../src/telemetry/Scribe.js";
import { isPlaceholderProfit, sanitizeProfitUsd } from "../../../src/telemetry/sentinels.js";

describe("scribe sentinels", () => {
  test("detects and strips placeholder profit sentinels", () => {
    expect(isPlaceholderProfit(9_999_999)).toBe(true);
    expect(isPlaceholderProfit(9_999_999.0)).toBe(true);
    expect(sanitizeProfitUsd(9_999_999)).toBe(null);
    expect(sanitizeProfitUsd(42.5)).toBe(42.5);
    expect(sanitizeProfitUsd(null)).toBe(null);
  });
});

describe("Scribe armed queue", () => {
  const borrower = "0xae0a739c37000000000000000000000000000000" as const;
  const marketId = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef" as const;

  test("never publishes placeholder profit on simulation success", () => {
    const scribe = new Scribe("[test] ");
    scribe.arm({
      borrower,
      marketId,
      healthFactor: 1.0043,
      debtUsd: 10_020_000,
      pair: "USDe/USDC",
    });
    scribe.beginSimulation(borrower, marketId);
    const entry = scribe.recordSimulationSuccess(borrower, marketId, { profitUsd: 9_999_999 });
    expect(entry?.profitUsd).toBe(null);
    expect(entry?.status).toBe("sim_failed");
    expect(entry?.simError).toContain("placeholder");
  });

  test("publishes real profit and debt only", () => {
    const scribe = new Scribe("[test] ");
    scribe.arm({
      borrower,
      marketId,
      healthFactor: 0.984,
      debtUsd: 10_020_000,
      pair: "USDe/USDC",
    });
    scribe.beginSimulation(borrower, marketId);
    const entry = scribe.recordSimulationSuccess(borrower, marketId, { profitUsd: 128.42 });
    expect(entry?.status).toBe("executing");
    expect(entry?.profitUsd).toBe(128.42);
    expect(entry?.debtUsd).toBe(10_020_000);
  });

  test("simfail clears profit and debt placeholders", () => {
    const scribe = new Scribe("[test] ");
    scribe.arm({ borrower, marketId, healthFactor: 1.0043, debtUsd: 0, pair: "USDe/USDC" });
    scribe.beginSimulation(borrower, marketId);
    const entry = scribe.recordSimulationFailure(borrower, marketId, "simulation reverted");
    expect(entry?.status).toBe("sim_failed");
    expect(entry?.profitUsd).toBe(null);
    expect(entry?.debtUsd).toBe(0);
  });
});
