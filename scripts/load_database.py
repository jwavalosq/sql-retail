"""Build retail.db from the full UCI Online Retail II file.

Run from the project root:
    python3 scripts/load_database.py

Source:
    UCI Machine Learning Repository, Online Retail II, dataset 502,
    creator Daqing Chen, DOI 10.24432/C5CG6D.
    Page: https://archive.ics.uci.edu/dataset/502/online+retail+ii
    Direct download: https://archive.ics.uci.edu/static/public/502/online+retail+ii.zip

The zip holds one xlsx with two sheets, Year 2009-2010 and
Year 2010-2011. The two sheets overlap: both cover Dec 1 to Dec 9,
2010. The same 14,504 cleaned rows appear in both sheets, so a
naive concatenation double counts that week. Step 4 below removes
only the second copy, one row for one row, and counts it.

Inputs:
    data/raw/online_retail_II.xlsx (already downloaded, 45,622,278
    bytes). If it is missing, this script downloads the UCI zip
    and unzips it first.

Output:
    retail.db (gitignored, rebuild it any time with this script)

Cleaning, in order, with the funnel printed and stored in the
cleaning_funnel table:
    Step 0, raw: 1,067,371 rows, both sheets combined.
    Step 1, drop cancellations: Invoice starting with C.
        19,494 rows dropped, 1,047,877 remain.
    Step 2, drop Quantity <= 0 or Price <= 0.
        6,207 rows dropped, 1,041,670 remain. In the non-cancel
        rows, 3,457 rows have Quantity <= 0 and 6,207 have
        Price <= 0, and every Quantity <= 0 row also has
        Price <= 0. Price is 0 on 6,202 raw rows and negative
        on 5 raw rows. Quantity is never 0 in the raw file,
        it is negative on 22,950 raw rows.
    Step 3, drop rows with no Customer ID.
        236,121 rows dropped, 805,549 remain. All 4,382 rows
        with a missing Description are in this dropped group:
        every one of them has no Customer ID, so the cleaned
        table has zero missing Descriptions.
    Step 4, drop the second copy of cross-sheet duplicates.
        14,504 rows dropped, 791,045 remain. These are rows
        from the Year 2010-2011 sheet whose full 8-column key
        (Invoice, StockCode, Description, Quantity, InvoiceDate,
        Price, Customer ID, Country) already appears in the
        Year 2009-2010 sheet, in the Dec 1 to Dec 9, 2010
        overlap. The dropped rows are worth 311,878.00 GBP.
        Within-sheet exact duplicates are NOT dropped: 11,620
        such rows remain in the cleaned table, because the same
        invoice line repeated inside one sheet cannot be told
        apart from a genuine repeated line, so they are kept
        and reported instead of guessed away.
    Revenue is added as Quantity * Price, in GBP.

Tables built:
    transactions: one row per cleaned line, 791,045 rows.
    invoices: one row per invoice number, 36,969 rows.
        invoice_date is the earliest line time for that invoice.
        64 invoices have more than one distinct line timestamp.
    customers: one row per Customer ID, 5,878 rows.
        country is the customer's most frequent country.
        13 customers bought from more than one country.
    products: one row per StockCode, 4,631 rows.
        description is the most frequent description for that
        StockCode. 624 StockCodes carry more than one
        description in the cleaned data, so the product table
        picks the most frequent one and the transactions table
        keeps the original line description.
    countries: one row per country, 41 rows.
    monthly_revenue: one row per calendar month, 25 months.
    cleaning_funnel: one row per cleaning step, with counts.

Honest notes, handled here and documented, not hidden:
    - The source column names are Invoice, StockCode, Description,
      Quantity, InvoiceDate, Price, Customer ID, Country. They
      are renamed to snake_case in the database.
    - StockCode M means Manual, and StockCode POST means postage.
      They are not real products, but they carry real revenue:
      Manual is 152,166.32 GBP in the cleaned data, and
      postage is the top line for Germany and France. Queries
      that rank products name this instead of hiding it.
    - Customer ID is the only customer key. There are no
      customer names in the file. Do not invent any.
    - The largest single line is 80,995 units of PAPER CRAFT,
      LITTLE BIRDIE, 168,469.60 GBP, invoice 581483, customer
      16446, on 2011-12-09. It is kept as recorded.
    - The highest unit price is 10,953.50 GBP, a Manual line,
      invoice 502263, customer 12918, on 2010-03-23.
    - December 2009 is a partial month: the file starts on
      2009-12-01. December 2011 is also partial: the file ends
      on 2011-12-09. Do not compare those months with full
      months as if they were equal.
"""

