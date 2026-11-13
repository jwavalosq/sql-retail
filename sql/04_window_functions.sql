-- ============================================================
-- Step 4: Window functions. ROW_NUMBER, RANK, running totals, LAG.
--
-- The question: how do I rank things, track a running total, and
-- compare each month with the month before, without collapsing rows?
--
-- What you will learn:
--   A window function computes a value across a set of rows that
--   are related to the current row, but it keeps every row in the
--   result. That is the big difference from GROUP BY, which
--   collapses each group into one row.
--   OVER defines the window. PARTITION BY splits rows into
--   separate groups inside the window. ORDER BY inside OVER
--   sets the order used for ranking or for running totals.
--   ROW_NUMBER gives each row a unique number: 1, 2, 3, with no
--   ties. RANK gives tied rows the same number, then skips the
--   next numbers. If two rows tie for rank 1, the next rank is 3.
--   LAG pulls a value from the previous row in the window, so
--   you can compute a change from one month to the next.
--   A running total is SUM over all rows up to the current row.
-- ============================================================

-- Query 4.1: Rank products by revenue, with RANK.
-- First we total revenue per product in a subquery. Then RANK
-- orders those totals from biggest to smallest. REGENCY
-- CAKESTAND 3 TIER is rank 1 with 278,150.20 GBP. No two
-- products tie at the top here, so RANK and ROW_NUMBER agree
-- on the first rows.
SELECT
    stock_code,
    description,
    revenue_gbp,
    RANK() OVER (ORDER BY revenue_gbp DESC) AS rank_by_revenue
FROM (
    SELECT stock_code, description,
           ROUND(SUM(revenue), 2) AS revenue_gbp
    FROM transactions
    GROUP BY stock_code, description
)
ORDER BY rank_by_revenue ASC
LIMIT 10;

-- Query 4.2: Rank products with ROW_NUMBER, top 10 only.
-- ROW_NUMBER never ties: even if two products had the same
-- revenue, they would get different numbers. The outer query
-- keeps only rows numbered 1 to 10. This is the standard
-- "top N" pattern with window functions.
SELECT stock_code, description, revenue_gbp, row_num
FROM (
    SELECT
        stock_code,
        description,
        ROUND(SUM(revenue), 2) AS revenue_gbp,
        ROW_NUMBER() OVER (ORDER BY SUM(revenue) DESC) AS row_num
    FROM transactions
    GROUP BY stock_code, description
)
WHERE row_num <= 10;

-- Query 4.3: The top product in each country.
-- PARTITION BY country restarts the numbering in every country.
-- Inside each country, products are ordered by revenue
-- descending, so row 1 is the best product of that country.
-- The outer query keeps only row 1 per country.
-- Read this with care: in Germany and France the top line is
-- StockCode POST, postage, and in EIRE it is StockCode M,
-- Manual. Those are not real products, they are postage and
-- adjustments, and they top the list because small countries
-- have small product totals. In the United Kingdom the top
-- product is a real one: WHITE HANGING HEART T-LIGHT HOLDER.
SELECT country, stock_code, description, revenue_gbp
FROM (
    SELECT
        country,
        stock_code,
        description,
        ROUND(SUM(revenue), 2) AS revenue_gbp,
        ROW_NUMBER() OVER (
            PARTITION BY country ORDER BY SUM(revenue) DESC
        ) AS row_num
    FROM transactions
    GROUP BY country, stock_code, description
)
WHERE row_num = 1
ORDER BY revenue_gbp DESC;

-- Query 4.4: Running total of revenue by month.
-- The subquery totals revenue per month. The window SUM adds
-- up every month from the first month through the current month,
-- so the last row reaches the full total of 17,431,551.18 GBP.
-- The window frame ROWS BETWEEN UNBOUNDED PRECEDING AND
-- CURRENT ROW means "from the start of the list up to this row".
SELECT
    year_month,
    revenue_gbp,
    ROUND(SUM(revenue_gbp) OVER (
        ORDER BY year_month ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) AS running_total_gbp
FROM (
    SELECT year_month, ROUND(SUM(revenue), 2) AS revenue_gbp
    FROM transactions
    GROUP BY year_month
)
ORDER BY year_month ASC;

-- Query 4.5: Month over month change, using LAG on months present.
-- LAG(revenue_gbp) pulls the previous row's revenue, which is
-- the previous month that appears in the table. The change
-- column is this month minus last month. The percent change
-- divides the change by last month and multiplies by 100.
-- Honest note: every month from Dec 2009 to Dec 2011 appears
-- in this table, all 25 months, so "previous month" here is
-- the calendar month before, but Dec 2009 and Dec 2011 are
-- partial months, so their changes are not like for like.
SELECT
    year_month,
    revenue_gbp,
    LAG(revenue_gbp) OVER (ORDER BY year_month ASC)
        AS previous_month_revenue,
    ROUND(revenue_gbp
        - LAG(revenue_gbp) OVER (ORDER BY year_month ASC), 2)
        AS change_from_previous,
    ROUND(
        100.0 * (revenue_gbp
        - LAG(revenue_gbp) OVER (ORDER BY year_month ASC))
        / LAG(revenue_gbp) OVER (ORDER BY year_month ASC),
        1
    ) AS percent_change
FROM (
    SELECT year_month, ROUND(SUM(revenue), 2) AS revenue_gbp
    FROM transactions
    GROUP BY year_month
)
ORDER BY year_month ASC;

-- Query 4.6: True month over month change, with every calendar month.
-- WITH RECURSIVE builds a list of every month from 2009-12 to
-- 2011-12, one row per month, even months with zero revenue.
-- LEFT JOIN adds the real totals, with COALESCE turning missing
-- totals into 0. Here all 25 months have revenue, so this query
-- matches 4.5, and that match is itself the check: no month is
-- missing from the file. If a month were missing, this version
-- would show it as 0 instead of hiding it.
WITH RECURSIVE all_months(year_month) AS (
    SELECT '2009-12'
    UNION ALL
    SELECT strftime('%Y-%m', date(year_month || '-01', '+1 month'))
    FROM all_months
    WHERE year_month < '2011-12'
),
monthly AS (
    SELECT year_month, ROUND(SUM(revenue), 2) AS revenue_gbp
    FROM transactions
    GROUP BY year_month
)
SELECT
    a.year_month,
    COALESCE(m.revenue_gbp, 0) AS revenue_gbp,
    LAG(COALESCE(m.revenue_gbp, 0)) OVER (ORDER BY a.year_month ASC)
        AS previous_month_revenue,
    COALESCE(m.revenue_gbp, 0)
        - LAG(COALESCE(m.revenue_gbp, 0)) OVER (ORDER BY a.year_month ASC)
        AS change_from_previous
FROM all_months AS a
LEFT JOIN monthly AS m
    ON a.year_month = m.year_month
ORDER BY a.year_month ASC;

-- Query 4.7: Each customer's most recent order.
-- PARTITION BY customer_id restarts the numbering for each
-- customer. ORDER BY invoice_date DESC puts the newest order
-- first inside each group, so row 1 is that customer's latest
-- order. The outer query keeps only row 1 per customer.
-- This is a classic interview pattern: "latest row per group".
SELECT customer_id, invoice_no, invoice_date, total_revenue
FROM (
    SELECT
        customer_id,
        invoice_no,
        invoice_date,
        total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id ORDER BY invoice_date DESC
        ) AS row_num
    FROM invoices
)
WHERE row_num = 1
ORDER BY invoice_date DESC
LIMIT 10;
