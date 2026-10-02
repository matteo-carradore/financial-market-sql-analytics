CREATE TABLE IF NOT EXISTS transactions (
    transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL,
    trade_date DATE NOT NULL,
    side TEXT CHECK(side IN ('BUY', 'SELL')),
    quantity REAL NOT NULL,
    execution_price REAL NOT NULL,
    fees REAL DEFAULT 0.0,
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id)
);

INSERT INTO transactions (asset_id, trade_date, side, quantity, execution_price, fees) VALUES
(1, '2025-01-15', 'BUY', 5, 685.00, 1.50),
(1, '2025-06-16', 'BUY', 3, 710.20, 1.50),
(2, '2025-02-03', 'BUY', 10, 495.50, 0.00),
(2, '2025-07-01', 'BUY', 10, 520.10, 0.00);

WITH position_summary AS (
    SELECT 
        asset_id,
        SUM(quantity) AS total_shares,
        ROUND(SUM(quantity * execution_price) / SUM(quantity), 4) AS avg_buy_price,
        ROUND(SUM(quantity * execution_price + fees), 2) AS total_cost_basis
    FROM transactions
    WHERE side = 'BUY'
    GROUP BY asset_id
),
latest_market_prices AS (
    SELECT 
        asset_id,
        close_price AS latest_price,
        trade_date AS as_of_date
    FROM daily_prices
    WHERE (asset_id, trade_date) IN (
        SELECT asset_id, MAX(trade_date) 
        FROM daily_prices 
        GROUP BY asset_id
    )
)
SELECT 
    a.ticker,
    a.name,
    p.total_shares,
    p.avg_buy_price AS pru,
    m.latest_price,
    ROUND(p.total_shares * m.latest_price, 2) AS market_value,
    ROUND((p.total_shares * m.latest_price) - p.total_cost_basis, 2) AS unrealized_pnl,
    ROUND((((p.total_shares * m.latest_price) - p.total_cost_basis) / p.total_cost_basis) * 100, 2) AS return_pct
FROM position_summary p
JOIN assets a ON p.asset_id = a.asset_id
JOIN latest_market_prices m ON p.asset_id = m.asset_id;