import os
import sys
import urllib.request
import zipfile
from collections import Counter

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RAW_DIR = os.path.join(ROOT, "data", "raw")
XLSX_PATH = os.path.join(RAW_DIR, "online_retail_II.xlsx")
ZIP_PATH = os.path.join(RAW_DIR, "online_retail_ii_uci.zip")
ZIP_URL = "https://archive.ics.uci.edu/static/public/502/online+retail+ii.zip"
DB_PATH = os.path.join(ROOT, "retail.db")

COLUMNS = ["Invoice", "StockCode", "Description", "Quantity",
           "InvoiceDate", "Price", "Customer ID", "Country"]
RENAME = {
    "Invoice": "invoice_no",
    "StockCode": "stock_code",
    "Description": "description",
    "Quantity": "quantity",
    "InvoiceDate": "invoice_date",
    "Price": "unit_price",
    "Customer ID": "customer_id",
    "Country": "country",
}


def ensure_source():
    if os.path.exists(XLSX_PATH):
        return
    os.makedirs(RAW_DIR, exist_ok=True)
    if not os.path.exists(ZIP_PATH):
        print("Downloading", ZIP_URL)
        urllib.request.urlretrieve(ZIP_URL, ZIP_PATH)
    print("Unzipping", ZIP_PATH)
    with zipfile.ZipFile(ZIP_PATH) as z:
        z.extractall(RAW_DIR)


def clean_sheet(df):
    """Apply cleaning steps 1 to 3 to one sheet. Returns cleaned df."""
    df = df.copy()
    df = df[~df["Invoice"].astype(str).str.startswith("C")]
    df = df[(df["Quantity"] > 0) & (df["Price"] > 0)]
    df = df[df["Customer ID"].notna()]
    return df


