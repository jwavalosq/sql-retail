# Build Report: Retail in SQL

## What was built

A SQL only portfolio project on the full UCI Online Retail II file, in the same story driven style as the Executive Orders in SQL project, but on retail data. Local build only at `~/workspace/sql-retail/`. Nothing was published, no GitHub repo was created, nothing was posted, per the brief. Jesus will give a separate explicit go before any publish.

## Sources

See `PROVENANCE.md` for full source notes. In short: UCI Machine Learning Repository, Online Retail II, dataset 502, creator Daqing Chen, DOI 10.24432/C5CG6D, direct download https://archive.ics.uci.edu/static/public/502/online+retail+ii.zip. The file was already downloaded at `data/raw/online_retail_ii_uci.zip`, 45,622,418 bytes, HTTP 200 from UCI. The loader re-downloads from that URL if the xlsx is missing.

## Build steps

1. Read the source file with Python and pandas and openpyxl, both sheets, and measured it directly instead of trusting the UCI listing alone. The listing matches: 1,067,371 rows, Dec 1, 2009 to Dec 9, 2011.
2. Found the sheet overlap: both sheets cover Dec 1 to Dec 9, 2010. Decided, with counts, to drop only the second copy of exact cross-sheet duplicates as cleaning step 4, and to keep within-sheet exact duplicates and report them.
3. Wrote `scripts/load_database.py`, which builds `retail.db` with seven tables: `transactions`, `invoices`, `customers`, `products`, `countries`, `monthly_revenue`, `cleaning_funnel`. It renames the source columns to snake_case, adds Revenue as Quantity times Price in GBP, and adds indexes on customer_id, invoice_no, stock_code, country, and invoice_date.
4. Wrote the six ladder files in `sql/`, each with plain language header comments: the question, what you will learn, and how each query works line by line.
5. Ran every SQL file against the built database. Zero errors allowed, zero errors found.
6. Wrote `scripts/export_results.py` (11 results CSVs) and `scripts/make_charts.py` (8 charts, saved to both `charts/` and `docs/charts/`).
7. Wrote `docs/index.html` (one chapter per ladder step), `README.md`, this report, and `PROVENANCE.md`.
8. Grepped the whole folder for the em-dash character. Result: zero matches.

## Verification log

Loader counts:
- Raw, both sheets: 1,067,371 rows. Sheet A, Year 2009-2010: 525,461 rows. Sheet B, Year 2010-2011: 541,910 rows.
- After cancellations: 1,047,877 rows, 19,494 dropped.
- After Quantity <= 0 or Price <= 0: 1,041,670 rows, 6,207 dropped.
- After no Customer ID: 805,549 rows, 236,121 dropped.
- After cross-sheet dedup: 791,045 rows, 14,504 dropped, 311,878.00 GBP dropped.
- transactions: 791,045 rows. invoices: 36,969 rows. customers: 5,878 rows. products: 4,631 rows. countries: 41 rows. monthly_revenue: 25 rows.
- Total revenue: 17,431,551.18 GBP. Date range: 2009-12-01 07:45:00 to 2011-12-09 12:50:00.
- Within-sheet exact duplicate rows kept: 11,620. Invoices with more than one line timestamp: 64.
- Database file: retail.db, about 172 MB, gitignored by design.

SQL execution (all statements run with Python sqlite3, split on complete statements):
- sql/01_foundations.sql: 10 statements, 0 errors
- sql/02_aggregations.sql: 12 statements, 0 errors
- sql/03_joins.sql: 6 statements, 0 errors
- sql/04_window_functions.sql: 7 statements, 0 errors
- sql/05_ctes_and_case.sql: 6 statements, 0 errors
- sql/06_capstone.sql: 5 statements, 0 errors
- Total: 46 statements, 0 errors.

