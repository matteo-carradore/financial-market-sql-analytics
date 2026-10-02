# Financial Market Data, Risk & Portfolio Analytics in SQL

A financial engineering project building a 3NF relational database in SQLite. It ingests 450+ daily trading sessions across equities and index ETFs, applies performance & downside risk metrics directly via SQL window functions, and models a transaction-based portfolio tracker with real-time unrealized PnL and PRU (cost basis) calculations.

---

## Architecture & Schema Design

The schema (`schema.sql`) implements Third Normal Form (3NF) relational design:

* **`assets`**: Instrument static data (ticker, name, asset class, base currency).
* **`daily_prices`**: Daily OHLCV quotes with a composite unique constraint on `(asset_id, trade_date)`.
* **`transactions`**: Portfolio trade blotter (trade date, execution side, quantity, price, fees).

### Query Optimization (`indexes.sql`)
* B-Tree composite index `(asset_id, trade_date)` to avoid full table scans during chronological ordering and partition grouping.
* Covering index on `assets(ticker)` for fast joins.

---

## Analytical Modules

### 1. Momentum & Rolling Indicators (`analysis.sql`)
* Evaluates intraday spread and daily percentage returns using `LAG()`.
* Computes rolling 3-day simple moving averages (`SMA`) using `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`.

### 2. High-Water Mark & Downside Risk (`drawdown.sql` & `risk_summary.sql`)
* Computes dynamic peak prices using cumulative `MAX() OVER (...)`.
* Evaluates running drawdown and historical Maximum Drawdown (`MDD`) across multi-year sessions.

### 3. Portfolio Tracking & Cost Basis (`portfolio.sql`)
* Aggregates trade history to compute volume-weighted average price (PRU / Cost Basis) including fees.
* Joins the latest available market quotes to evaluate position market values, unrealized profit & loss, and percentage performance.

---

## Quickstart

```bash
# 1. Initialize schema, indexes, and market data (450+ sessions)
sqlite3 market_data.db < schema.sql
sqlite3 market_data.db < indexes.sql
python3 generate_data.py
sqlite3 market_data.db < seed_full.sql

# 2. Run risk and portfolio analytics
sqlite3 -column -header market_data.db < risk_summary.sql
sqlite3 -column -header market_data.db < portfolio.sql
```