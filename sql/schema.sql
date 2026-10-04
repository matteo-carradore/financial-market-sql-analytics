-- 3NF schema. The script can be re-run: it starts again from an empty database.
PRAGMA foreign_keys = ON;

DROP VIEW  IF EXISTS v_position_ledger;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS daily_prices;
DROP TABLE IF EXISTS assets;
DROP TABLE IF EXISTS params;

CREATE TABLE params (
    name  TEXT PRIMARY KEY,
    value REAL NOT NULL
);
INSERT INTO params VALUES ('trading_days', 252), ('risk_free_rate', 0.0);

CREATE TABLE assets (
    asset_id      INTEGER PRIMARY KEY,
    ticker        TEXT NOT NULL UNIQUE,              -- UNIQUE already creates the index on ticker
    name          TEXT NOT NULL,
    asset_class   TEXT NOT NULL,
    base_currency TEXT NOT NULL CHECK (length(base_currency) = 3),
    data_source   TEXT NOT NULL CHECK (data_source IN ('YAHOO_CSV', 'SIMULATED'))
);

CREATE TABLE daily_prices (
    price_id       INTEGER PRIMARY KEY,
    asset_id       INTEGER NOT NULL REFERENCES assets(asset_id),
    trade_date     TEXT    NOT NULL,                 -- ISO 8601 (YYYY-MM-DD)
    open_price     REAL NOT NULL CHECK (open_price  > 0),
    high_price     REAL NOT NULL,
    low_price      REAL NOT NULL CHECK (low_price   > 0),
    close_price    REAL NOT NULL CHECK (close_price > 0),
    adjusted_close REAL NOT NULL CHECK (adjusted_close > 0),
    volume         INTEGER CHECK (volume >= 0),
    -- This UNIQUE already creates the (asset_id, trade_date) index, so no second identical index is needed.
    UNIQUE (asset_id, trade_date),
    CHECK (high_price >= low_price),
    CHECK (high_price >= open_price AND high_price >= close_price),
    CHECK (low_price  <= open_price AND low_price  <= close_price)
);

CREATE TABLE transactions (
    transaction_id  INTEGER PRIMARY KEY,
    asset_id        INTEGER NOT NULL REFERENCES assets(asset_id),
    trade_date      TEXT    NOT NULL,
    side            TEXT    NOT NULL CHECK (side IN ('BUY', 'SELL')),
    quantity        REAL    NOT NULL CHECK (quantity > 0),
    execution_price REAL    NOT NULL CHECK (execution_price > 0),
    fees            REAL    NOT NULL DEFAULT 0 CHECK (fees >= 0)
);
CREATE INDEX idx_tx_asset_date ON transactions (asset_id, trade_date, transaction_id);

-- Blocks selling more than what is held (no short selling in this model).
CREATE TRIGGER trg_no_oversell
BEFORE INSERT ON transactions
WHEN NEW.side = 'SELL'
BEGIN
    SELECT RAISE(ABORT, 'SELL exceeds held position')
    WHERE NEW.quantity > COALESCE((
        SELECT SUM(CASE side WHEN 'BUY' THEN quantity ELSE -quantity END)
        FROM transactions
        WHERE asset_id = NEW.asset_id AND trade_date <= NEW.trade_date
    ), 0);
END;
