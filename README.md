# Financial Market Data & Risk Analysis in SQL

A personal project building a relational database in SQLite to store daily market data and compute key quantitative indicators directly in SQL. 

I built this project to apply database design concepts alongside market concepts (momentum, moving averages, and drawdown risk) using window functions.

---

## Database Design

The schema (`schema.sql`) models price history in 3NF:

* **`assets`**: reference table for tracked instruments (ticker, name, asset class, currency).
* **`daily_prices`**: historical quotes (OHLC, adjusted close, daily volume) linked via foreign key with a composite unique constraint on `(asset_id, trade_date)`.

---

## Queries & Implemented Metrics

### 1. Daily Returns & 3-Day Moving Average (`analysis.sql`)
Calculates the daily percentage change and short-term trend:
* Uses `LAG()` over partition by asset to retrieve the previous close.
* Computes rolling 3-day simple moving average (`SMA`) using `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`.
* Tracks intraday price spread relative to open.

### 2. High-Water Mark & Drawdown (`drawdown.sql`)
Measures downside risk by calculating the distance between the current close and the asset's historical peak:
* Uses cumulative windowing `MAX(adjusted_close) OVER (PARTITION BY asset_id ORDER BY trade_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.
* Computes current drawdown percentage.

---

## Quickstart

Run with SQLite locally:

```bash
# Set up database and load sample data
sqlite3 market_data.db < schema.sql
sqlite3 market_data.db < seed.sql

# Run analysis queries
sqlite3 -column -header market_data.db < analysis.sql
sqlite3 -column -header market_data.db < drawdown.sql
```