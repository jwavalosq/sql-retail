-- ============================================================
-- Step 2: Aggregations. COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING.
--
-- The question: how much money did this shop make, who bought
-- the most, and which months, countries, and products dominate?
--
-- What you will learn:
--   COUNT counts rows. SUM adds numbers. AVG takes an average.
--   MIN and MAX find the smallest and largest values.
--   GROUP BY splits rows into groups, one result row per group.
--   HAVING filters groups, the way WHERE filters single rows.
--   You must use HAVING for group filters, because WHERE runs
--   before grouping and cannot see group totals.
--
-- A warning about averages: AVG hides the shape of the data.
-- Always pair an average with a MIN and a MAX, or a count, so
-- you can see whether the average is typical or pulled by
-- outliers. The average basket here is pulled up by a few very
-- large wholesale orders, as query 2.7 shows.
--
-- All revenue is in GBP, as Quantity times Price, on cleaned
-- lines only: 791,045 rows, 2009-12-01 to 2011-12-09.
-- ============================================================

-- Query 2.1: How many order lines are in the cleaned dataset?
-- COUNT(*) counts every row in the table. The answer is 791,045.
SELECT COUNT(*) AS total_lines
FROM transactions;

-- Query 2.2: How much revenue did the cleaned lines make?
-- SUM(revenue) adds up every line. The answer is 17,431,551.18 GBP.
-- Revenue is Quantity times Price, in GBP, on cleaned lines only.
-- Cancellations, zero or negative rows, rows with no Customer ID,
-- and the second copy of the Dec 2010 sheet overlap are excluded.
SELECT ROUND(SUM(revenue), 2) AS total_revenue_gbp
FROM transactions;

-- Query 2.3: Revenue by year, oldest first.
-- GROUP BY year makes one group per year. 2010 leads, then 2011,
-- then 2009, but read the years with care: 2009 is only December,
-- one month, and 2011 ends on Dec 9, so it is missing most of
-- December. The full years are not equal in length.
-- 2009: 686,654.16. 2010: 8,406,185.00. 2011: 8,338,712.01.
SELECT year, COUNT(*) AS lines,
       ROUND(SUM(revenue), 2) AS revenue_gbp
FROM transactions
GROUP BY year
ORDER BY year ASC;

-- Query 2.4: The 5 best months by revenue.
-- GROUP BY year_month makes one group per calendar month.
-- November leads in both full years: 2010-11 with 1,172,336.04
-- GBP, then 2011-11 with 1,161,817.38 GBP. Christmas shopping
-- is the story here, and it repeats.
SELECT year_month, COUNT(*) AS lines,
       ROUND(SUM(revenue), 2) AS revenue_gbp
FROM transactions
GROUP BY year_month
ORDER BY revenue_gbp DESC
LIMIT 5;

-- Query 2.5: Revenue by country, biggest first.
-- The United Kingdom leads by far: 14,444,491.73 GBP, about
-- 82.9 percent of all revenue. Outside the UK, EIRE leads with
-- 616,897.33 GBP, then the Netherlands with 554,039.74 GBP,
-- then Germany with 425,578.38 GBP.
SELECT country, COUNT(*) AS lines,
       COUNT(DISTINCT customer_id) AS customers,
       ROUND(SUM(revenue), 2) AS revenue_gbp
FROM transactions
GROUP BY country
ORDER BY revenue_gbp DESC
LIMIT 10;

-- Query 2.6: The 10 best products by revenue.
-- GROUP BY stock_code and description together, because the
-- same StockCode can carry more than one description in the
-- file. The leader is REGENCY CAKESTAND 3 TIER with 278,150.20
-- GBP, then WHITE HANGING HEART T-LIGHT HOLDER with 247,389.21 GBP.
-- StockCode M, Manual, appears in this list: it is an adjustment,
-- not a real product, so it is flagged, not hidden.
SELECT stock_code, description, COUNT(*) AS lines,
       SUM(quantity) AS units_sold,
       ROUND(SUM(revenue), 2) AS revenue_gbp
FROM transactions
GROUP BY stock_code, description
ORDER BY revenue_gbp DESC
LIMIT 10;

-- Query 2.7: Basket size: revenue per invoice.
-- First we total revenue per invoice in a subquery, then we
-- average those invoice totals. The average basket is 471.52 GBP,
-- but the median basket is 303.60 GBP and the largest invoice is
-- far bigger, so the average is pulled up by large wholesale
-- orders. Always say the median next to the average.
SELECT
    COUNT(*) AS invoices,
    ROUND(AVG(invoice_revenue), 2) AS avg_basket_gbp,
    ROUND(MIN(invoice_revenue), 2) AS smallest_basket_gbp,
    ROUND(MAX(invoice_revenue), 2) AS largest_basket_gbp
FROM (
    SELECT invoice_no, SUM(revenue) AS invoice_revenue
    FROM transactions
    GROUP BY invoice_no
);

-- Query 2.8: Lines per invoice, on average.
-- Same pattern as 2.7, but counting lines instead of money.
-- The average invoice holds 21.4 lines. An invoice here is one
-- order: one Invoice number, one customer, one country.
SELECT
    ROUND(AVG(lines_per_invoice), 1) AS avg_lines_per_invoice,
    MIN(lines_per_invoice) AS fewest_lines,
    MAX(lines_per_invoice) AS most_lines
FROM (
    SELECT invoice_no, COUNT(*) AS lines_per_invoice
    FROM transactions
    GROUP BY invoice_no
);

-- Query 2.9: The date range of the cleaned dataset.
-- MIN finds the earliest date, MAX finds the latest date.
-- The range is 2009-12-01 07:45:00 to 2011-12-09 12:50:00.
SELECT MIN(invoice_date) AS earliest, MAX(invoice_date) AS latest
FROM transactions;

-- Query 2.10: Countries with more than 100,000 GBP of revenue.
-- HAVING SUM(revenue) > 100000 keeps only groups above that
-- bar. WHERE could not do this, because WHERE cannot see a
-- group total. Eight countries clear 100,000 GBP.
SELECT country, ROUND(SUM(revenue), 2) AS revenue_gbp
FROM transactions
GROUP BY country
HAVING SUM(revenue) > 100000
ORDER BY revenue_gbp DESC;

-- Query 2.11: Customers with more than 100 separate invoices.
-- HAVING COUNT(DISTINCT invoice_no) > 100 keeps only the most
-- frequent buyers. Customer 14911 leads with 398 invoices.
-- These are wholesalers buying again and again, not one-off
-- gift buyers.
SELECT customer_id, COUNT(DISTINCT invoice_no) AS invoices,
       ROUND(SUM(revenue), 2) AS revenue_gbp
FROM transactions
GROUP BY customer_id
HAVING COUNT(DISTINCT invoice_no) > 100
ORDER BY invoices DESC;

-- Query 2.12: The cleaning funnel, as a table.
-- The cleaning_funnel table was written by the loader, one row
-- per cleaning step, so you can quote the funnel from SQL.
-- Raw: 1,067,371. After cancellations: 1,047,877. After
-- Quantity and Price: 1,041,670. After Customer ID:
-- 805,549. After cross-sheet dedup: 791,045.
-- The biggest drop is the Customer ID step: 236,121 rows.
SELECT step, rows_remaining, rows_dropped, note
FROM cleaning_funnel;
