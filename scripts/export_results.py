"""Run the key queries and write their outputs to results/ as CSVs.

Run from the project root, after scripts/load_database.py:
    python3 scripts/export_results.py

The CSVs feed the charts in scripts/make_charts.py and let a reader
check every headline number without running SQL by hand.
"""

import csv
import os
import sqlite3

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DB_PATH = os.path.join(ROOT, "retail.db")
RESULTS = os.path.join(ROOT, "results")

QUERIES = {
    "revenue_by_month.csv": """
        SELECT year_month, lines, distinct_invoices,
               distinct_customers,
               ROUND(total_revenue, 2) AS revenue_gbp
        FROM monthly_revenue ORDER BY year_month ASC
    """,
    "revenue_by_country.csv": """
        SELECT country, total_lines, distinct_customers,
               distinct_invoices,
               ROUND(total_revenue, 2) AS revenue_gbp
        FROM countries ORDER BY total_revenue DESC
    """,
    "revenue_by_year.csv": """
        SELECT year, COUNT(*) AS lines,
               ROUND(SUM(revenue), 2) AS revenue_gbp
        FROM transactions GROUP BY year ORDER BY year ASC
    """,
    "top_products.csv": """
        SELECT stock_code, description, total_lines,
               total_quantity,
               ROUND(total_revenue, 2) AS revenue_gbp
        FROM products ORDER BY total_revenue DESC LIMIT 10
    """,
    "top_customers.csv": """
        SELECT customer_id, total_orders, total_lines,
               ROUND(total_revenue, 2) AS revenue_gbp
        FROM customers ORDER BY total_revenue DESC LIMIT 10
    """,
    "revenue_by_segment.csv": """
        WITH rfm AS (
            SELECT customer_id,
                CAST(julianday('2011-12-10')
                    - julianday(DATE(MAX(invoice_date))) AS INTEGER)
                    AS recency_days,
                COUNT(DISTINCT invoice_no) AS orders,
                ROUND(SUM(revenue), 2) AS monetary_gbp
            FROM transactions GROUP BY customer_id
        ),
        segmented AS (
            SELECT monetary_gbp,
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
        SELECT segment, COUNT(*) AS customers,
               ROUND(SUM(monetary_gbp), 2) AS revenue_gbp
        FROM segmented GROUP BY segment ORDER BY revenue_gbp DESC
    """,
    "monthly_running_total.csv": """
        SELECT year_month, revenue_gbp,
               ROUND(SUM(revenue_gbp) OVER (
                   ORDER BY year_month ASC
                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
               ), 2) AS running_total_gbp
        FROM (SELECT year_month, ROUND(total_revenue, 2) AS revenue_gbp
              FROM monthly_revenue)
        ORDER BY year_month ASC
    """,
    "top_product_per_country.csv": """
        SELECT country, stock_code, description, revenue_gbp
        FROM (
            SELECT country, stock_code, description,
                   ROUND(SUM(revenue), 2) AS revenue_gbp,
                   ROW_NUMBER() OVER (
                       PARTITION BY country ORDER BY SUM(revenue) DESC
                   ) AS row_num
            FROM transactions
            GROUP BY country, stock_code, description
        )
        WHERE row_num = 1 ORDER BY revenue_gbp DESC
    """,
    "repeat_vs_onetime.csv": """
        SELECT
            CASE WHEN orders >= 2 THEN 'Repeat buyers'
                 ELSE 'One-time buyers' END AS buyer_type,
            COUNT(*) AS customers,
            ROUND(SUM(monetary_gbp), 2) AS revenue_gbp
        FROM (
            SELECT customer_id,
                   COUNT(DISTINCT invoice_no) AS orders,
                   SUM(revenue) AS monetary_gbp
            FROM transactions GROUP BY customer_id
        )
        GROUP BY buyer_type ORDER BY revenue_gbp DESC
    """,
    "cohort_first_month.csv": """
        WITH first_orders AS (
            SELECT customer_id,
                   strftime('%Y-%m', MIN(invoice_date)) AS first_month,
                   COUNT(DISTINCT invoice_no) AS orders
            FROM transactions GROUP BY customer_id
        )
        SELECT first_month, COUNT(*) AS customers,
               SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)
                   AS returned_customers,
               ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)
                   / COUNT(*), 1) AS return_rate_percent
        FROM first_orders GROUP BY first_month ORDER BY first_month ASC
    """,
    "cleaning_funnel.csv": """
        SELECT step, rows_remaining, rows_dropped, note
        FROM cleaning_funnel
    """,
}


def main():
    os.makedirs(RESULTS, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    for filename, sql in QUERIES.items():
        cur = con.execute(sql)
        columns = [d[0] for d in cur.description]
        rows = cur.fetchall()
        path = os.path.join(RESULTS, filename)
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(columns)
            writer.writerows(rows)
        print(filename, "=", len(rows), "rows")
    con.close()


if __name__ == "__main__":
    main()
