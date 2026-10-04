-- Market analytics views. All of them use adjusted_close, for consistency.
DROP VIEW IF EXISTS v_risk_summary;
DROP VIEW IF EXISTS v_correlation;
DROP VIEW IF EXISTS v_drawdown;
DROP VIEW IF EXISTS v_returns;

-- 1. Returns, intraday range, moving averages (only valid once the window is full)
CREATE VIEW v_returns AS
WITH base AS (
    SELECT a.asset_id, a.ticker, p.trade_date, p.adjusted_close,
           LAG(p.adjusted_close) OVER w AS prev_close,
           (p.high_price - p.low_price) / p.open_price AS intraday_range,
           ROW_NUMBER() OVER w AS rn,
           AVG(p.adjusted_close) OVER (w ROWS BETWEEN 19 PRECEDING AND CURRENT ROW) AS sma20_raw,
           AVG(p.adjusted_close) OVER (w ROWS BETWEEN 49 PRECEDING AND CURRENT ROW) AS sma50_raw
    FROM daily_prices p JOIN assets a USING (asset_id)
    WINDOW w AS (PARTITION BY p.asset_id ORDER BY p.trade_date)
)
SELECT asset_id, ticker, trade_date, adjusted_close,
       adjusted_close / prev_close - 1 AS daily_return,
       intraday_range,
       CASE WHEN rn >= 20 THEN sma20_raw END AS sma_20,
       CASE WHEN rn >= 50 THEN sma50_raw END AS sma_50
FROM base;

-- 2. High-water mark and current drawdown (as a fraction, e.g. -0.12 = -12 %)
CREATE VIEW v_drawdown AS
WITH peaks AS (
    SELECT a.asset_id, a.ticker, p.trade_date, p.adjusted_close,
           MAX(p.adjusted_close) OVER (
               PARTITION BY p.asset_id ORDER BY p.trade_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS peak_price
    FROM daily_prices p JOIN assets a USING (asset_id)
)
SELECT *, adjusted_close / peak_price - 1 AS drawdown FROM peaks;

-- 3. Risk summary: CAGR, annualised volatility, Sharpe, max drawdown, Calmar
CREATE VIEW v_risk_summary AS
WITH ret AS (
    SELECT asset_id, ticker,
           COUNT(daily_return)                AS n,
           AVG(daily_return)                  AS mu,
           SUM(daily_return * daily_return)   AS sumsq
    FROM v_returns WHERE daily_return IS NOT NULL GROUP BY asset_id, ticker
),
bounds AS (
    SELECT asset_id,
           MIN(trade_date) AS first_date, MAX(trade_date) AS last_date,
           (SELECT adjusted_close FROM daily_prices x WHERE x.asset_id = p.asset_id ORDER BY trade_date ASC  LIMIT 1) AS first_px,
           (SELECT adjusted_close FROM daily_prices x WHERE x.asset_id = p.asset_id ORDER BY trade_date DESC LIMIT 1) AS last_px
    FROM daily_prices p GROUP BY asset_id
),
mdd AS (SELECT asset_id, MIN(drawdown) AS max_drawdown FROM v_drawdown GROUP BY asset_id),
k AS (
    SELECT (SELECT value FROM params WHERE name = 'trading_days')   AS td,
           (SELECT value FROM params WHERE name = 'risk_free_rate') AS rf
),
stats AS (
    SELECT r.ticker, a.data_source, b.first_date, b.last_date, r.n AS n_returns,
           r.mu, SQRT((r.sumsq - r.n * r.mu * r.mu) / (r.n - 1)) AS sd,
           POWER(b.last_px / b.first_px, k.td / r.n) - 1 AS cagr,
           m.max_drawdown, k.td, k.rf
    FROM ret r JOIN bounds b USING (asset_id) JOIN mdd m USING (asset_id)
         JOIN assets a USING (asset_id), k
)
SELECT ticker, data_source, first_date, last_date, n_returns,
       ROUND(cagr * 100, 2)                              AS cagr_pct,
       ROUND(sd * SQRT(td) * 100, 2)                     AS ann_vol_pct,
       ROUND((mu * td - rf) / (sd * SQRT(td)), 2)        AS sharpe,
       ROUND(max_drawdown * 100, 2)                      AS max_drawdown_pct,
       ROUND(cagr / -max_drawdown, 2)                    AS calmar
FROM stats;

-- 4. Correlation and beta for each pair of assets (on common dates only)
CREATE VIEW v_correlation AS
WITH pairs AS (
    SELECT a.ticker AS t1, b.ticker AS t2, a.daily_return AS x, b.daily_return AS y
    FROM v_returns a JOIN v_returns b
      ON a.trade_date = b.trade_date AND a.asset_id < b.asset_id
    WHERE a.daily_return IS NOT NULL AND b.daily_return IS NOT NULL
),
agg AS (
    SELECT t1, t2, COUNT(*) AS n, SUM(x) sx, SUM(y) sy, SUM(x*y) sxy, SUM(x*x) sxx, SUM(y*y) syy
    FROM pairs GROUP BY t1, t2
)
SELECT t1, t2, n AS common_days,
       ROUND((n*sxy - sx*sy) / SQRT((n*sxx - sx*sx) * (n*syy - sy*sy)), 3) AS correlation,
       ROUND((n*sxy - sx*sy) / (n*syy - sy*sy), 3)                          AS beta_t1_vs_t2
FROM agg;
