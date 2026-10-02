WITH price_metrics AS (
    SELECT 
        a.ticker,
        p.trade_date,
        p.adjusted_close,
        LAG(p.adjusted_close, 1) OVER (
            PARTITION BY p.asset_id 
            ORDER BY p.trade_date
        ) AS prev_close,
        ROUND(((p.high_price - p.low_price) / p.open_price) * 100, 2) AS intraday_volatility_pct
    FROM daily_prices p
    JOIN assets a ON p.asset_id = a.asset_id
)
SELECT 
    ticker,
    trade_date,
    adjusted_close,
    ROUND(((adjusted_close - prev_close) / prev_close) * 100, 2) AS daily_return_pct,
    ROUND(AVG(adjusted_close) OVER (
        PARTITION BY ticker 
        ORDER BY trade_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS sma_3d,
    intraday_volatility_pct
FROM price_metrics;