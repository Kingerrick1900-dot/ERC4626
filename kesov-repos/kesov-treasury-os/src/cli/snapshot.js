/** Phase 1 CLI — Accounting + Oracle snapshot */

import { buildSnapshot } from '../accounting/layer.js';

const snap = await buildSnapshot();
console.log(JSON.stringify(snap, null, 2));
