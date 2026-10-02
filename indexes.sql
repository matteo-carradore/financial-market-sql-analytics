CREATE INDEX IF NOT EXISTS idx_prices_asset_date 
ON daily_prices (asset_id, trade_date);

CREATE INDEX IF NOT EXISTS idx_assets_ticker 
ON assets (ticker);