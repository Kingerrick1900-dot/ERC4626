/** Market adapters — Phase 1 stubs (stateless interface; no signing) */

/**
 * @typedef {Object} AdapterBalances
 * @property {string} asset
 * @property {string} amount
 * @property {'external-priced'|'internal-synthetic'} tag
 */

/**
 * @typedef {Object} MarketAdapter
 * @property {string} id
 * @property {(params: object) => Promise<object>} deposit
 * @property {(params: object) => Promise<object>} withdraw
 * @property {(params: object) => Promise<object>} borrow
 * @property {(params: object) => Promise<object>} repay
 * @property {(params: object) => Promise<AdapterBalances[]>} getBalances
 */

function notWired(name) {
  return async () => {
    throw new Error(`${name}: execution not wired in Phase 1 (Intent Queue Phase 3)`);
  };
}

/** @type {MarketAdapter} */
export const morphoAdapter = {
  id: 'morpho',
  deposit: notWired('morpho.deposit'),
  withdraw: notWired('morpho.withdraw'),
  borrow: notWired('morpho.borrow'),
  repay: notWired('morpho.repay'),
  async getBalances() {
    return [];
  },
};

/** @type {MarketAdapter} */
export const aaveAdapter = {
  id: 'aave',
  deposit: notWired('aave.deposit'),
  withdraw: notWired('aave.withdraw'),
  borrow: notWired('aave.borrow'),
  repay: notWired('aave.repay'),
  async getBalances() {
    return [];
  },
};

/** @type {MarketAdapter} */
export const internalCdpAdapter = {
  id: 'internal-cdp',
  deposit: notWired('cdp.deposit'),
  withdraw: notWired('cdp.withdraw'),
  borrow: notWired('cdp.borrow'),
  repay: notWired('cdp.repay'),
  async getBalances() {
    return [];
  },
};

export const adapters = {
  morpho: morphoAdapter,
  aave: aaveAdapter,
  'internal-cdp': internalCdpAdapter,
};
