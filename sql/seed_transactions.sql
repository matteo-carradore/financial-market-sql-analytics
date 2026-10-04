-- Sample transactions. Execution prices are NOT typed by hand:
-- each order is executed at the real closing price of the first trading day on or after the wanted date.
WITH t (ticker, wanted_date, side, qty, fees) AS (VALUES
    ('MC.PA', '2025-01-15', 'BUY',  5, 1.50),
    ('MC.PA', '2025-06-16', 'BUY',  3, 1.50),
    ('MC.PA', '2026-02-10', 'SELL', 2, 1.50),
    ('SPY',   '2025-02-03', 'BUY', 10, 0.00),
    ('SPY',   '2025-07-01', 'BUY', 10, 0.00),
    ('SPY',   '2026-03-02', 'SELL', 5, 0.00)
),
resolved AS (
    SELECT a.asset_id, t.side, t.qty, t.fees,
           (SELECT MIN(p.trade_date) FROM daily_prices p
             WHERE p.asset_id = a.asset_id AND p.trade_date >= t.wanted_date) AS trade_date
    FROM t JOIN assets a USING (ticker)
)
INSERT INTO transactions (asset_id, trade_date, side, quantity, execution_price, fees)
SELECT r.asset_id, r.trade_date, r.side, r.qty, p.close_price, r.fees
FROM resolved r
JOIN daily_prices p ON p.asset_id = r.asset_id AND p.trade_date = r.trade_date
ORDER BY r.trade_date;
