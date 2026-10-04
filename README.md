# Market Data, Risk & Portfolio Analytics in SQL

Base SQLite normalisée (3NF) pour analyser le risque de marché et suivre un portefeuille, avec **toute la logique analytique écrite en SQL** (window functions, CTE récursive, vues) et vérifiée par des tests contre un recalcul indépendant en pandas.

> **À propos des données** : chaque actif porte une colonne `data_source` (`YAHOO_CSV` ou `SIMULATED`), et le build refuse de générer des données fictives sans l'option `--simulate`. Le dashboard et la synthèse de risque affichent la source. Pour des résultats réels, voir *Données réelles* ci-dessous.

## Ce que fait le projet

| Module | Fichier | Contenu |
|---|---|---|
| Schéma | `sql/schema.sql` | `assets`, `daily_prices`, `transactions`, contraintes `CHECK` (OHLC cohérent, prix > 0), trigger anti-vente à découvert |
| Rendements & tendance | `sql/views.sql` → `v_returns` | rendement quotidien (`LAG`), spread intraday, SMA 20/50 (NULL tant que la fenêtre n'est pas remplie) |
| Drawdown | `v_drawdown` | high-water mark (`MAX() OVER`) et drawdown courant |
| Risque | `v_risk_summary` | CAGR, volatilité annualisée, Sharpe, max drawdown, Calmar (`params` : 252 jours, taux sans risque) |
| Co-mouvement | `v_correlation` | corrélation et bêta par paire, sur dates communes |
| Portefeuille | `sql/portfolio.sql` | PRU en **coût moyen pondéré** via CTE récursive, **BUY et SELL**, PnL réalisé et latent, frais inclus |

Tout se base sur `adjusted_close` (dividendes/splits), sans arrondi intermédiaire : les `ROUND` sont uniquement à l'affichage.

## Quickstart

```bash
pip install -r requirements.txt

python3 build_db.py    # démo avec données simulées (ou voir "Données réelles")
python3 report.py                  # tableaux + docs/dashboard.png
python3 -m unittest discover -s tests -v
```

Ou directement avec les vues : `sqlite3 -header -column market_data.db "SELECT * FROM v_risk_summary"`.

## Données réelles

```bash
pip install yfinance
python3 fetch_prices.py MC.PA SPY  # écrit data/prices/MC.PA.csv et SPY.csv
python3 build_db.py                # utilise automatiquement les CSV
```

Le loader rejette les fichiers HTML (page anti-bot téléchargée par erreur), ignore les lignes `null` de Yahoo et vérifie un minimum de séances.

## Exemple de sortie (données réelles Yahoo Finance, 2023-2026)

```
ticker data_source  cagr_pct  ann_vol_pct  sharpe  max_drawdown_pct  calmar
 MC.PA   YAHOO_CSV    -13.06        29.17   -0.33            -54.79   -0.24
   SPY   YAHOO_CSV     22.30        14.92    1.42            -18.76    1.19
```

![dashboard](docs/dashboard.png)

## Choix de conception

- **Index** : `UNIQUE(asset_id, trade_date)` crée déjà l'index composite ; aucun doublon n'est ajouté (un test le vérifie). Seul `transactions` a un index dédié.
- **Idempotence** : `build_db.py` reconstruit la base de zéro ; relancer ne duplique rien.
- **Pas de conversion de devise** : `v_positions` affiche une ligne par actif dans sa devise. Agréger EUR + USD demanderait une table `fx_rates`.
- **Limites** : coût moyen pondéré uniquement (pas FIFO), pas de dividendes en cash, pas de vente à découvert.

## Pistes d'évolution

Table `fx_rates` et valorisation en EUR, FIFO comme méthode alternative, VaR historique (`NTILE`/percentile), benchmark et alpha.
