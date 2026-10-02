DROP TABLE IF EXISTS daily_prices;
DROP TABLE IF EXISTS assets;

CREATE TABLE assets (
    asset_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticker TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    asset_class TEXT NOT NULL,
    base_currency TEXT NOT NULL
);

CREATE TABLE daily_prices (
    price_id INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_id INTEGER NOT NULL,
    trade_date DATE NOT NULL,
    open_price REAL NOT NULL,
    high_price REAL NOT NULL,
    low_price REAL NOT NULL,
    close_price REAL NOT NULL,
    adjusted_close REAL NOT NULL,
    volume INTEGER,
    FOREIGN KEY (asset_id) REFERENCES assets(asset_id),
    UNIQUE(asset_id, trade_date)
);

CREATE INDEX idx_asset_date ON daily_prices (asset_id, trade_date);