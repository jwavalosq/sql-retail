-- ============================================================
-- Step 3: Joins. INNER JOIN, LEFT JOIN, and a self-join.
--
-- The question: how do I combine this fact table with the
-- dimension tables built from it, and how do I check that
-- two tables agree?
--
-- What you will learn:
--   A JOIN matches rows from two tables on a shared value, here
--   the customer_id, the StockCode, the country, or the month.
--   ON states the matching rule.
--   INNER JOIN keeps only rows that match on both sides. If a
--   row has no match, it disappears from the result.
--   LEFT JOIN keeps every row from the left table, and fills
--   NULL where the right table has no match. Use LEFT JOIN when
--   "no match" is itself an answer you want to see.
--   A self-join joins a table to itself, with two different
--   aliases, to compare rows inside the same table.
--
-- The tables used here, all built by scripts/load_database.py:
--   transactions: one row per cleaned line, 791,045 rows.
--   invoices: one row per invoice, 36,969 rows.
--   customers: one row per Customer ID, 5,878 rows.
--   products: one row per StockCode, 4,631 rows.
--   countries: one row per country, 41 rows.
--   monthly_revenue: one row per month, 25 months.
-- ============================================================

-- Query 3.1: INNER JOIN to check the customers summary table.
-- We group transactions by customer, then join the result to
-- customers on customer_id. The difference column should be 0
-- on every row: the summary table matches the main table exactly.
-- INNER JOIN is right here because every customer in the main
-- table should also be in the summary table.
SELECT
    grouped.customer_id,
    ROUND(grouped.revenue_computed, 2) AS revenue_computed,
    ROUND(ref.total_revenue, 2) AS revenue_in_table,
    ROUND(grouped.revenue_computed - ref.total_revenue, 2)
        AS difference
FROM (
    SELECT customer_id, SUM(revenue) AS revenue_computed
    FROM transactions
    GROUP BY customer_id
) AS grouped
INNER JOIN customers AS ref
    ON grouped.customer_id = ref.customer_id
ORDER BY difference DESC
LIMIT 5;

-- Query 3.2: INNER JOIN to check the monthly summary table.
-- Same check as 3.1, but for months. The difference column
-- should be 0 on every row: 25 months, all matching.
SELECT
    grouped.year_month,
    ROUND(grouped.revenue_computed, 2) AS revenue_computed,
    ROUND(ref.total_revenue, 2) AS revenue_in_table,
    ROUND(grouped.revenue_computed - ref.total_revenue, 2)
        AS difference
FROM (
    SELECT year_month, SUM(revenue) AS revenue_computed
    FROM transactions
    GROUP BY year_month
) AS grouped
INNER JOIN monthly_revenue AS ref
    ON grouped.year_month = ref.year_month
ORDER BY grouped.year_month ASC;

-- Query 3.3: LEFT JOIN to find customers with no recent orders.
-- The left table is customers (all 5,878 customers). The right
-- side counts orders per customer since 2011-09-10, the last
-- 90 days of the file. LEFT JOIN keeps all 5,878 customers,
-- even those with zero recent orders. COALESCE turns the NULL
-- for "no match" into 0, so the result reads cleanly.
-- An INNER JOIN would have hidden the quiet customers, and
-- quiet customers are exactly who this question is about.
-- The reference date for recency in this project is 2011-12-10,
-- the day after the last order in the file.
SELECT
    c.customer_id,
    c.total_orders AS lifetime_orders,
    COALESCE(recent.recent_orders, 0) AS orders_last_90_days
FROM customers AS c
LEFT JOIN (
    SELECT customer_id, COUNT(DISTINCT invoice_no) AS recent_orders
    FROM transactions
    WHERE invoice_date >= '2011-09-10'
    GROUP BY customer_id
) AS recent
    ON c.customer_id = recent.customer_id
ORDER BY orders_last_90_days ASC, c.total_revenue DESC
LIMIT 10;

-- Query 3.4: JOIN products to their revenue, with customer reach.
-- products is a dimension table built from transactions, so this
-- join checks that the product table and the line table agree,
-- and it adds a useful column: how many distinct customers
-- bought each product. The top product, REGENCY CAKESTAND
-- 3 TIER, was bought by many customers, not just one big buyer.
SELECT
    p.stock_code,
    p.description,
    p.total_lines,
    p.distinct_customers,
    ROUND(p.total_revenue, 2) AS revenue_gbp
FROM products AS p
INNER JOIN (
    SELECT stock_code, SUM(revenue) AS revenue_check
    FROM transactions
    GROUP BY stock_code
) AS t
    ON p.stock_code = t.stock_code
ORDER BY p.total_revenue DESC
LIMIT 10;

-- Query 3.5: JOIN countries to customers, to see where the
-- customer base sits.
-- countries holds one row per country. Joining it to customers
-- on the country name shows how many customers each country
-- has, and what they spent on average. The United Kingdom has
-- the most customers by far, but the average spend per customer
-- is higher in some smaller countries, so do not confuse a big
-- total with a big average.
SELECT
    co.country,
    co.distinct_customers AS customers,
    ROUND(co.total_revenue, 2) AS revenue_gbp,
    ROUND(co.total_revenue / co.distinct_customers, 2)
        AS revenue_per_customer_gbp
FROM countries AS co
ORDER BY co.total_revenue DESC
LIMIT 10;

-- Query 3.6: Self-join to find repeated lines inside one invoice.
-- We join transactions to itself, using aliases a and b.
-- The ON rule matches rows with the same invoice, the same
-- StockCode, the same Quantity, the same Price, and the same
-- date. The condition a.rowid < b.rowid keeps each pair once,
-- and stops a row from pairing with itself. Without it, every
-- row would match itself and every pair would appear twice.
-- This answers a real question about this file: the same line
-- sometimes appears twice inside one invoice. Those within-sheet
-- repeats are kept in the cleaned data, 11,620 rows, because
-- they cannot be told apart from genuine repeated lines, so
-- this query shows them instead of hiding them.
SELECT
    a.invoice_no,
    a.stock_code,
    a.description,
    a.quantity,
    a.unit_price,
    COUNT(*) AS pairs_in_invoice
FROM transactions AS a
INNER JOIN transactions AS b
    ON a.invoice_no = b.invoice_no
    AND a.stock_code = b.stock_code
    AND a.quantity = b.quantity
    AND a.unit_price = b.unit_price
    AND a.invoice_date = b.invoice_date
    AND a.rowid < b.rowid
GROUP BY a.invoice_no, a.stock_code, a.description,
         a.quantity, a.unit_price
ORDER BY pairs_in_invoice DESC
LIMIT 20;
