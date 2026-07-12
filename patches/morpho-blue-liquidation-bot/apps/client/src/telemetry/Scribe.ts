import type { Address, Hex } from "viem";

import { isPlaceholderProfit, sanitizeDebtUsd, sanitizeProfitUsd } from "./sentinels.js";

export type ArmedQueueStatus =
  | "armed"
  | "simulating"
  | "executing"
  | "sim_failed"
  | "skipped"
  | "success"
  | "failed";

export interface ArmedQueueEntry {
  borrower: Address;
  marketId: Hex;
  status: ArmedQueueStatus;
  healthFactor: number | null;
  debtUsd: number | null;
  profitUsd: number | null;
  pair: string | null;
  simError: string | null;
  updatedAt: string;
}

export interface ArmInput {
  borrower: Address;
  marketId: Hex;
  healthFactor?: number | null;
  debtUsd?: number | null;
  pair?: string | null;
}

export interface SimulationResultInput {
  profitUsd?: number | null;
  simError?: string | null;
}

function entryKey(borrower: Address, marketId: Hex): string {
  return `${borrower.toLowerCase()}:${marketId}`;
}

function formatUsd(value: number | null): string {
  if (value === null) return "—";
  if (value >= 1_000_000) return `$${(value / 1_000_000).toFixed(2)}M`;
  if (value >= 1_000) return `$${(value / 1_000).toFixed(1)}K`;
  return `$${value.toFixed(2)}`;
}

export class Scribe {
  private readonly tag: string;
  private readonly armedQueue = new Map<string, ArmedQueueEntry>();

  constructor(logTag = "") {
    this.tag = logTag;
  }

  arm(input: ArmInput): ArmedQueueEntry {
    const entry: ArmedQueueEntry = {
      borrower: input.borrower,
      marketId: input.marketId,
      status: "armed",
      healthFactor: input.healthFactor ?? null,
      debtUsd: sanitizeDebtUsd(input.debtUsd),
      profitUsd: null,
      pair: input.pair ?? null,
      simError: null,
      updatedAt: new Date().toISOString(),
    };
    this.armedQueue.set(entryKey(input.borrower, input.marketId), entry);
    this.logEntry(entry);
    return entry;
  }

  beginSimulation(borrower: Address, marketId: Hex): ArmedQueueEntry | undefined {
    return this.patch(borrower, marketId, {
      status: "simulating",
      profitUsd: null,
      simError: null,
    });
  }

  recordSimulationSuccess(
    borrower: Address,
    marketId: Hex,
    input: SimulationResultInput,
  ): ArmedQueueEntry | undefined {
    if (input.profitUsd != null && isPlaceholderProfit(input.profitUsd)) {
      console.warn(
        `${this.tag}[Scribe] Rejected placeholder profit ${input.profitUsd} for ${borrower} — refusing to publish`,
      );
      return this.recordSimulationFailure(borrower, marketId, "placeholder profit rejected");
    }

    const profitUsd = sanitizeProfitUsd(input.profitUsd);
    if (profitUsd === null) {
      return this.recordSimulationFailure(borrower, marketId, "profit unavailable after simulation");
    }

    return this.patch(borrower, marketId, {
      status: "executing",
      profitUsd,
      simError: null,
    });
  }

  recordSimulationFailure(
    borrower: Address,
    marketId: Hex,
    simError: string,
  ): ArmedQueueEntry | undefined {
    const entry = this.patch(borrower, marketId, {
      status: "sim_failed",
      profitUsd: null,
      simError,
    });
    if (entry) {
      console.warn(`${this.tag}simfail ${borrower} market=${marketId.slice(0, 10)}… ${simError}`);
    }
    return entry;
  }

  recordSkipped(
    borrower: Address,
    marketId: Hex,
    reason: string,
  ): ArmedQueueEntry | undefined {
    return this.patch(borrower, marketId, {
      status: "skipped",
      profitUsd: null,
      simError: reason,
    });
  }

  recordSuccess(borrower: Address, marketId: Hex, profitUsd?: number | null): ArmedQueueEntry | undefined {
    return this.patch(borrower, marketId, {
      status: "success",
      profitUsd: sanitizeProfitUsd(profitUsd),
      simError: null,
    });
  }

  recordFailure(borrower: Address, marketId: Hex, reason: string): ArmedQueueEntry | undefined {
    return this.patch(borrower, marketId, {
      status: "failed",
      profitUsd: null,
      simError: reason,
    });
  }

  getArmedQueue(): ArmedQueueEntry[] {
    return [...this.armedQueue.values()].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  publishArmedQueue(): void {
    const queue = this.getArmedQueue();
    if (queue.length === 0) return;
    console.log(`${this.tag}[Scribe] Armed Queue (${queue.length})`);
    for (const entry of queue.slice(0, 20)) {
      this.logEntry(entry);
    }
  }

  private patch(
    borrower: Address,
    marketId: Hex,
    patch: Partial<ArmedQueueEntry>,
  ): ArmedQueueEntry | undefined {
    const key = entryKey(borrower, marketId);
    const current = this.armedQueue.get(key);
    if (!current) return undefined;

    const next: ArmedQueueEntry = {
      ...current,
      ...patch,
      borrower: current.borrower,
      marketId: current.marketId,
      debtUsd: patch.debtUsd === undefined ? current.debtUsd : sanitizeDebtUsd(patch.debtUsd),
      profitUsd: patch.profitUsd === undefined ? current.profitUsd : sanitizeProfitUsd(patch.profitUsd),
      updatedAt: new Date().toISOString(),
    };

    if (patch.profitUsd != null && isPlaceholderProfit(patch.profitUsd)) {
      next.profitUsd = null;
      next.status = "sim_failed";
      next.simError = next.simError ?? "placeholder profit rejected";
    }

    this.armedQueue.set(key, next);
    this.logEntry(next);
    return next;
  }

  private logEntry(entry: ArmedQueueEntry): void {
    const hf =
      entry.healthFactor === null || entry.healthFactor === undefined
        ? "—"
        : entry.healthFactor.toFixed(4);
    const debt = formatUsd(entry.debtUsd);
    const profit = formatUsd(entry.profitUsd);
    const pair = entry.pair ? ` ${entry.pair}` : "";
    const err = entry.simError ? ` err=${entry.simError}` : "";
    console.log(
      `${this.tag}[Scribe] ${entry.status} ${entry.borrower.slice(0, 10)}…${pair} HF=${hf} debt=${debt} profit=${profit}${err}`,
    );
  }
}
