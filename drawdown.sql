WITH running_peaks AS (
    SELECT 
        a.ticker,
        p.trade_date,
        p.adjusted_close,
        MAX(p.adjusted_close) OVER (
            PARTITION BY p.asset_id 
            ORDER BY p.trade_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS peak_price
    FROM daily_prices p
    JOIN assets a ON p.asset_id = a.asset_id
)
SELECT 
    ticker,
    trade_date,
    adjusted_close,
    peak_price,
    ROUND(((adjusted_close - peak_price) / peak_price) * 100, 2) AS drawdown_pct
FROM running_peaks;