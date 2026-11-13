-- ============================================================
-- Step 5: CTEs and CASE. WITH clauses, RFM buckets, and segments.
--
-- The question: how do I break a hard question into steps, and
-- how do I sort customers into readable buckets?
--
-- What you will learn:
--   WITH gives a name to a step, called a common table
--   expression, or CTE. Later steps can use that name like a
--   table. CTEs make long queries readable, because each step
--   does one job and has a clear name.
--   CASE WHEN tests rows one condition at a time and returns
--   the first matching label. It is how you turn numbers into
--   buckets such as "Recent" or "Champions".
--   A CTE chain runs top to bottom: each CTE can use the ones
--   above it, but not the ones below it.
--
-- RFM, the idea behind this step:
--   Recency: days since the customer's last order, measured
--   from 2011-12-10, the day after the last order in the file.
--   Frequency: how many separate invoices the customer placed.
--   Monetary: total revenue from that customer, in GBP.
--   The buckets and segments below are descriptive labels from
--   the thresholds stated in each query. They are not a proven
--   churn predictor, and no churn model is built here.
--
-- Segment rules, checked in priority order, first match wins:
--   Champions: recency 90 days or less, 10 or more orders,
--     and 2,500 GBP or more. 771 customers.
--   Loyal: recency 180 days or less, 4 or more orders.
--     1,397 customers.
--   Potential Loyalists: recency 90 days or less, 2 to 3 orders.
--     658 customers.
--   New Customers: recency 30 days or less, exactly 1 order.
--     123 customers.
--   At Risk: recency over 180 days, 4 or more orders, and
--     1,000 GBP or more. 344 customers.
--   Hibernating: recency over 365 days, 2 or more orders.
--     561 customers.
--   One-time: exactly 1 order. 1,500 customers.
--   Occasional: everyone left. 524 customers.
--   The eight segments add to 5,878 customers, the full base.
-- ============================================================

-- Query 5.1: RFM per customer, in one CTE, with segment labels.
-- Step one (rfm) computes recency, frequency, and monetary per
-- customer. Recency uses julianday, which counts days between
-- two dates in SQLite. The final SELECT applies the segment
-- CASE in the priority order stated above, then counts
-- customers and revenue per segment. Champions are only 771
-- customers, 13.1 percent of the base, but they bring
-- 10,616,836.77 GBP, 60.9 percent of all revenue.
WITH rfm AS (
    SELECT
        customer_id,
        CAST(julianday('2011-12-10')
            - julianday(DATE(MAX(invoice_date))) AS INTEGER)
            AS recency_days,
        COUNT(DISTINCT invoice_no) AS orders,
        ROUND(SUM(revenue), 2) AS monetary_gbp
    FROM transactions
    GROUP BY customer_id
),
segmented AS (
    SELECT
        customer_id,
        recency_days,
        orders,
        monetary_gbp,
        CASE
            WHEN recency_days <= 90 AND orders >= 10
                AND monetary_gbp >= 2500 THEN 'Champions'
            WHEN recency_days <= 180 AND orders >= 4 THEN 'Loyal'
            WHEN recency_days <= 90 AND orders BETWEEN 2 AND 3
                THEN 'Potential Loyalists'
            WHEN recency_days <= 30 AND orders = 1
                THEN 'New Customers'
            WHEN recency_days > 180 AND orders >= 4
                AND monetary_gbp >= 1000 THEN 'At Risk'
            WHEN recency_days > 365 AND orders >= 2
                THEN 'Hibernating'
            WHEN orders = 1 THEN 'One-time'
            ELSE 'Occasional'
        END AS segment
    FROM rfm
)
SELECT
    segment,
    COUNT(*) AS customers,
    ROUND(SUM(monetary_gbp), 2) AS revenue_gbp,
    ROUND(100.0 * SUM(monetary_gbp)
        / (SELECT SUM(monetary_gbp) FROM segmented), 1)
        AS share_of_revenue_percent
FROM segmented
GROUP BY segment
ORDER BY revenue_gbp DESC;

-- Query 5.2: Customers sorted into recency buckets.
-- CASE WHEN checks the recency in days from top to bottom and
-- returns the first label that fits. A customer whose last
-- order was 10 days ago hits the first branch, "0-30 days".
-- A customer last seen over a year ago falls through to
-- "366+ days". There are 1,628 customers in the 0-30 day
-- bucket and 1,614 in the 366+ day bucket: the base is split
-- between very recent buyers and long quiet ones.
SELECT
    CASE
        WHEN recency_days <= 30 THEN '0-30 days'
        WHEN recency_days <= 90 THEN '31-90 days'
        WHEN recency_days <= 180 THEN '91-180 days'
        WHEN recency_days <= 365 THEN '181-365 days'
        ELSE '366+ days'
    END AS recency_bucket,
    COUNT(*) AS customers
FROM (
    SELECT
        customer_id,
        CAST(julianday('2011-12-10')
            - julianday(DATE(MAX(invoice_date))) AS INTEGER)
            AS recency_days
    FROM transactions
    GROUP BY customer_id
)
GROUP BY recency_bucket
ORDER BY customers DESC;

