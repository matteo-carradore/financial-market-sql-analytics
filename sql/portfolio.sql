-- Portfolio tracking with the weighted average cost method (PRU), SELL included.
-- Buy fees are added to the cost basis; sell fees reduce the sale proceeds.
DROP VIEW IF EXISTS v_positions;
DROP VIEW IF EXISTS v_realized_pnl;
DROP VIEW IF EXISTS v_position_ledger;

CREATE VIEW v_position_ledger AS
WITH RECURSIVE ordered AS (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY asset_id ORDER BY trade_date, transaction_id) AS rn
    FROM transactions t
),
ledger (asset_id, rn, trade_date, side, shares, cost, realized_pnl) AS (
    SELECT asset_id, rn, trade_date, side,
           CASE side WHEN 'BUY' THEN quantity ELSE -quantity END,
           CASE side WHEN 'BUY' THEN quantity * execution_price + fees ELSE 0 END,
           0.0
    FROM ordered WHERE rn = 1
    UNION ALL
    SELECT o.asset_id, o.rn, o.trade_date, o.side,
           CASE o.side WHEN 'BUY' THEN l.shares + o.quantity ELSE l.shares - o.quantity END,
           CASE o.side WHEN 'BUY' THEN l.cost + o.quantity * o.execution_price + o.fees
                       ELSE l.cost * (1 - o.quantity / l.shares) END,
           CASE o.side WHEN 'BUY' THEN 0.0
                       ELSE o.quantity * o.execution_price - o.fees - o.quantity * (l.cost / l.shares) END
    FROM ledger l JOIN ordered o ON o.asset_id = l.asset_id AND o.rn = l.rn + 1
)
SELECT * FROM ledger;

CREATE VIEW v_realized_pnl AS
SELECT asset_id, ROUND(SUM(realized_pnl), 2) AS realized_pnl
FROM v_position_ledger GROUP BY asset_id;

-- Open positions + unrealized PnL. No sum across currencies: one row per asset, in its own currency.
CREATE VIEW v_positions AS
WITH last_state AS (
    SELECT asset_id, shares, cost FROM v_position_ledger
    WHERE (asset_id, rn) IN (SELECT asset_id, MAX(rn) FROM v_position_ledger GROUP BY asset_id)
),
last_px AS (
    SELECT asset_id, close_price AS last_price, trade_date AS as_of_date
    FROM daily_prices
    WHERE (asset_id, trade_date) IN (SELECT asset_id, MAX(trade_date) FROM daily_prices GROUP BY asset_id)
)
SELECT a.ticker, a.base_currency AS currency, s.shares,
       ROUND(s.cost / s.shares, 4)                              AS pru,
       p.last_price, p.as_of_date,
       ROUND(s.shares * p.last_price, 2)                        AS market_value,
       ROUND(s.cost, 2)                                         AS cost_basis,
       ROUND(s.shares * p.last_price - s.cost, 2)               AS unrealized_pnl,
       ROUND((s.shares * p.last_price / s.cost - 1) * 100, 2)   AS return_pct,
       COALESCE(r.realized_pnl, 0)                              AS realized_pnl
FROM last_state s
JOIN assets a USING (asset_id)
JOIN last_px p USING (asset_id)
LEFT JOIN v_realized_pnl r USING (asset_id)
WHERE s.shares > 1e-9;
