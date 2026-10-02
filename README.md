# Financial Market Data & Risk Analysis in SQL

A personal project building a relational database in SQLite to store multi-asset daily market data (450+ trading sessions across equities and index ETFs) and compute key quantitative indicators directly in SQL.

I built this project to apply relational modeling and time-series concepts using window functions and CTEs.

---

## Database Design

The schema (`schema.sql`) models price history in 3NF:

* **`assets`**: reference table for instruments (ticker, name, asset class, base currency).
* **`daily_prices`**: daily OHLC quotes, adjusted close, and volume linked via foreign key with a composite unique constraint on `(asset_id, trade_date)`.

---

## Key SQL Implementations

### 1. Rolling Momentum & Moving Averages (`analysis.sql`)
* Uses `LAG()` over partition by asset to retrieve the previous close and calculate daily returns.
* Computes rolling 3-day simple moving average (`SMA`) using `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`.
* Tracks intraday price spread relative to open.

### 2. High-Water Mark & Drawdown Tracking (`drawdown.sql`)
* Measures drawdown by comparing daily close against the historical peak price using `MAX(close_price) OVER (PARTITION BY asset_id ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.

### 3. Aggregate Risk Profile (`risk_summary.sql`)
* Aggregates multi-year performance across assets to compute total trading days, average daily returns, and historical Maximum Drawdown (`MDD`).

---

## Quickstart

Run with SQLite locally:

```bash
# 1. Initialize schema and generate dataset (450+ sessions)
sqlite3 market_data.db < schema.sql
python3 generate_data.py
sqlite3 market_data.db < seed_full.sql

# 2. Run analysis and risk queries
sqlite3 -column -header market_data.db < analysis.sql
sqlite3 -column -header market_data.db < drawdown.sql
sqlite3 -column -header market_data.db < risk_summary.sql
```