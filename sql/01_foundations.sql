-- ============================================================
-- Step 1: Foundations. SELECT, WHERE, ORDER BY, LIMIT, DISTINCT.
--
-- The question: what is in this table, and how do I look at just
-- the rows I care about?
--
-- What you will learn:
--   SELECT picks columns. FROM picks the table. WHERE filters rows.
--   ORDER BY sorts rows. LIMIT keeps only the first few rows.
--   DISTINCT removes duplicates, so you see each value once.
--   LIKE lets you search inside text. The percent sign means
--   "any characters can go here".
--
-- How to run this file: build the database first with
--   python3 scripts/load_database.py
-- then run this file against retail.db with any SQLite tool.
-- Every query below is independent. Run them in order.
--
-- The table: transactions, one row per cleaned order line.
-- 791,045 rows, from 2009-12-01 to 2011-12-09, revenue in GBP.
-- Cleaning is in scripts/load_database.py and in the
-- cleaning_funnel table: cancellations, zero or negative
-- Quantity or Price, rows with no Customer ID, and the second
-- copy of the Dec 1 to Dec 9, 2010 overlap between the two
-- UCI sheets were all removed and counted.
-- ============================================================

-- Query 1.1: The first 10 order lines ever recorded.
-- SELECT * means "give me every column". ORDER BY invoice_date
-- sorts oldest first, because ASC means ascending, smallest first.
-- LIMIT 10 stops after 10 rows, so the result stays small.
-- The first lines are from 2009-12-01, invoice 489434.
SELECT *
FROM transactions
ORDER BY invoice_date ASC
LIMIT 10;

-- Query 1.2: The 10 most recent order lines.
-- Same query, but DESC means descending, largest first, so the
-- newest dates come first. The newest lines are from 2011-12-09,
-- the last day in the file.
SELECT *
FROM transactions
ORDER BY invoice_date DESC
LIMIT 10;

-- Query 1.3: Ten lines from customer 18102, the top customer
-- by revenue, oldest first.
-- WHERE keeps only rows where the customer_id column matches
-- the number exactly. Customer ID is the only customer key
-- in this file. There are no customer names to search by.
SELECT invoice_no, invoice_date, stock_code, description,
       quantity, unit_price, revenue
FROM transactions
WHERE customer_id = 18102
ORDER BY invoice_date ASC
LIMIT 10;

-- Query 1.4: Every country in the cleaned data, listed once.
-- DISTINCT collapses repeats. There are 41 countries, not
-- 791,045, because most lines come from the same countries.
-- The United Kingdom dominates, as step 2 will show.
SELECT DISTINCT country
FROM transactions
ORDER BY country ASC;

-- Query 1.5: Every product code, listed once, with a count.
-- This uses DISTINCT in a different way: first we list the
-- distinct StockCodes, then we count them. There are 4,631
-- distinct StockCodes in the cleaned data.
SELECT COUNT(DISTINCT stock_code) AS distinct_products
FROM transactions;

-- Query 1.6: Ten lines with the word CAKESTAND in the description.
-- LIKE '%CAKESTAND%' means "the description contains the
-- letters CAKESTAND anywhere". The percent signs stand for any
-- characters before and after. Descriptions are in capital
-- letters in this file, so search in capitals.
-- The top product by revenue is REGENCY CAKESTAND 3 TIER.
SELECT invoice_no, invoice_date, stock_code, description,
       quantity, unit_price, revenue
FROM transactions
WHERE description LIKE '%CAKESTAND%'
ORDER BY invoice_date ASC
LIMIT 10;

-- Query 1.7: Lines from 2011-12-09, the last day in the file.
-- invoice_date holds a date and a time, so LIKE '2011-12-09%'
-- matches every time on that day. This day holds the largest
-- single line in the file: 80,995 units of PAPER CRAFT,
-- LITTLE BIRDIE, 168,469.60 GBP, invoice 581483.
SELECT invoice_no, stock_code, description, quantity,
       unit_price, revenue
FROM transactions
WHERE invoice_date LIKE '2011-12-09%'
ORDER BY revenue DESC
LIMIT 10;

-- Query 1.8: The most expensive lines by unit price.
-- ORDER BY unit_price DESC puts the highest price first.
-- The highest unit price is 10,953.50 GBP, a Manual line
-- (StockCode M), invoice 502263, customer 12918, on 2010-03-23.
-- Manual lines are adjustments, not real products, so read
-- this as a data quirk, not as a luxury product.
SELECT invoice_no, invoice_date, stock_code, description,
       quantity, unit_price, revenue, customer_id
FROM transactions
ORDER BY unit_price DESC
LIMIT 10;

-- Query 1.9: The cheapest lines by unit price.
-- ORDER BY unit_price ASC puts the lowest price first.
-- Prices here are all above zero, because rows with Price
-- <= 0 were removed in cleaning. The cheapest line costs
-- 0.001 GBP, a tenth of a penny, then 0.03 GBP. These are
-- tiny-priced lines, likely samples or price quirks, so
-- read them as data quirks, not as real selling prices.
SELECT invoice_no, invoice_date, stock_code, description,
       quantity, unit_price, revenue
FROM transactions
ORDER BY unit_price ASC
LIMIT 10;

-- Query 1.10: Lines with no description, the missing value test.
-- In SQL, missing values are called NULL. You test for them
-- with IS NULL, never with = NULL, because NULL is not equal
-- to anything. This query returns 0 rows, and that is a real
-- finding: all 4,382 raw rows with a missing Description also
-- had no Customer ID, so they were already removed in cleaning.
SELECT invoice_no, stock_code, quantity, unit_price
FROM transactions
WHERE description IS NULL
LIMIT 10;
