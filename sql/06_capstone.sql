-- ============================================================
-- Step 6: Capstone. Five recruiter style interview questions.
--
-- Each question below is the kind of question a hiring manager
-- asks a data analyst: a plain business question that needs one
-- clear query and one honest answer. Each query is self contained
-- and well commented, so you can explain every line out loud.
--
-- The answers, in short:
--   1. The best month is 2010-11, with 1,172,336.04 GBP,
--      6.7 percent of all revenue. November leads in both
--      years, so this is Christmas shopping, not a one-off.
--   2. The top 10 customers bring 2,787,566.23 GBP, 16.0
--      percent of all revenue. The top customer, 18102,
--      brings 580,987.04 GBP alone, 3.3 percent.
--   3. Outside the United Kingdom, EIRE matters most, with
--      616,897.33 GBP, 3.5 percent of all revenue and 20.7
--      percent of non-UK revenue.
--   4. Repeat buyers are 4,255 customers, 72.4 percent of
--      the base, and they bring 96.8 percent of revenue.
--      One-time buyers are 1,623 customers, 27.6 percent,
--      and they bring only 3.2 percent of revenue.
--   5. The Dec 2009 first-order cohort is the largest, with
--      955 customers, and 91.2 percent of them ordered again.
--      Later cohorts return less often, but they also had
--      less time to return, so do not read that fall as
--      pure churn.
-- ============================================================

-- Capstone question 1: Which month made the most money, and why?
-- How it works: total revenue per month, order by revenue
-- descending, keep the first row, and add its share of the
-- 17,431,551.18 GBP total. The answer is 2010-11, with
-- 1,172,336.04 GBP, 6.7 percent of all revenue. The why is in
-- the runner up: 2011-11 is second with 1,161,817.38 GBP, and
-- October is third and fourth in both years, so the peak
-- repeats every autumn. That is Christmas shopping, not a
-- single big order. The honest follow up is that Dec 2009
-- and Dec 2011 are partial months, so they cannot beat a
-- full November even in a strong December.
SELECT
    year_month,
    ROUND(total_revenue, 2) AS revenue_gbp,
    ROUND(100.0 * total_revenue
        / (SELECT SUM(revenue) FROM transactions), 1)
        AS share_percent
FROM monthly_revenue
ORDER BY total_revenue DESC
LIMIT 1;

-- Capstone question 2: Who are the top 10 customers by revenue,
-- and what share of all revenue do they bring together?
-- How it works: total revenue per customer in a CTE, rank
-- them with ROW_NUMBER, keep ranks 1 to 10, then sum those
-- ten totals and divide by the grand total. The top 10 bring
-- 2,787,566.23 GBP, 16.0 percent of all revenue. The top
-- customer alone, 18102, brings 580,987.04 GBP, 3.3 percent.
-- A recruiter likes this question because it tests ranking,
-- filtering, and turning rows into one comparison number.
-- The risk to name out loud is concentration: one customer
-- leaving would not sink the shop, but the top 10 together
-- are one sixth of revenue.
WITH customer_totals AS (
    SELECT customer_id, SUM(revenue) AS monetary_gbp
    FROM transactions
    GROUP BY customer_id
),
ranked AS (
    SELECT
        customer_id,
        monetary_gbp,
        ROW_NUMBER() OVER (ORDER BY monetary_gbp DESC) AS rank_num
    FROM customer_totals
),
top10 AS (
    SELECT customer_id, monetary_gbp
    FROM ranked
    WHERE rank_num <= 10
)
SELECT
    (SELECT COUNT(*) FROM top10) AS top_customers,
    ROUND(SUM(monetary_gbp), 2) AS top10_revenue_gbp,
    ROUND(100.0 * SUM(monetary_gbp)
        / (SELECT SUM(revenue) FROM transactions), 1)
        AS share_percent,
    ROUND(MAX(monetary_gbp), 2) AS top_customer_revenue_gbp
FROM top10;

-- Capstone question 3: Which country outside the United Kingdom
-- matters most, and how big is it really?
-- How it works: total revenue per country, exclude the United
-- Kingdom, order biggest first, keep the first row, and add
-- two shares: its share of all revenue, and its share of
-- non-UK revenue. The answer is EIRE, with 616,897.33 GBP,
-- 3.5 percent of all revenue, but 20.7 percent of the
-- 2,987,059.45 GBP that comes from outside the UK. The honest
-- follow up is scale: even the best non-UK country is small
-- next to the UK at 14,444,491.73 GBP, 82.9 percent of all
-- revenue. This shop is a UK shop with export sales, not a
-- balanced international business.
SELECT
    country,
    ROUND(total_revenue, 2) AS revenue_gbp,
    ROUND(100.0 * total_revenue
        / (SELECT SUM(revenue) FROM transactions), 1)
        AS share_of_all_revenue_percent,
    ROUND(100.0 * total_revenue
        / (SELECT SUM(revenue) FROM transactions
           WHERE country <> 'United Kingdom'), 1)
        AS share_of_non_uk_revenue_percent
FROM countries
WHERE country <> 'United Kingdom'
ORDER BY total_revenue DESC
LIMIT 1;

-- Capstone question 4: Do repeat buyers or one-time buyers
-- drive this business?
-- How it works: count distinct invoices per customer in a CTE,
-- then CASE splits customers into Repeat (2 or more invoices)
-- and One-time (exactly 1 invoice). GROUP BY counts customers
-- and sums revenue per group. Repeat buyers are 4,255
-- customers, 72.4 percent of the base, and they bring
-- 16,868,755.83 GBP, 96.8 percent of revenue. One-time buyers
-- are 1,623 customers, 27.6 percent, and they bring 562,795.35
-- GBP, 3.2 percent. The business runs on buyers who come back.
SELECT
    CASE WHEN orders >= 2 THEN 'Repeat buyers'
         ELSE 'One-time buyers' END AS buyer_type,
    COUNT(*) AS customers,
    ROUND(SUM(monetary_gbp), 2) AS revenue_gbp,
    ROUND(100.0 * SUM(monetary_gbp)
        / (SELECT SUM(revenue) FROM transactions), 1)
        AS share_of_revenue_percent
FROM (
    SELECT
        customer_id,
        COUNT(DISTINCT invoice_no) AS orders,
        SUM(revenue) AS monetary_gbp
    FROM transactions
    GROUP BY customer_id
)
GROUP BY buyer_type
ORDER BY revenue_gbp DESC;

-- Capstone question 5: How well does each first-order cohort
-- come back?
-- How it works: step one (first_orders) finds each customer's
-- first order month and counts their total invoices. Step two
-- groups by that first month, counts customers, counts how
-- many placed more than one invoice, and divides to get a
-- return rate. The Dec 2009 cohort is the largest, with 955
-- customers, and 91.2 percent of them ordered again. Later
-- cohorts return less often: the 2010-06 cohort returns at
-- 75.9 percent. Do not present that fall as pure churn,
-- because later cohorts had less calendar time left in the
-- file to place a second order. The file ends on 2011-12-09,
-- so a customer who first bought in late 2011 barely had a
-- chance to return inside this data.
WITH first_orders AS (
    SELECT
        customer_id,
        strftime('%Y-%m', MIN(invoice_date)) AS first_month,
        COUNT(DISTINCT invoice_no) AS orders
    FROM transactions
    GROUP BY customer_id
)
SELECT
    first_month,
    COUNT(*) AS customers,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) AS returned_customers,
    ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)
        / COUNT(*), 1) AS return_rate_percent
FROM first_orders
GROUP BY first_month
ORDER BY first_month ASC;
