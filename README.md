# Portfolio Projects

This repository contains Python and SQL portfolio work:

- `Movie Correlation Portfolio Project.ipynb`: Python data cleaning, categorical encoding, Pearson correlation analysis, and visualization with Pandas, NumPy, Seaborn, and Matplotlib.
- `Basketball Web Scraping.ipynb`: Stathead/Basketball Reference webpage collection with Requests, BeautifulSoup, and Pandas. Set `STATHEAD_USER_COOKIE` in the environment before running; never commit session cookies.
- `Nashville Housing Data Cleaning Scripts.sql`: SQL Server cleaning with joins, string functions, `CASE`, a CTE, and `ROW_NUMBER()`.
- `Covid Portfolio Project Scripts.sql`: SQL Server exploration with joins, aggregates, a CTE, a temporary table, window calculations, and a reporting view.

## Movie Data

Place the movie dataset at `data/movies.csv` before running the movie notebook. The dataset is not included in this repository, so use the same `movies.csv` source used for the original analysis.


## SQL execution and regression checks

The scripts target SQL Server and an imported `[Portfolio Project]` database.
Nashville retains the original columns and only lists candidate duplicates; it
never deletes records. It creates derived columns if absent, handles addresses
without commas, preserves periods in owner street names, and leaves conflicting
parcel addresses unresolved for review.

COVID continent totals sum each country's maximum reported cumulative death
count rather than selecting the largest country. Ratios use decimal arithmetic
and return NULL for zero denominators. Cumulative vaccinations count doses, not
unique vaccinated people; `RollingVaccinationDoses` and `DosesPer100People` make
that distinction explicit. The legacy `PercentPopulationVaccinated` view name
is retained, but its cumulative column is now `RollingVaccinationDoses`.

With SQL Server and `sqlcmd` installed, run:

```powershell
python tests/test_sql_server.py --server localhost
```

The test runs both scripts twice against synthetic data in a uniquely named
`CodexPortfolioTest_*` database and removes that test database afterward. It does
not use or change the existing `[Portfolio Project]` database. The test account
needs permission to create and drop its test database.


## Movie notebook transformation checks

Run `python tests/test_movie_notebook.py` with pandas installed. The tests execute
actual transformation cells against fixtures with missing release years and
category values. Unknown release years remain nullable integers, and category
encoding uses a separate copy instead of overwriting the original movie data.
Outputs from the two changed cells are cleared. Other displayed outputs are
explicitly marked as cached until the notebook is rerun with the source CSV. Integer category codes are arbitrary:
Pearson correlations involving those codes do not establish a meaningful
relationship between unordered categories.
