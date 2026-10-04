#!/usr/bin/env python3
"""Prints the SQL analytics and saves docs/dashboard.png (normalised prices + drawdown)."""
import sqlite3
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).parent
con = sqlite3.connect(ROOT / "market_data.db")
show = lambda title, q: print(f"\n== {title} ==\n{pd.read_sql(q, con).to_string(index=False)}")

show("Risk summary", "SELECT * FROM v_risk_summary")
show("Correlation / beta", "SELECT * FROM v_correlation")
show("Positions (local currency)", "SELECT * FROM v_positions")

px = pd.read_sql("SELECT ticker, trade_date, adjusted_close FROM v_drawdown", con, parse_dates=["trade_date"])
dd = pd.read_sql("SELECT ticker, trade_date, drawdown FROM v_drawdown", con, parse_dates=["trade_date"])
src = ", ".join(f"{t}: {s}" for t, s in con.execute("SELECT ticker, data_source FROM assets"))
fig, (a1, a2) = plt.subplots(2, 1, figsize=(10, 7), sharex=True)
for t, g in px.groupby("ticker"):
    a1.plot(g.trade_date, 100 * g.adjusted_close / g.adjusted_close.iloc[0], label=t)
for t, g in dd.groupby("ticker"):
    a2.fill_between(g.trade_date, g.drawdown * 100, 0, alpha=0.35, label=t)
a1.set(title=f"Performance (base 100)  —  sources: {src}"); a1.legend()
a2.set(title="Drawdown (%)"); a2.legend(); a2.grid(alpha=.3); a1.grid(alpha=.3)
fig.tight_layout(); (ROOT / "docs").mkdir(exist_ok=True); fig.savefig(ROOT / "docs" / "dashboard.png", dpi=120)
print("\nChart saved: docs/dashboard.png")
