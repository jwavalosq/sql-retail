# Provenance: Retail in SQL

## Source, with what was taken from it

UCI Machine Learning Repository, Online Retail II, dataset 502, creator Daqing Chen, DOI 10.24432/C5CG6D.

- Page: https://archive.ics.uci.edu/dataset/502/online+retail+ii
- Direct download: https://archive.ics.uci.edu/static/public/502/online+retail+ii.zip
- File downloaded: `data/raw/online_retail_ii_uci.zip`, 45,622,418 bytes, HTTP 200 from UCI, holding one xlsx, `online_retail_II.xlsx`, 45,622,278 bytes.
- UCI lists the full file as 1,067,371 rows, Dec 1, 2009 to Dec 9, 2011, a UK based non-store online retailer selling unique all-occasion gift ware, with many customers being wholesalers. The file measured here matches that listing exactly: 1,067,371 rows, 2009-12-01 07:45:00 to 2011-12-09 12:50:00.

## File structure, measured, not assumed

The xlsx has two sheets:

- Year 2009-2010: 525,461 rows, 2009-12-01 to 2010-12-09, 4,383 distinct customers, 28,816 distinct invoices, 40 countries.
- Year 2010-2011: 541,910 rows, 2010-12-01 to 2011-12-09, 4,372 distinct customers, 25,900 distinct invoices, 38 countries.

Columns in both sheets, renamed in the database: Invoice, StockCode, Description, Quantity, InvoiceDate, Price, Customer ID, Country. In the database these become invoice_no, stock_code, description, quantity, invoice_date, unit_price, customer_id, country, plus revenue, year_month, year, and source_sheet.

Combined raw counts, measured: 1,067,371 rows, 5,942 distinct Customer IDs, 53,628 distinct Invoice values, 43 countries, 5,305 distinct StockCodes.

## Cleaning, measured at each step

- Step 1, cancellations: Invoice starting with C. 19,494 rows dropped. Cancellations are worth -1,526,667.86 GBP as recorded, and 99.99 percent of cancellation rows have Quantity below zero. Distinct cancellation invoices: 8,292.
- Step 2, Quantity <= 0 or Price <= 0: 6,207 rows dropped among non-cancellations. Price is 0 on 6,202 raw rows and negative on 5 raw rows. Quantity is negative on 22,950 raw rows and never 0 in the raw file. Among non-cancellations, 3,457 rows have Quantity <= 0 and 6,207 have Price <= 0, and every Quantity <= 0 row also has Price <= 0.
- Step 3, no Customer ID: 236,121 rows dropped. All 4,382 rows with a missing Description are in this group: every one of them has no Customer ID, so the cleaned table has zero missing Descriptions.
- Step 4, cross-sheet duplicates: the two sheets overlap Dec 1 to Dec 9, 2010, with 22,523 raw rows in each sheet in that window and the same 1,088 invoices in both. After steps 1 to 3, exactly 14,504 rows in the Year 2010-2011 sheet match a row in the Year 2009-2010 sheet on all 8 source columns, worth 311,878.00 GBP. The loader drops only that second copy, one row for one row per key. Without this step, Dec 2010 revenue would read 884,591.89 GBP and total revenue 17,743,429.18 GBP.
- Within-sheet exact duplicates are kept: 11,620 rows in the cleaned table match another row on all 8 source columns inside the same sheet. They cannot be told apart from genuine repeated lines, so they are reported, not dropped.
- Result: 791,045 cleaned lines, 17,431,551.18 GBP, 5,878 customers, 36,969 invoices, 41 countries, 4,631 StockCodes.

## Data quirks, handled honestly in the loader

- StockCode M means Manual, and StockCode POST means postage. They are not real products. Manual is 152,166.32 GBP in the cleaned data, postage is 124,648.04 GBP. Postage is the top line for Germany and France, Manual is the top line for EIRE.
- 624 StockCodes carry more than one Description in the cleaned data. The products table uses the most frequent description per StockCode, and the transactions table keeps the original line description.
- 13 customers bought from more than one country. The customers table uses each customer's most frequent country.
- 64 invoices have more than one distinct line timestamp. The invoices table uses the earliest line time per invoice.
- The largest single line is 80,995 units of PAPER CRAFT, LITTLE BIRDIE, 168,469.60 GBP, invoice 581483, customer 16446, on 2011-12-09. It is kept as recorded.
- The highest unit price is 10,953.50 GBP, a Manual line, invoice 502263, customer 12918, on 2010-03-23.
- The cheapest unit price is 0.001 GBP.
- December 2009 and December 2011 are partial months, as noted in the README.
- This project does not reuse the Dec 2010 to Dec 2011 slice from the earlier Python retail project (541,909 raw rows in that one sheet). The numbers here are from the full two-year file and will not match that slice.

## What was not done

- No rows were invented. No customer names were invented: the file has none.
- No churn classifier was built. RFM segments are descriptive buckets from stated thresholds.
- No forecast is presented as a prediction. No language model was trained or used.
- Nothing was published, posted, or signed into anywhere. Local build only.
