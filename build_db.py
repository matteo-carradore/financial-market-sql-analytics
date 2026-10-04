#!/usr/bin/env python3
"""Builds market_data.db from scratch (safe to re-run).

Price source, per asset:
  1. data/prices/<TICKER>.csv  (Yahoo Finance format)  -> data_source = YAHOO_CSV
  2. otherwise, simulated prices (only with --simulate) -> data_source = SIMULATED
With no CSV and no --simulate the build stops: fake data is never generated silently.
"""
import argparse
import csv
import random
import sqlite3
import sys
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).parent
ASSETS = [  # ticker, name, asset class, currency
    ("MC.PA", "LVMH Moët Hennessy", "Equities", "EUR"),
    ("SPY", "SPDR S&P 500 ETF Trust", "Equities", "USD"),
]
# start price, daily drift, daily vol, loading on the common market factor
SIM_PARAMS = {"MC.PA": (680.0, 0.0002, 0.015, 0.6), "SPY": (490.0, 0.0004, 0.010, 1.0)}


def read_yahoo_csv(path: Path):
    """Reads a Yahoo CSV (Date,Open,High,Low,Close,Adj Close,Volume) and checks it."""
    text = path.read_text(encoding="utf-8-sig")
    if text.lstrip().lower().startswith(("<!doctype", "<html")):
        sys.exit(f"{path.name} is an HTML page, not a CSV. Download it again (see fetch_prices.py).")
    rows = []
    for r in csv.DictReader(text.splitlines()):
        try:
            rows.append((r["Date"][:10], float(r["Open"]), float(r["High"]), float(r["Low"]),
                         float(r["Close"]), float(r["Adj Close"]), int(float(r["Volume"] or 0))))
        except (KeyError, ValueError):
            continue  # skip Yahoo's 'null' rows (market holidays)
    if len(rows) < 30:
        sys.exit(f"{path.name}: only {len(rows)} valid rows, the file looks wrong.")
    return sorted(rows)


def simulate(start: date, end: date, seed: int):
    """Random walk with a common market factor (so correlation/beta are not trivial)."""
    rng = random.Random(seed)
    days = [start + timedelta(d) for d in range((end - start).days + 1)
            if (start + timedelta(d)).weekday() < 5]
    market = [rng.gauss(0, 0.010) for _ in days]
    out = {}
    for ticker, (px, drift, vol, load) in SIM_PARAMS.items():
        rows = []
        for d, m in zip(days, market):
            idio = rng.gauss(0, vol * (1 - 0.5 * load) ** 0.5)
            close = round(px * (1 + drift + load * m + idio), 2)
            opn = round(px * (1 + rng.uniform(-0.003, 0.003)), 2)
            high = round(max(opn, close) * (1 + rng.uniform(0.001, 0.008)), 2)
            low = round(min(opn, close) * (1 - rng.uniform(0.001, 0.008)), 2)
            rows.append((d.isoformat(), opn, high, low, close, close, max(int(rng.gauss(1e6, 1e5)), 1)))
            px = close
        out[ticker] = rows
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "market_data.db"))
    ap.add_argument("--simulate", action="store_true", help="simulate assets that have no CSV")
    ap.add_argument("--start", default="2025-01-01")
    ap.add_argument("--end", default="2026-09-30")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    sim = None
    prices = {}
    for ticker, *_ in ASSETS:
        csv_path = ROOT / "data" / "prices" / f"{ticker}.csv"
        if csv_path.exists():
            prices[ticker] = ("YAHOO_CSV", read_yahoo_csv(csv_path))
        elif args.simulate:
            sim = sim or simulate(date.fromisoformat(args.start), date.fromisoformat(args.end), args.seed)
            prices[ticker] = ("SIMULATED", sim[ticker])
        else:
            sys.exit(f"No data for {ticker}: add data/prices/{ticker}.csv or run with --simulate.")

    Path(args.db).unlink(missing_ok=True)
    con = sqlite3.connect(args.db)
    con.execute("PRAGMA foreign_keys = ON")
    con.executescript((ROOT / "sql" / "schema.sql").read_text())
    with con:
        for ticker, name, cls, ccy in ASSETS:
            source, rows = prices[ticker]
            cur = con.execute("INSERT INTO assets (ticker,name,asset_class,base_currency,data_source) VALUES (?,?,?,?,?)",
                              (ticker, name, cls, ccy, source))
            con.executemany(
                "INSERT INTO daily_prices (asset_id,trade_date,open_price,high_price,low_price,close_price,adjusted_close,volume)"
                " VALUES (?,?,?,?,?,?,?,?)", [(cur.lastrowid, *r) for r in rows])
    for f in ("views.sql", "portfolio.sql", "seed_transactions.sql"):
        con.executescript((ROOT / "sql" / f).read_text())
    for t, src, n in con.execute("SELECT ticker,data_source,COUNT(*) FROM assets JOIN daily_prices USING(asset_id) GROUP BY 1,2"):
        print(f"{t:6} {n:4} sessions  [{src}]")
    con.close()


if __name__ == "__main__":
    main()
