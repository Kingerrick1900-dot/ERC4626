// --- PHASE3_STRIKE_ENROLL ---
// p3 exec uses existing imports if present
const _execP3 = execFileAsync;

async function p3Sql(sql: string): Promise<string> {
  const { stdout } = await _execP3("sqlite3", ["/opt/kesov-kingdom/kingdom.db", sql], { timeout: 20000 });
  return (stdout || "").trim();
}

async function p3Eth(addr: string): Promise<string> {
  try {
    const rpc = process.env.RSS_RPC_URL || process.env.EVM_PROVIDER_BASE || "https://base.publicnode.com";
    const client = createPublicClient({ chain: base, transport: fallback([http(rpc), http("https://base.publicnode.com")]) });
    const bal = await client.getBalance({ address: addr as `0x${string}` });
    return formatUnits(bal, 18);
  } catch (e) {
    return "err:" + String(e);
  }
}

export const strikeStatusAction: Action = {
  name: "STRIKE_STATUS",
  similes: ["HOSTILE_STATUS", "LIQUIDATION_STATUS", "FLEET_STRIKE"],
  description: "Hostile strike desk: gas, queue, near-liq targets, recent execution outcomes.",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return t.includes("strike status") || t.includes("hostile status") || t.trim() === "strike";
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    try {
      const fleet = "0xcbD8Ac7e09aB6944A0Ae8f2DecaBbDbC8F3EC564";
      const eth = await p3Eth(fleet);
      const q = await p3Sql("SELECT status||'|'||count(*)||'|'||printf('%.0f',COALESCE(sum(debt_value_usd),0)) FROM liquidation_queue GROUP BY status ORDER BY count(*) DESC;");
      const near = await p3Sql("SELECT substr(user,1,12)||' HF='||printf('%.4f',health_factor)||' $'||printf('%.0f',debt_value_usd)||' '||protocol FROM potential_targets WHERE health_factor>0.995 AND health_factor<1.015 AND debt_value_usd>2000 ORDER BY health_factor ASC, debt_value_usd DESC LIMIT 8;");
      const exec = await p3Sql("SELECT status||'|'||count(*) FROM executions GROUP BY status;");
      const last = await p3Sql("SELECT id||' '||status||' '||substr(user,1,10)||' $'||printf('%.0f',COALESCE(net_profit_usd,0))||' '||datetime(executed_at,'unixepoch') FROM executions ORDER BY id DESC LIMIT 5;");
      const lines = [
        "**Strike Desk (Hostile)**",
        "Fleet gas: **" + eth + " ETH** (`" + fleet + "`)",
        "LIVE morpho flash fires when on-chain HF < 1 (backrun holds above).",
        "Queue (status|count|debt$):",
        q || "(empty)",
        "Near targets:",
        near || "(none)",
        "Executions by status:",
        exec || "(none)",
        "Recent:",
        last || "(none)",
        "Cmds: `strike status` · `strike clear` · `fire 0x…` · `find-fire`",
      ];
      await reply(callback, message, lines.join("\n"));
    } catch (err) {
      await reply(callback, message, "Strike status error: " + String(err));
    }
  },
  examples: [],
};

export const strikeClearAction: Action = {
  name: "STRIKE_CLEAR",
  similes: ["CLEAR_QUEUE", "RESET_EXECUTING"],
  description: "Reset stuck executing liquidation_queue rows back to pending.",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return t.includes("strike clear") || t.includes("clear queue") || t.includes("reset executing");
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    try {
      const n = await p3Sql("UPDATE liquidation_queue SET status='pending', claimed_by=NULL, claimed_at=NULL, executing_at=NULL, failure_reason='telegram_strike_clear' WHERE status='executing'; SELECT changes();");
      const q = await p3Sql("SELECT status||'|'||count(*) FROM liquidation_queue GROUP BY status;");
      await reply(callback, message, "Cleared stuck executing → pending: **" + n + "**\n" + q);
    } catch (err) {
      await reply(callback, message, "Strike clear failed: " + String(err));
    }
  },
  examples: [],
};

export const rescueInvoiceAction: Action = {
  name: "VIP_RESCUE_INVOICE",
  similes: ["RESCUE_INVOICE", "VIP_FEES"],
  description: "Show accrued VIP rescue fees (ledger) awaiting collection.",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return t.includes("rescue invoice") || t.includes("vip invoice") || t.includes("vip fees") || t.includes("rescue fees");
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    try {
      const rows = await p3Sql("SELECT substr(c.user,1,12)||' '||COALESCE(c.label,'')||' fee='||printf('%.2f',COALESCE(SUM(e.fee_usd),0))||' events='||count(*) FROM rescue_events e JOIN rescue_clients c ON c.id=e.client_id WHERE e.event_type='fee_accrued' GROUP BY e.client_id;");
      const total = await p3Sql("SELECT printf('%.2f', COALESCE(SUM(fee_usd),0)) FROM rescue_events WHERE event_type='fee_accrued';");
      const active = await p3Sql("SELECT count(*) FROM rescue_clients WHERE status='active';");
      await reply(
        callback,
        message,
        "**VIP Fee Ledger** (accrual — collect off-chain/invoice until settle path lives)\nActive clients: **" +
          active +
          "**\nTotal accrued: **$" +
          total +
          "**\n" +
          (rows || "(no fee_accrued yet)") +
          "\nEnroll more: `rescue enroll 0x… Label` · Pitch: `rescue status`"
      );
    } catch (err) {
      await reply(callback, message, "Invoice error: " + String(err));
    }
  },
  examples: [],
};

export const rescuePitchAction: Action = {
  name: "VIP_RESCUE_PITCH",
  similes: ["RESCUE_PITCH", "PITCH_WHALES"],
  description: "List high-debt near-liq whales to pitch for VIP rescue enrollment.",
  validate: async (_rt, message) => {
    const t = (message.content.text || "").toLowerCase();
    return t.includes("rescue pitch") || t.includes("pitch whales") || t.includes("vip pitch");
  },
  handler: async (_rt, message, _s, _o, callback) => {
    if (!isAuthorized(message)) return deny(callback, message);
    try {
      const pitch = await p3Sql(
        "SELECT user||' HF='||printf('%.4f',health_factor)||' debt=$'||printf('%.0f',debt_value_usd)||' '||protocol||' fee@7%~$'||printf('%.0f',debt_value_usd*0.07) " +
          "FROM potential_targets WHERE health_factor>1.0 AND health_factor<1.08 AND debt_value_usd>5000 " +
          "AND lower(user) NOT IN (SELECT lower(user) FROM rescue_clients WHERE status='active') " +
          "ORDER BY debt_value_usd DESC LIMIT 12;"
      );
      await reply(
        callback,
        message,
        "**VIP Pitch List** (not enrolled)\n" +
          (pitch || "(none)") +
          "\nEnroll: `rescue enroll 0x… Label`"
      );
    } catch (err) {
      await reply(callback, message, "Pitch error: " + String(err));
    }
  },
  examples: [],
};


