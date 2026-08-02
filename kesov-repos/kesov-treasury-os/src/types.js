/** Shared types — KESOV Treasury OS */

/** @typedef {'external-priced' | 'internal-synthetic'} PriceTag */

/**
 * @typedef {Object} PositionLine
 * @property {string} id
 * @property {string} venue
 * @property {string} asset
 * @property {string} amount
 * @property {number} decimals
 * @property {PriceTag} tag
 * @property {number|null} usdMark
 * @property {string} [note]
 */

/**
 * @typedef {Object} DebtLine
 * @property {string} id
 * @property {string} venue
 * @property {string} asset
 * @property {string} amount
 * @property {number} decimals
 * @property {PriceTag} tag
 * @property {number|null} usdMark
 * @property {number|null} hfRaw
 */

/**
 * @typedef {Object} TreasurySnapshot
 * @property {string} asOf
 * @property {PositionLine[]} assets
 * @property {DebtLine[]} debts
 * @property {object} totals
 * @property {object} oracle
 * @property {object} flags
 */

/**
 * Intent Queue schema (Phase 3+)
 * @typedef {Object} Intent
 * @property {string} id
 * @property {string} source
 * @property {'deposit'|'withdraw'|'borrow'|'repay'|'allocate'|'deallocate'|'harvest'|'collateral_topup'} action
 * @property {Record<string, unknown>} params
 * @property {'pending'|'approved'|'rejected'|'executing'|'done'|'dead'} status
 * @property {string|null} riskControllerNote
 * @property {number} attempts
 * @property {string} createdAt
 * @property {string} [updatedAt]
 */

export const INTENT_ACTIONS = [
  'deposit',
  'withdraw',
  'borrow',
  'repay',
  'allocate',
  'deallocate',
  'harvest',
  'collateral_topup',
];

export const MAX_INTENT_RETRIES = 3;
