"""Compares the SQL results with an independent Python/pandas calculation.
Run:  python -m unittest discover -s tests -v   (after python build_db.py)"""
import sqlite3
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

DB = Path(__file__).parents[1] / "market_data.db"


class AnalyticsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.con = sqlite3.connect(DB)

    @classmethod
    def tearDownClass(cls):
        cls.con.close()

    def prices(self, ticker):
        df = pd.read_sql("SELECT trade_date, adjusted_close px FROM daily_prices JOIN assets USING(asset_id) "
                         "WHERE ticker=? ORDER BY trade_date", self.con, params=(ticker,))
        return df.set_index("trade_date").px

    def test_risk_metrics_match_pandas(self):
        for ticker in ("MC.PA", "SPY"):
            with self.subTest(ticker=ticker):
                px = self.prices(ticker)
                r = px.pct_change().dropna()
                row = pd.read_sql("SELECT * FROM v_risk_summary WHERE ticker=?", self.con, params=(ticker,)).iloc[0]
                self.assertAlmostEqual(row.max_drawdown_pct, (px / px.cummax() - 1).min() * 100, delta=0.01)
                self.assertAlmostEqual(row.ann_vol_pct, r.std() * np.sqrt(252) * 100, delta=0.01)
                self.assertAlmostEqual(row.sharpe, r.mean() * 252 / (r.std() * np.sqrt(252)), delta=0.01)
                self.assertAlmostEqual(row.cagr_pct, ((px.iloc[-1] / px.iloc[0]) ** (252 / len(r)) - 1) * 100, delta=0.01)

    def test_correlation_and_beta_match_pandas(self):
        # Align by DATE: Paris and New York have different market holidays.
        d = pd.concat([self.prices("MC.PA").pct_change(), self.prices("SPY").pct_change()],
                      axis=1, join="inner").dropna()
        x, y = d.iloc[:, 0], d.iloc[:, 1]
        row = pd.read_sql("SELECT * FROM v_correlation", self.con).iloc[0]
        self.assertEqual(row.common_days, len(d))
        self.assertAlmostEqual(row.correlation, x.corr(y), delta=0.001)
        self.assertAlmostEqual(row.beta_t1_vs_t2, x.cov(y) / y.var(), delta=0.001)

    def test_average_cost_matches_python_loop(self):
        """Recomputes average cost / cost basis / realized PnL with a Python loop over the transactions table."""
        tx = pd.read_sql("SELECT ticker, side, quantity q, execution_price p, fees f FROM transactions "
                         "JOIN assets USING(asset_id) ORDER BY trade_date, transaction_id", self.con)
        pos = pd.read_sql("SELECT * FROM v_positions", self.con).set_index("ticker")
        for ticker, g in tx.groupby("ticker"):
            shares = cost = realized = 0.0
            for r in g.itertuples():
                if r.side == "BUY":
                    shares += r.q
                    cost += r.q * r.p + r.f
                else:
                    avg = cost / shares
                    realized += r.q * r.p - r.f - r.q * avg
                    cost -= r.q * avg
                    shares -= r.q
            with self.subTest(ticker=ticker):
                self.assertAlmostEqual(pos.loc[ticker, "shares"], shares, places=6)
                self.assertAlmostEqual(pos.loc[ticker, "cost_basis"], cost, delta=0.01)
                self.assertAlmostEqual(pos.loc[ticker, "realized_pnl"], realized, delta=0.01)

    def test_transactions_use_real_closes(self):
        bad = self.con.execute(
            "SELECT COUNT(*) FROM transactions t JOIN daily_prices p "
            "ON p.asset_id=t.asset_id AND p.trade_date=t.trade_date WHERE p.close_price != t.execution_price"
        ).fetchone()[0]
        self.assertEqual(bad, 0)

    def test_oversell_rejected(self):
        with self.assertRaises(sqlite3.DatabaseError):
            self.con.execute("INSERT INTO transactions (asset_id,trade_date,side,quantity,execution_price) "
                             "VALUES (1,'2026-09-01','SELL',999,1)")
        self.con.rollback()

    def test_no_redundant_indexes(self):
        idx = [r[0] for r in self.con.execute(
            "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'")]
        self.assertEqual(idx, ["idx_tx_asset_date"])


if __name__ == "__main__":
    unittest.main()
