# Data Catalog

## Source Dataset
**Indian Bank Customer Transactions** (1M+ records)
Source: Kaggle — "Bank Customer Segmentation (1M+ Transactions)"
Raw file: `bank_transactions.csv`

The raw file is a single flat export, but it naturally contains two distinct
business entities that would, in a real bank, come from two different source
systems. This project splits it into two logical sources at ingestion time to
mirror a realistic multi-source integration problem:

| Logical Source System        | Business Owner            | Fields Pulled From Raw File                                  |
|-------------------------------|----------------------------|----------------------------------------------------------------|
| **CRM / Customer Onboarding** | Retail Banking Ops         | CustomerID, CustomerDOB, CustGender, CustLocation              |
| **Core Banking System**       | Transaction Processing     | TransactionID, CustomerID, CustAccountBalance, TransactionDate, TransactionTime, TransactionAmount |

> **Verified against the actual file** (1,048,567 rows, 884,265 unique
> customers). Columns match exactly: `TransactionID, CustomerID,
> CustomerDOB, CustGender, CustLocation, CustAccountBalance,
> TransactionDate, TransactionTime, TransactionAmount (INR)`. The last
> column has a space and parentheses in its name — handled by renaming it
> during the source split (see `scripts/split_source_data.py`) rather than
> bracket-escaping it in every query.

## Real Data Quality Issues Found (not hypothetical — confirmed by profiling the file)

| Issue | Scale | Handling |
|---|---|---|
| `CustomerDOB` and `TransactionDate` are **dd/mm/yy**, not the SQL Server default mm/dd/yy | All rows | `TRY_CONVERT(DATE, col, 3)` — using plain `TRY_CAST` silently mis-parses or nulls ~58% of rows (any date where day > 12) |
| `TransactionTime` is a bare `HHMMSS` integer string with **no leading zeros preserved** (lengths run 1-6 digits) | 108,472 rows are 5-digit, 14,098 are 4-digit, etc. | Zero-pad to 6 chars before slicing into `HH:MM:SS` |
| `CustomerDOB` contains a **`1/1/1800` sentinel value** for unknown DOB | 57,339 rows (5.47%) | Flagged as `MISSING_DOB_SENTINEL`, excluded from age-based segmentation — not silently averaged in as a 226-year-old customer |
| `CustAccountBalance` is `NULL` | 2,369 rows (0.23%) | Flagged `MISSING_BALANCE`, `balance_tier = 'Unknown'` — left unhandled, these would silently fall into the top "HNI" bucket via SQL's NULL comparison behavior |
| `CustGender` blank or a stray `'T'` value | 1,100 blanks + 1 row | Mapped to `'Unknown'` rather than dropped |
| `TransactionAmount` is 0 | 835 rows | Treated same as negative — flagged `ZERO_OR_NEGATIVE_AMOUNT` |
| No duplicate `TransactionID`s | — | Confirmed, no dedup needed on the fact table |
| Date range is only **1 Aug – 21 Oct 2016** (55 unique transaction days) | Whole dataset | This is a ~3-month snapshot, not a full year — affects trend-analysis grain (see `analytics/sales_analysis.sql`) and rules out any dormancy metric with a threshold longer than the observed window |

## Bronze Layer
Raw 1:1 copies of the two source extracts. No transformation. Includes a
`dwh_load_date` audit column on every table.

- `bronze.crm_customer_info`
- `bronze.core_banking_transactions`

## Silver Layer
Cleaned, standardized, deduplicated versions of bronze tables.

- `silver.crm_customer_info` — dedup by CustomerID, derive `customer_age`
  from DOB, standardize `CustLocation` casing, flag invalid/future DOBs.
- `silver.core_banking_transactions` — merge date + time into a single
  `transaction_datetime`, remove negative/null `TransactionAmount` rows,
  flag transactions with account balance mismatches.

## Gold Layer (Star Schema)
Materialized tables (not views), loaded once via `scripts/gold/load_gold.sql`
rather than recomputed on every query. At 1M+ transaction rows, the earlier
view-based design meant every analytics query re-ran the full join/date/tier
logic from scratch, and any query touching both `fact_transactions` and
`dim_date` silently re-scanned the entire base table a second time. This is
a deliberate, documented design correction, not the original approach.

- `gold.dim_customers` — one row per customer, SCD-1 (latest snapshot only),
  plus an explicit `customer_key = -1` "Unknown Customer" member for
  transactions whose CRM record was flagged in silver
- `gold.dim_date` — standard date dimension generated for the transaction
  date range
- `gold.fact_transactions` — one row per transaction, foreign-keyed to
  `dim_customers` and `dim_date`, stored with a **clustered columnstore
  index** — the appropriate index type for a large, append-only,
  aggregate-heavy fact table (this project's `analytics/` queries are
  almost entirely `GROUP BY`/`SUM`/`AVG`, which columnstore is built for)

## Data Quality Rules Enforced in Silver
1. `CustomerID` must be non-null and unique per customer record in CRM.
2. `TransactionAmount` must be > 0.
3. `CustomerDOB` must produce an age between 18 and 100; anything outside
   this range is flagged in `dq_flag`, not silently dropped.
4. `CustLocation` is trimmed and upper-cased for consistent grouping.