Headline figures, all matched between SQL and an independent Python check, no adjustments:
- Total lines: 791,045. Total revenue: 17,431,551.18 GBP.
- Revenue by year: 2009, 686,654.16 GBP on 30,754 lines (December only); 2010, 8,406,185.00 GBP on 388,563 lines; 2011, 8,338,712.01 GBP on 371,728 lines (to Dec 9).
- Best months: 2010-11, 1,172,336.04 GBP; 2011-11, 1,161,817.38 GBP; 2011-10, 1,039,318.79 GBP; 2010-10, 1,036,680.00 GBP; 2011-09, 952,838.38 GBP. Dec 2010 after dedup: 572,713.89 GBP, against 884,591.89 GBP naive.
- Top countries: United Kingdom 14,444,491.73 GBP (82.9 percent, 5,350 customers); EIRE 616,897.33 GBP; Netherlands 554,039.74 GBP; Germany 425,578.38 GBP; France 348,967.05 GBP; Australia 169,350.96 GBP; Spain 108,383.81 GBP; Switzerland 100,061.94 GBP. Eight countries clear 100,000 GBP. Non-UK total: 2,987,059.45 GBP, 17.1 percent.
- Top products: REGENCY CAKESTAND 3 TIER 278,150.20 GBP; WHITE HANGING HEART T-LIGHT HOLDER 247,389.21 GBP; PAPER CRAFT, LITTLE BIRDIE 168,469.60 GBP; Manual 152,166.32 GBP; JUMBO BAG RED RETROSPOT 134,602.73 GBP.
- Top customers: 18102, 580,987.04 GBP; 14646, 528,602.52 GBP; 14156, 313,624.17 GBP; 14911, 291,561.05 GBP on 398 invoices, the most invoices of any customer. Top 10 together: 2,787,566.23 GBP, 16.0 percent.
- Average basket: 471.52 GBP. Median basket: 303.60 GBP. Smallest basket: 0.38 GBP. Largest basket: 168,469.60 GBP. Average lines per invoice: 21.4. Fewest lines: 1. Most lines: 542.
- Repeat buyers: 4,255 customers, 16,868,755.83 GBP, 96.8 percent. One-time buyers: 1,623 customers, 562,795.35 GBP, 3.2 percent.
- RFM segments, measured from 2011-12-10 in SQL: Champions 771 customers, 10,616,836.77 GBP, 60.9 percent; Loyal 1,397 customers, 3,376,708.87 GBP, 19.4 percent; At Risk 344 customers, 1,176,040.07 GBP, 6.7 percent; Potential Loyalists 658 customers, 759,317.52 GBP, 4.4 percent; One-time 1,500 customers, 523,677.55 GBP, 3.0 percent; Occasional 524 customers, 495,788.40 GBP, 2.8 percent; Hibernating 561 customers, 444,064.18 GBP, 2.5 percent; New Customers 123 customers, 39,117.80 GBP, 0.2 percent. Total: 5,878 customers.
- Recency buckets: 0-30 days, 1,628 customers; 31-90 days, 1,261; 91-180 days, 588; 181-365 days, 787; 366+ days, 1,614.
- Monetary bands: Under 500 GBP, 2,054 customers; 500-999, 1,107; 1000-2499, 1,367; 2500-9999, 1,088; 10000+, 262. Average total spend per customer: 2,965.56 GBP. Customers above that average: 1,160.
- Frequency buckets: 1 order, 1,623 customers; 2-3 orders, 1,608; 4-9 orders, 1,673; 10+ orders, 974.
- Cohort: Dec 2009 first-order cohort, 955 customers, 871 returned, 91.2 percent. 2010-06 cohort, 270 customers, 75.9 percent returned.
- Join checks: customer revenue differences are 0 after rounding to 2 decimals, with a maximum floating point difference of about 3e-11. Month revenue differences are likewise 0 after rounding, maximum about 1e-10.
- Top product per country: United Kingdom, WHITE HANGING HEART T-LIGHT HOLDER, 228,148.41 GBP. Germany and France top with POSTAGE, EIRE tops with Manual, as flagged in the queries.
- Largest single line: 80,995 units of PAPER CRAFT, LITTLE BIRDIE, 168,469.60 GBP, invoice 581483, customer 16446, 2011-12-09. Highest unit price: 10,953.50 GBP, Manual, invoice 502263, customer 12918, 2010-03-23. Cheapest unit price: 0.001 GBP.

Corrections made during verification (caught before delivery, not glossed over):
- The first RFM segment counts were taken from a Python preview that measured recency from 2011-12-09. The SQL in this project measures recency from 2011-12-10, the day after the last order, which shifts borderline customers across the 30, 90, 180, and 365 day thresholds. The SQL numbers are the project standard, so all segment counts, the recency buckets, and the average spend were corrected to the SQL values: Loyal 1,397 not 1,398, At Risk 344 not 343, Hibernating 561 not 554, One-time 1,500 not 1,492, Occasional 524 not 531, New Customers 123 not 131, recency 0-30 days 1,628 not 1,667, 366+ days 1,614 not 1,604, average spend 2,965.56 not 2,965.47, Champions revenue 10,616,836.77 not .78.
- The aggregation comment first said ten countries clear 100,000 GBP. The query shows eight. Fixed.
- The aggregation comment first gave Germany revenue as 431,262.46 GBP, the naive figure before the cross-sheet dedup. The cleaned figure is 425,578.38 GBP. Fixed.
- The foundations comment first described the cheapest lines as a few pence each. The cheapest line is 0.001 GBP. Fixed.
- The loader docstring first gave Manual revenue as 152,340.57 GBP, the naive figure. The cleaned figure is 152,166.32 GBP. Fixed.

Charts: 8 PNG files, all validated as readable images, in both `charts/` and `docs/charts/`:
01_monthly_revenue, 02_top_countries, 03_top_products, 04_revenue_by_year, 05_rfm_segments, 06_running_total, 07_repeat_vs_onetime, 08_top_customers.

Results: 11 CSV files in `results/`, all generated by scripts/export_results.py from the built database.

Em-dash check: grep for the em-dash character across the whole folder returned zero matches.

## Cuts and limits

- The database file is gitignored and must be rebuilt with the load script. That is intentional: the repo ships code and small CSVs, not a 172 MB binary database or a 45 MB Excel file.
- The raw xlsx and zip are gitignored. The loader re-downloads the zip from UCI if the xlsx is missing.
- No large raw or cleaned transaction CSV is shipped in the repo folder, because a 45 MB plus file would fail the GitHub blob API. Results are small aggregated CSVs only.
- RFM segments are descriptive buckets from stated thresholds, not a proven churn predictor. No churn model and no forecast are presented.
- Within-sheet exact duplicates are kept and reported, 11,620 rows, as documented in PROVENANCE.md.
- The story site is a local HTML file. It is not published anywhere, per the local only instruction.
- Charts are matplotlib only, plain styled, built from query result CSVs. No interactive dashboard was built for this project, because the brief asked for SQL mastery, not a dashboard.
