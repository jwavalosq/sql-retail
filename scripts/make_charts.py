"""Build 8 charts from results/ CSVs, saving copies to charts/ and docs/charts/.

Run from the project root, after scripts/export_results.py:
    python3 scripts/make_charts.py

Only matplotlib is used. Titles are plain words, no em-dash anywhere.
"""

import csv
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RESULTS = os.path.join(ROOT, "results")
CHARTS = os.path.join(ROOT, "charts")
DOC_CHARTS = os.path.join(ROOT, "docs", "charts")


def read_csv(name):
    with open(os.path.join(RESULTS, name), newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def save(fig, name):
    fig.tight_layout()
    fig.savefig(os.path.join(CHARTS, name), dpi=150)
    fig.savefig(os.path.join(DOC_CHARTS, name), dpi=150)
    plt.close(fig)
    print(name)


def barh_chart(rows, label_key, value_key, title, xlabel, filename):
    rows = list(rows)
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.barh([str(r[label_key]) for r in rows][::-1],
            [float(r[value_key]) for r in rows][::-1])
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.grid(axis="x", alpha=0.3)
    save(fig, filename)


def bar_chart(rows, label_key, value_key, title, ylabel, filename, rotate=45):
    fig, ax = plt.subplots(figsize=(10, 6))
    ax.bar([str(r[label_key]) for r in rows],
           [float(r[value_key]) for r in rows])
    ax.set_title(title)
    ax.set_ylabel(ylabel)
    ax.tick_params(axis="x", rotation=rotate)
    ax.grid(axis="y", alpha=0.3)
    save(fig, filename)


def line_chart(rows, label_key, value_key, title, ylabel, filename):
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.plot([str(r[label_key]) for r in rows],
            [float(r[value_key]) for r in rows], marker="o", markersize=3)
    ax.set_title(title)
    ax.set_ylabel(ylabel)
    ax.tick_params(axis="x", rotation=45)
    ax.grid(alpha=0.3)
    save(fig, filename)


def main():
    os.makedirs(CHARTS, exist_ok=True)
    os.makedirs(DOC_CHARTS, exist_ok=True)

    monthly = read_csv("revenue_by_month.csv")
    line_chart(monthly, "year_month", "revenue_gbp",
               "Monthly revenue, Dec 2009 to Dec 2011 (GBP)",
               "Revenue (GBP)", "01_monthly_revenue.png")

    countries = read_csv("revenue_by_country.csv")[:10]
    barh_chart(countries, "country", "revenue_gbp",
               "Top 10 countries by revenue (GBP)",
               "Revenue (GBP)", "02_top_countries.png")

    products = read_csv("top_products.csv")
    barh_chart(products, "description", "revenue_gbp",
               "Top 10 products by revenue (GBP)",
               "Revenue (GBP)", "03_top_products.png")

    years = read_csv("revenue_by_year.csv")
    bar_chart(years, "year", "revenue_gbp",
              "Revenue by year (GBP). 2009 and 2011 are partial years",
              "Revenue (GBP)", "04_revenue_by_year.png", rotate=0)

    segments = read_csv("revenue_by_segment.csv")
    bar_chart(segments, "segment", "revenue_gbp",
              "Revenue by RFM segment (GBP)",
              "Revenue (GBP)", "05_rfm_segments.png", rotate=30)

    running = read_csv("monthly_running_total.csv")
    line_chart(running, "year_month", "running_total_gbp",
               "Running total revenue by month (GBP)",
               "Cumulative revenue (GBP)", "06_running_total.png")

    repeat = read_csv("repeat_vs_onetime.csv")
    bar_chart(repeat, "buyer_type", "revenue_gbp",
              "Repeat buyers versus one-time buyers, revenue (GBP)",
              "Revenue (GBP)", "07_repeat_vs_onetime.png", rotate=0)

    customers = read_csv("top_customers.csv")
    barh_chart(customers, "customer_id", "revenue_gbp",
               "Top 10 customers by revenue (GBP)",
               "Revenue (GBP)", "08_top_customers.png")


if __name__ == "__main__":
    main()
