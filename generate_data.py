import random
from datetime import date, timedelta

random.seed(42)

assets = [
    {"id": 1, "ticker": "MC.PA", "start_price": 680.0, "drift": 0.0002, "vol": 0.015},
    {"id": 2, "ticker": "SPY",   "start_price": 490.0, "drift": 0.0004, "vol": 0.010}
]

start_date = date(2025, 1, 1)
end_date = date(2026, 9, 30)

with open("seed_full.sql", "w") as f:
    f.write("-- Clean slate\n")
    f.write("DELETE FROM daily_prices;\n")
    f.write("DELETE FROM assets;\n\n")
    f.write("INSERT INTO assets (asset_id, ticker, name, asset_class, base_currency) VALUES\n")
    f.write("(1, 'MC.PA', 'LVMH Moët Hennessy', 'Equities', 'EUR'),\n")
    f.write("(2, 'SPY', 'SPDR S&P 500 ETF Trust', 'Equities', 'USD');\n\n")
    f.write("INSERT INTO daily_prices (asset_id, trade_date, open_price, high_price, low_price, close_price, adjusted_close, volume) VALUES\n")

    records = []
    for asset in assets:
        price = asset["start_price"]
        cur = start_date
        while cur <= end_date:
            if cur.weekday() < 5:  # Lundi à Vendredi uniquement
                ret = random.gauss(asset["drift"], asset["vol"])
                open_p = round(price * (1 + random.uniform(-0.003, 0.003)), 2)
                close_p = round(price * (1 + ret), 2)
                high_p = round(max(open_p, close_p) * (1 + random.uniform(0.001, 0.008)), 2)
                low_p = round(min(open_p, close_p) * (1 - random.uniform(0.001, 0.008)), 2)
                vol = int(random.gauss(350000 if asset["id"] == 1 else 45000000, 50000))
                
                records.append(f"({asset['id']}, '{cur.isoformat()}', {open_p}, {high_p}, {low_p}, {close_p}, {close_p}, {max(vol, 10000)})")
                price = close_p
            cur += timedelta(days=1)

    f.write(",\n".join(records) + ";\n")

print(f"Génération terminée : {len(records)} séances créées dans seed_full.sql.")