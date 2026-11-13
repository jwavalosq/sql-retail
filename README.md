# Retail in SQL

I started with a simple question. What does a real shop actually look like when you read its orders line by line, and can SQL tell me who its business really depends on?

This is a UK online retailer selling gift ware. It recorded 1,067,371 order lines from Dec 1, 2009 to Dec 9, 2011. After cleaning, 791,045 lines remain, worth 17,431,551.18 GBP. I start with simple filters and end with window functions, CTEs, RFM segments, and five recruiter style interview questions, all in SQLite.

[Story site: Retail in SQL](https://jwavalosq.github.io/sql-retail/) | [Repo](https://github.com/jwavalosq/sql-retail)

## The question I started with

I wanted to learn SQL on data a real business would recognize. So I asked: if I take every line this shop ever sold in two years, clean it properly, and query it in SQL, what story does it tell about customers, countries, products, and seasons?

A retail order line is one product on one invoice: how many units, at what price, bought by which customer, in which country, on which date. Revenue on a line is Quantity times Price, in GBP. Most customers here are wholesalers who buy again and again, which is why repeat buyers drive almost all the revenue. That fact alone changes how you read every other number in this project.

## Why it matters

Every shop has to answer the same questions. Who are my best customers? Which products actually sell? Which months carry the year? How much of my business depends on one country, or on ten customers? Guessing at those answers is expensive. Querying them, with the cleaning counted and the limits stated, is how a business makes decisions it can defend.

This project helps anyone who wants to learn SQL on messy, real-world data, and anyone hiring for analytics who wants to see how I handle a file that does not arrive clean.

## What I did, step by step

First, I took the full UCI Online Retail II file, dataset 502, creator Daqing Chen, DOI 10.24432/C5CG6D. I measured the file myself instead of trusting the listing alone. The listing matches: 1,067,371 rows, Dec 1, 2009 to Dec 9, 2011.

Next, I cleaned it in Python with a counted funnel, and I kept every count. I dropped 19,494 cancellation rows, then 6,207 rows with Quantity or Price at or below zero, then 236,121 rows with no Customer ID. Then I caught something the listing does not warn you about: the two sheets overlap. Both cover Dec 1 to Dec 9, 2010, so the same 14,504 cleaned rows appear in both sheets, worth 311,878.00 GBP. I dropped only the second copy, one row for one row, and counted it as cleaning step 4. That left 791,045 cleaned lines.

Then I built a loader, `scripts/load_database.py`, that turns the cleaned data into a SQLite database with seven tables: `transactions`, `invoices`, `customers`, `products`, `countries`, `monthly_revenue`, and `cleaning_funnel`. It renames the source columns to snake_case, adds Revenue as Quantity times Price in GBP, and adds indexes on customer_id, invoice_no, stock_code, country, and invoice_date.

Then I wrote six SQL files, one step at a time, in `sql/`. Each file is self contained and heavily commented, with the question in plain words, what you will learn, and how each query works line by line:

1. `sql/01_foundations.sql`: SELECT, WHERE, ORDER BY, LIMIT, DISTINCT, LIKE. Look at rows.
2. `sql/02_aggregations.sql`: COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING. Count and group.
3. `sql/03_joins.sql`: INNER JOIN, LEFT JOIN, self-join. Combine tables and check they agree.
4. `sql/04_window_functions.sql`: ROW_NUMBER, RANK, running totals, LAG. Rank and compare without collapsing rows.
5. `sql/05_ctes_and_case.sql`: WITH clauses, CASE WHEN buckets, RFM segments. Break hard questions into steps.
6. `sql/06_capstone.sql`: five recruiter style interview questions, each answered in one well commented query.

I ran all 46 SQL statements against the database. Zero errors. I exported the key results to 11 CSVs in `results/`, and I built 8 charts from those results, in `charts/` and in `docs/charts/`. The story site is `docs/index.html`, with one chapter per ladder step.

## What I found

Every number below comes from the queries in this repo, checked against an independent Python check. Nothing here is guessed.

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

## What it means

This is a wholesaler business wearing a gift shop label. A small group of repeat buyers carries almost everything: 771 Champions bring 60.9 percent of revenue, and all repeat buyers together bring 96.8 percent. Lose a handful of those customers and the shop loses a large share of its income. That is the finding a manager should act on first.

It is also a Christmas business. November leads in both years, so the peak is a season, not a one-off. And it is a UK business with export sales on the side: the UK is 82.9 percent of revenue, and the best non-UK country, EIRE, is 616,897.33 GBP. Any plan to grow abroad starts from a very small base.

For me, the deeper lesson is the cleaning. Without catching the nine day sheet overlap, Dec 2010 revenue would have read 884,591.89 GBP instead of 572,713.89 GBP, and total revenue would have read 17,743,429.18 GBP instead of 17,431,551.18 GBP. The most important number in this project is not a total. It is the 311,878.00 GBP I did not double count.

## How to run it yourself

### In Colab first

Open a new Google Colab notebook, clone this repo, install the requirements, and run the loader to rebuild the database. The loader downloads the UCI file directly if the Excel file is missing. Then run each SQL file in order with Python sqlite3, or open the database and run the queries step by step. You do not need a database file to start, because the loader rebuilds it from the source file.

### On your laptop second

You need only Python and SQLite. The loader needs pandas and openpyxl to read the UCI Excel file. Charts need matplotlib.

```bash
pip install -r requirements.txt
python3 scripts/load_database.py
sqlite3 retail.db < sql/01_foundations.sql
```

Repeat the last command for files 02 through 06, in order.

The database file is gitignored on purpose. You rebuild it any time with the load script, which downloads the UCI file directly if the Excel file is missing. Query outputs live in `results/`. Charts live in `charts/` and in `docs/charts/`. The story site is `docs/index.html`, with one chapter per ladder step.

## The data model

- `transactions`: one row per cleaned order line, 791,045 rows. This is the fact table.
- `invoices`: one row per invoice, 36,969 rows. Invoice date is the earliest line time for that invoice.
- `customers`: one row per Customer ID, 5,878 rows. Country is the customer's most frequent country.
- `products`: one row per StockCode, 4,631 rows. Description is the most frequent description for that StockCode.
- `countries`: one row per country, 41 rows.
- `monthly_revenue`: one row per calendar month, 25 months.
- `cleaning_funnel`: one row per cleaning step, with counts.

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

Published at https://github.com/jwavalosq/sql-retail, story site https://jwavalosq.github.io/sql-retail/
