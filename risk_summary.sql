WITH daily_metrics AS (
    SELECT 
        asset_id,
        trade_date,
        close_price,
        LAG(close_price, 1) OVER (PARTITION BY asset_id ORDER BY trade_date) AS prev_close,
        MAX(close_price) OVER (
            PARTITION BY asset_id 
            ORDER BY trade_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS peak_price
    FROM daily_prices
),
asset_drawdowns AS (
    SELECT 
        asset_id,
        trade_date,
        close_price,
        ROUND(((close_price - prev_close) / prev_close) * 100, 2) AS daily_return_pct,
        ROUND(((close_price - peak_price) / peak_price) * 100, 2) AS drawdown_pct
    FROM daily_metrics
)
SELECT 
    a.ticker,
    COUNT(d.trade_date) AS trading_days,
    ROUND(AVG(d.daily_return_pct), 3) AS avg_daily_return_pct,
    MIN(d.drawdown_pct) AS max_drawdown_pct
FROM asset_drawdowns d
JOIN assets a ON d.asset_id = a.asset_id
GROUP BY a.ticker;