def main():
    ensure_source()
    sheet_a = pd.read_excel(XLSX_PATH, sheet_name="Year 2009-2010")
    sheet_b = pd.read_excel(XLSX_PATH, sheet_name="Year 2010-2011")
    raw_rows = len(sheet_a) + len(sheet_b)
    print("raw rows =", raw_rows,
          "(sheet A", len(sheet_a), "sheet B", len(sheet_b), ")")

    # Step 1 to 3, counted on the combined file, in order.
    combined = pd.concat([sheet_a, sheet_b], ignore_index=True)
    after_cancel = combined[
        ~combined["Invoice"].astype(str).str.startswith("C")]
    dropped_cancel = len(combined) - len(after_cancel)
    after_qty_price = after_cancel[
        (after_cancel["Quantity"] > 0) & (after_cancel["Price"] > 0)]
    dropped_qty_price = len(after_cancel) - len(after_qty_price)
    after_customer = after_qty_price[after_qty_price["Customer ID"].notna()]
    dropped_customer = len(after_qty_price) - len(after_customer)
    print("after cancellations =", len(after_cancel),
          "dropped", dropped_cancel)
    print("after Quantity/Price =", len(after_qty_price),
          "dropped", dropped_qty_price)
    print("after Customer ID =", len(after_customer),
          "dropped", dropped_customer)

    # Step 4, cross-sheet duplicates only. Clean each sheet
    # separately, then drop from sheet B one copy for each exact
    # key already present in sheet A, counting per key so a key
    # that appears twice in A and three times in B loses two
    # copies from B, not three.
    clean_a = clean_sheet(sheet_a)
    clean_b = clean_sheet(sheet_b)
    counts_a = clean_a[COLUMNS].value_counts()
    counts_b = clean_b[COLUMNS].value_counts()
    common = counts_a.index.intersection(counts_b.index)
    drop_per_key = {k: min(counts_a[k], counts_b[k]) for k in common}
    remaining = Counter(drop_per_key)
    keep_b = []
    dropped_revenue = 0.0
    for idx, row in clean_b.iterrows():
        key = tuple(row[c] for c in COLUMNS)
        if remaining.get(key, 0) > 0:
            remaining[key] -= 1
            dropped_revenue += float(row["Quantity"]) * float(row["Price"])
        else:
            keep_b.append(idx)
    clean_b_deduped = clean_b.loc[keep_b]
    dropped_dup = len(clean_b) - len(clean_b_deduped)
    print("after cross-sheet dedup =", len(clean_a) + len(clean_b_deduped),
          "dropped", dropped_dup, "revenue dropped =", round(dropped_revenue, 2))

    df = pd.concat([clean_a, clean_b_deduped], ignore_index=True)
    df["Revenue"] = df["Quantity"] * df["Price"]
    df = df.rename(columns=RENAME)
    df["customer_id"] = df["customer_id"].astype(int)
    df["invoice_no"] = df["invoice_no"].astype(str)
    df["stock_code"] = df["stock_code"].astype(str)
    df["invoice_date"] = pd.to_datetime(df["invoice_date"])
    df["year_month"] = df["invoice_date"].dt.strftime("%Y-%m")
    df["year"] = df["invoice_date"].dt.year
    df["source_sheet"] = ["Year 2009-2010"] * len(clean_a) + \
        ["Year 2010-2011"] * len(clean_b_deduped)
    df["invoice_date_text"] = df["invoice_date"].dt.strftime("%Y-%m-%d %H:%M:%S")

    # Within-sheet exact duplicates kept, counted for the report.
    within_dup = int(df.duplicated(subset=[
        "invoice_no", "stock_code", "description", "quantity",
        "invoice_date_text", "unit_price", "customer_id", "country"
    ], keep="first").sum())
    print("within-sheet exact duplicate rows kept =", within_dup)
    multi_timestamp_invoices = int(
        df.groupby("invoice_no")["invoice_date"].nunique().gt(1).sum())
    print("invoices with more than one line timestamp =",
          multi_timestamp_invoices)

    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    import sqlite3
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()

    cur.execute("""
        CREATE TABLE transactions (
            invoice_no TEXT,
            stock_code TEXT,
            description TEXT,
            quantity INTEGER,
            invoice_date TEXT,
            unit_price REAL,
            customer_id INTEGER,
            country TEXT,
            revenue REAL,
            year_month TEXT,
            year INTEGER,
            source_sheet TEXT
        )
    """)
    cur.execute("""
        CREATE TABLE invoices (
            invoice_no TEXT,
            invoice_date TEXT,
            customer_id INTEGER,
            country TEXT,
            lines INTEGER,
            total_quantity INTEGER,
            total_revenue REAL
        )
    """)
    cur.execute("""
        CREATE TABLE customers (
            customer_id INTEGER,
            country TEXT,
            first_order_date TEXT,
            last_order_date TEXT,
            total_orders INTEGER,
            total_lines INTEGER,
            total_quantity INTEGER,
            total_revenue REAL
        )
    """)
    cur.execute("""
        CREATE TABLE products (
            stock_code TEXT,
            description TEXT,
            total_lines INTEGER,
            total_quantity INTEGER,
            total_revenue REAL,
            distinct_customers INTEGER,
            distinct_invoices INTEGER
        )
    """)
    cur.execute("""
        CREATE TABLE countries (
            country TEXT,
            total_lines INTEGER,
            distinct_customers INTEGER,
            distinct_invoices INTEGER,
            total_revenue REAL
        )
    """)
    cur.execute("""
        CREATE TABLE monthly_revenue (
            year_month TEXT,
            lines INTEGER,
            distinct_invoices INTEGER,
            distinct_customers INTEGER,
            total_revenue REAL
        )
    """)
    cur.execute("""
        CREATE TABLE cleaning_funnel (
            step TEXT,
            rows_remaining INTEGER,
            rows_dropped INTEGER,
            note TEXT
        )
    """)

    trans = df[["invoice_no", "stock_code", "description", "quantity",
                "invoice_date_text", "unit_price", "customer_id",
                "country", "Revenue", "year_month", "year",
                "source_sheet"]].values.tolist()
    cur.executemany(
        "INSERT INTO transactions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        trans)

    inv = df.groupby("invoice_no").agg(
        invoice_date=("invoice_date_text", "min"),
        customer_id=("customer_id", "first"),
        country=("country", "first"),
        lines=("Revenue", "size"),
        total_quantity=("quantity", "sum"),
        total_revenue=("Revenue", "sum")).reset_index()
    cur.executemany(
        "INSERT INTO invoices VALUES (?, ?, ?, ?, ?, ?, ?)",
        inv.values.tolist())

    def mode_value(series):
        counts = series.value_counts()
        top = counts.max()
        return sorted(counts[counts == top].index.tolist())[0]

    cust_rows = []
    for cid, group in df.groupby("customer_id"):
        cust_rows.append((
            int(cid),
            mode_value(group["country"]),
            group["invoice_date_text"].min(),
            group["invoice_date_text"].max(),
            int(group["invoice_no"].nunique()),
            int(len(group)),
            int(group["quantity"].sum()),
            float(group["Revenue"].sum()),
        ))
    cur.executemany("INSERT INTO customers VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    cust_rows)

    prod_rows = []
    for code, group in df.groupby("stock_code"):
        prod_rows.append((
            str(code),
            mode_value(group["description"].dropna()),
            int(len(group)),
            int(group["quantity"].sum()),
            float(group["Revenue"].sum()),
            int(group["customer_id"].nunique()),
            int(group["invoice_no"].nunique()),
        ))
    cur.executemany(
        "INSERT INTO products VALUES (?, ?, ?, ?, ?, ?, ?)", prod_rows)

    country_rows = []
    for country, group in df.groupby("country"):
        country_rows.append((
            country,
            int(len(group)),
            int(group["customer_id"].nunique()),
            int(group["invoice_no"].nunique()),
            float(group["Revenue"].sum()),
        ))
    cur.executemany(
        "INSERT INTO countries VALUES (?, ?, ?, ?, ?)", country_rows)

    monthly = df.groupby("year_month").agg(
        lines=("Revenue", "size"),
        distinct_invoices=("invoice_no", "nunique"),
        distinct_customers=("customer_id", "nunique"),
        total_revenue=("Revenue", "sum")).reset_index()
    cur.executemany(
        "INSERT INTO monthly_revenue VALUES (?, ?, ?, ?, ?)",
        monthly.values.tolist())

    funnel = [
        ("Raw, both sheets combined", raw_rows, 0,
         "UCI file, 1,067,371 rows as listed by UCI"),
        ("After dropping cancellations (Invoice starting with C)",
         len(after_cancel), dropped_cancel,
         "Cancellations are 19,494 rows, 1.8 percent of raw"),
        ("After dropping Quantity <= 0 or Price <= 0",
         len(after_qty_price), dropped_qty_price,
         "Price is 0 on 6,202 raw rows, negative on 5; "
         "Quantity is negative on 22,950 raw rows, never 0"),
        ("After dropping rows with no Customer ID",
         len(after_customer), dropped_customer,
         "All 4,382 rows with a missing Description are in "
         "this group, so cleaned data has zero missing "
         "Descriptions"),
        ("After dropping second copy of cross-sheet duplicates",
         len(df), dropped_dup,
         "Dec 1 to Dec 9, 2010 appears in both sheets; "
         "second copy worth 311,878.00 GBP"),
    ]
    cur.executemany(
        "INSERT INTO cleaning_funnel VALUES (?, ?, ?, ?)", funnel)

    cur.execute("CREATE INDEX idx_t_customer ON transactions(customer_id)")
    cur.execute("CREATE INDEX idx_t_invoice ON transactions(invoice_no)")
    cur.execute("CREATE INDEX idx_t_stock ON transactions(stock_code)")
    cur.execute("CREATE INDEX idx_t_country ON transactions(country)")
    cur.execute("CREATE INDEX idx_t_date ON transactions(invoice_date)")
    con.commit()

    checks = {
        "transactions": "SELECT COUNT(*) FROM transactions",
        "invoices": "SELECT COUNT(*) FROM invoices",
        "customers": "SELECT COUNT(*) FROM customers",
        "products": "SELECT COUNT(*) FROM products",
        "countries": "SELECT COUNT(*) FROM countries",
        "monthly_revenue": "SELECT COUNT(*) FROM monthly_revenue",
        "total_revenue": "SELECT ROUND(SUM(revenue), 2) FROM transactions",
    }
    for name, sql in checks.items():
        print(name, "=", cur.execute(sql).fetchone()[0])
    print("date range =",
          cur.execute("SELECT MIN(invoice_date), MAX(invoice_date) "
                      "FROM transactions").fetchone())
    con.close()
    print("Wrote", DB_PATH)


if __name__ == "__main__":
    sys.exit(main())
