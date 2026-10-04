#!/usr/bin/env python3
"""Télécharge de vraies données via yfinance -> data/prices/<TICKER>.csv  (pip install yfinance)."""
import sys
from pathlib import Path
import yfinance as yf

out = Path(__file__).parent / "data" / "prices"
out.mkdir(parents=True, exist_ok=True)
for t in sys.argv[1:] or ["MC.PA", "SPY"]:
    df = yf.download(t, start="2023-01-01", auto_adjust=False, progress=False, multi_level_index=False)
    if df.empty:
        sys.exit(f"Aucune donnée reçue pour {t}")
    df.to_csv(out / f"{t}.csv")
    print(f"{t}: {len(df)} séances ({df.index[0].date()} -> {df.index[-1].date()})")
