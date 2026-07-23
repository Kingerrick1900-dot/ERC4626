/** Intent Queue — in-memory + optional Postgres later. Schema + 3 retries → dead-letter. */

import { randomUUID } from 'crypto';
import { INTENT_ACTIONS, MAX_INTENT_RETRIES } from '../types.js';
import { evaluateIntent } from '../risk/controller.js';

/**
 * @typedef {import('../types.js').Intent} Intent
 */

export class IntentQueue {
  constructor() {
    /** @type {Map<string, Intent>} */
    this.items = new Map();
    /** @type {Intent[]} */
    this.deadLetter = [];
  }

  /**
   * @param {{ source: string, action: string, params?: Record<string, unknown> }} input
   * @returns {Intent}
   */
  enqueue(input) {
    if (!INTENT_ACTIONS.includes(input.action)) {
      throw new Error(`invalid action: ${input.action}`);
    }
    /** @type {Intent} */
    const intent = {
      id: randomUUID(),
      source: input.source || 'unknown',
      action: input.action,
      params: input.params || {},
      status: 'pending',
      riskControllerNote: null,
      attempts: 0,
      createdAt: new Date().toISOString(),
    };
    this.items.set(intent.id, intent);
    return intent;
  }

  get(id) {
    return this.items.get(id) || null;
  }

  list(status) {
    const all = [...this.items.values()];
    return status ? all.filter((i) => i.status === status) : all;
  }

  /**
   * Run Risk Controller; on reject → rejected; on approve → approved.
   * @param {string} id
   * @param {import('../risk/controller.js').RiskContext} ctx
   * @param {object} [policy]
   */
  riskGate(id, ctx = {}, policy) {
    const intent = this.items.get(id);
    if (!intent) throw new Error('intent not found');
    if (intent.status !== 'pending' && intent.status !== 'approved') {
      throw new Error(`cannot riskGate status=${intent.status}`);
    }
    const decision = evaluateIntent(intent, ctx, policy);
    intent.riskControllerNote = decision.reason;
    intent.updatedAt = new Date().toISOString();
    intent.status = decision.approved ? 'approved' : 'rejected';
    return { intent, decision };
  }

  /**
   * Mark execution attempt. After MAX_INTENT_RETRIES failures → dead.
   * @param {string} id
   * @param {{ ok: boolean, error?: string }} result
   */
  recordAttempt(id, result) {
    const intent = this.items.get(id);
    if (!intent) throw new Error('intent not found');
    intent.attempts = (intent.attempts || 0) + 1;
    intent.updatedAt = new Date().toISOString();
    if (result.ok) {
      intent.status = 'done';
      return intent;
    }
    intent.riskControllerNote = result.error || intent.riskControllerNote;
    if (intent.attempts >= MAX_INTENT_RETRIES) {
      intent.status = 'dead';
      this.deadLetter.push({ ...intent });
      this.items.delete(id);
    } else {
      intent.status = 'approved'; // retryable
    }
    return intent;
  }

  /** Postgres DDL for VPS (Phase 3 wiring) */
  static postgresDdl() {
    return `
CREATE TABLE IF NOT EXISTS intents (
  id UUID PRIMARY KEY,
  source TEXT NOT NULL,
  action TEXT NOT NULL,
  params JSONB NOT NULL DEFAULT '{}',
  status TEXT NOT NULL,
  risk_controller_note TEXT,
  attempts INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS intents_dead (
  LIKE intents INCLUDING ALL
);
`;
  }
}
