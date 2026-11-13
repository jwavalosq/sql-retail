# Retail in SQL

Learn SQL on a real shop, not toy data. One UK online retailer, selling gift ware, recorded 1,067,371 order lines from Dec 1, 2009 to Dec 9, 2011. After cleaning, 791,045 lines remain, worth 17,431,551.18 GBP. You start with simple filters and end with window functions, CTEs, RFM segments, and five recruiter style interview questions, all in SQLite.

A retail order line is one product on one invoice: how many units, at what price, bought by which customer, in which country, on which date. Revenue on a line is Quantity times Price, in GBP. Most customers here are wholesalers who buy again and again, which is why repeat buyers drive almost all the revenue.

## How to run it

You need only Python and SQLite. The loader needs pandas and openpyxl to read the UCI Excel file. Charts need matplotlib.

```bash
pip install -r requirements.txt
python3 scripts/load_database.py
sqlite3 retail.db < sql/01_foundations.sql
```

Repeat the last command for files 02 through 06, in order. Each file is self contained and heavily commented, with the question in plain words, what you will learn, and how the query works line by line.

The database file is gitignored on purpose. You rebuild it any time with the load script, which downloads the UCI file directly if the Excel file is missing. Query outputs live in `results/`. Charts live in `charts/` and in `docs/charts/`. The story site is `docs/index.html`, with one chapter per ladder step.

## The learning ladder

1. `sql/01_foundations.sql`: SELECT, WHERE, ORDER BY, LIMIT, DISTINCT, LIKE. Look at rows.
2. `sql/02_aggregations.sql`: COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING. Count and group.
3. `sql/03_joins.sql`: INNER JOIN, LEFT JOIN, self-join. Combine tables and check they agree.
4. `sql/04_window_functions.sql`: ROW_NUMBER, RANK, running totals, LAG. Rank and compare without collapsing rows.
5. `sql/05_ctes_and_case.sql`: WITH clauses, CASE WHEN buckets, RFM segments. Break hard questions into steps.
6. `sql/06_capstone.sql`: five recruiter style interview questions, each answered in one well commented query.

## The data model

- `transactions`: one row per cleaned order line, 791,045 rows. This is the fact table.
- `invoices`: one row per invoice, 36,969 rows. Invoice date is the earliest line time for that invoice.
- `customers`: one row per Customer ID, 5,878 rows. Country is the customer's most frequent country.
- `products`: one row per StockCode, 4,631 rows. Description is the most frequent description for that StockCode.
- `countries`: one row per country, 41 rows.
- `monthly_revenue`: one row per calendar month, 25 months.
- `cleaning_funnel`: one row per cleaning step, with counts.

## Headline findings, all from the queries in this repo

- Total cleaned lines: 791,045. Total revenue: 17,431,551.18 GBP. Date range: 2009-12-01 to 2011-12-09. Customers: 5,878. Invoices: 36,969. Countries: 41.
- Best month: 2010-11, with 1,172,336.04 GBP, 6.7 percent of all revenue. Next: 2011-11, with 1,161,817.38 GBP. November leads in both years.
- Revenue by year: 2009, 686,654.16 GBP (December only); 2010, 8,406,185.00 GBP; 2011, 8,338,712.01 GBP (to Dec 9).
- Top country: United Kingdom, 14,444,491.73 GBP, 82.9 percent of revenue, with 5,350 customers. Outside the UK, EIRE leads with 616,897.33 GBP.
- Top product: REGENCY CAKESTAND 3 TIER, 278,150.20 GBP. Next: WHITE HANGING HEART T-LIGHT HOLDER, 247,389.21 GBP.
- Top customer: 18102, with 580,987.04 GBP. The top 10 customers together bring 2,787,566.23 GBP, 16.0 percent of revenue.
- Average basket: 471.52 GBP. Median basket: 303.60 GBP. Average invoice holds 21.4 lines.
- Repeat buyers: 4,255 customers, 72.4 percent of the base, bringing 96.8 percent of revenue. One-time buyers: 1,623 customers, 3.2 percent of revenue.
- RFM segments: Champions are 771 customers, 13.1 percent of the base, but bring 10,616,836.77 GBP, 60.9 percent of revenue. Loyal are 1,397 customers, 19.4 percent of revenue. At Risk are 344 customers, 6.7 percent of revenue.
- The summary tables match the main table exactly: every customer revenue and every month revenue differs by 0 after rounding to 2 decimals.

## The honest limits, read this before you quote a total

This is the full UCI Online Retail II file, Dec 2009 to Dec 2011, not the Dec 2010 to Dec 2011 slice used in the earlier Python retail project. That slice had 541,909 rows. This project has 1,067,371 raw rows and 791,045 cleaned rows. Do not mix the two sets of numbers.

The two UCI sheets overlap: both cover Dec 1 to Dec 9, 2010. The same 14,504 cleaned rows appear in both sheets, worth 311,878.00 GBP. The loader removes only the second copy and counts it as cleaning step 4. Without that step, Dec 2010 revenue would read 884,591.89 GBP instead of 572,713.89 GBP, and total revenue would read 17,743,429.18 GBP instead of 17,431,551.18 GBP. Within-sheet exact duplicates are kept, 11,620 rows, because the same line repeated inside one sheet cannot be told apart from a genuine repeated line.

No customer names exist in the file. Customer ID is the only customer key. Do not invent names.

StockCode M means Manual and StockCode POST means postage. They are not real products, but they carry real revenue: Manual is 152,166.32 GBP, postage is 124,648.04 GBP, and postage is the top line for Germany and France. Product rankings name this instead of hiding it.

RFM segments are descriptive buckets from the thresholds stated in `sql/05_ctes_and_case.sql`. They are not a proven churn predictor. No churn classifier and no forecast is presented here.

December 2009 is a partial month: the file starts on 2009-12-01. December 2011 is also partial: the file ends on 2011-12-09. Do not compare those months with full months as if they were equal.

Revenue is in GBP as Quantity times Price. Cancellations and zero or negative rows are excluded from revenue and counted separately in the cleaning funnel.

No language model was trained or used here. This project is SQL only, by design: the point is to master SQL.

## Files

- `scripts/load_database.py`: downloads the UCI zip if needed, cleans, and builds retail.db.
- `scripts/export_results.py`: runs the key queries and writes `results/` CSVs.
- `scripts/make_charts.py`: builds the 8 charts from `results/` CSVs.
- `sql/`: the six ladder files, in order.
- `results/`: 11 CSV outputs of the key queries.
- `charts/` and `docs/charts/`: 8 charts.
- `docs/index.html`: the story site, one chapter per ladder step.
- `data/raw/online_retail_II.xlsx`: the UCI file, gitignored, re-downloadable by the loader.
- `BUILD_REPORT.md`, `PROVENANCE.md`: sources, build steps, verification log.

Local build only. Nothing here has been published to GitHub.