-- Query 5.3: Customers sorted into monetary bands.
-- Same CASE pattern, applied to total spend per customer.
-- Under 500 GBP is the biggest band, with 2,054 customers.
-- At the other end, 262 customers spent 10,000 GBP or more
-- each. The average customer spent 2,965.56 GBP in total,
-- but the median customer spent far less, so read the bands,
-- not just the average.
SELECT
    CASE
        WHEN monetary_gbp < 500 THEN 'Under 500'
        WHEN monetary_gbp < 1000 THEN '500-999'
        WHEN monetary_gbp < 2500 THEN '1000-2499'
        WHEN monetary_gbp < 10000 THEN '2500-9999'
        ELSE '10000+'
    END AS monetary_band_gbp,
    COUNT(*) AS customers
FROM (
    SELECT customer_id, SUM(revenue) AS monetary_gbp
    FROM transactions
    GROUP BY customer_id
)
GROUP BY monetary_band_gbp
ORDER BY customers DESC;

-- Query 5.4: Invoices sorted into basket size buckets.
-- Step one totals revenue per invoice. CASE sorts each invoice
-- into a basket bucket. Most invoices are small baskets, but
-- a few are very large, which is why the average basket of
-- 471.52 GBP sits above the median basket of 303.60 GBP.
SELECT
    CASE
        WHEN invoice_revenue < 100 THEN 'Under 100'
        WHEN invoice_revenue < 500 THEN '100-499'
        WHEN invoice_revenue < 1000 THEN '500-999'
        WHEN invoice_revenue < 5000 THEN '1000-4999'
        ELSE '5000+'
    END AS basket_band_gbp,
    COUNT(*) AS invoices
FROM (
    SELECT invoice_no, SUM(revenue) AS invoice_revenue
    FROM transactions
    GROUP BY invoice_no
)
GROUP BY basket_band_gbp
ORDER BY invoices DESC;

-- Query 5.5: Customers above the average total spend.
-- Step one (customer_totals) totals revenue per customer.
-- Step two (average_total) averages those totals: the average
-- customer spent 2,965.56 GBP across the whole file. The final
-- SELECT keeps customers above that average. Without CTEs,
-- this would need the same subquery written twice. With CTEs,
-- each step is written once and named.
WITH customer_totals AS (
    SELECT customer_id, SUM(revenue) AS monetary_gbp
    FROM transactions
    GROUP BY customer_id
),
average_total AS (
    SELECT AVG(monetary_gbp) AS avg_monetary
    FROM customer_totals
)
SELECT COUNT(*) AS customers_above_average
FROM customer_totals AS c, average_total AS a
WHERE c.monetary_gbp > a.avg_monetary;

-- Query 5.6: Each segment's share of all revenue, in one CTE chain.
-- Step one (rfm) computes recency, frequency, and monetary.
-- Step two (segmented) applies the same segment CASE as 5.1.
-- Step three (total) sums all revenue, 17,431,551.18 GBP.
-- The final SELECT divides each segment total by the grand
-- total. Champions hold 60.9 percent of revenue, Loyal holds
-- 19.4 percent, At Risk holds 6.7 percent, and the other five
-- segments together hold the remaining 12.9 percent.
WITH rfm AS (
    SELECT
        customer_id,
        CAST(julianday('2011-12-10')
            - julianday(DATE(MAX(invoice_date))) AS INTEGER)
            AS recency_days,
        COUNT(DISTINCT invoice_no) AS orders,
        ROUND(SUM(revenue), 2) AS monetary_gbp
    FROM transactions
    GROUP BY customer_id
),
segmented AS (
    SELECT
        monetary_gbp,
        CASE
            WHEN recency_days <= 90 AND orders >= 10
                AND monetary_gbp >= 2500 THEN 'Champions'
            WHEN recency_days <= 180 AND orders >= 4 THEN 'Loyal'
            WHEN recency_days <= 90 AND orders BETWEEN 2 AND 3
                THEN 'Potential Loyalists'
            WHEN recency_days <= 30 AND orders = 1
                THEN 'New Customers'
            WHEN recency_days > 180 AND orders >= 4
                AND monetary_gbp >= 1000 THEN 'At Risk'
            WHEN recency_days > 365 AND orders >= 2
                THEN 'Hibernating'
            WHEN orders = 1 THEN 'One-time'
            ELSE 'Occasional'
        END AS segment
    FROM rfm
),
total AS (
    SELECT SUM(monetary_gbp) AS all_revenue FROM segmented
)
SELECT
    s.segment,
    COUNT(*) AS customers,
    ROUND(SUM(s.monetary_gbp), 2) AS revenue_gbp,
    ROUND(100.0 * SUM(s.monetary_gbp) / t.all_revenue, 1)
        AS share_percent
FROM segmented AS s, total AS t
GROUP BY s.segment
ORDER BY revenue_gbp DESC;
