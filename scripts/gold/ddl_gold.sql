/*
===============================================================================
DDL Script: Create Gold Tables (Star Schema)
===============================================================================
Purpose:
    Materialized (not view-based) star schema for reporting.

    Design decision: gold was originally built as views. At 1M+ transaction
    rows, that meant every analytics query re-ran the full join, COALESCE,
    and date/tier logic from scratch — and any query touching both
    fact_transactions and dim_date re-scanned all of
    silver.core_banking_transactions a second time, since dim_date was
    also a view over the same base table. Materializing gold as tables,
    loaded once via scripts/gold/load_gold.sql, moves that cost from
    "every analytics query" to "once per ETL run" — which is where it
    belongs in a warehouse.

    dim_customers includes an explicit "Unknown Customer" member
    (customer_key = -1) for transactions whose CRM record was flagged in
    silver, so no fact row is ever left with a NULL foreign key.
===============================================================================
*/

IF OBJECT_ID('gold.dim_customers', 'U') IS NOT NULL
    DROP TABLE gold.dim_customers;
GO

CREATE TABLE gold.dim_customers (
    customer_key      INT PRIMARY KEY,
    customer_id        NVARCHAR(50),
    customer_age        INT,
    age_generation        NVARCHAR(30),
    gender                 NVARCHAR(10),
    location                 NVARCHAR(100)
);
GO

CREATE NONCLUSTERED INDEX IX_dim_customers_customer_id
    ON gold.dim_customers (customer_id);
GO

CREATE NONCLUSTERED INDEX IX_dim_customers_location
    ON gold.dim_customers (location) INCLUDE (age_generation, gender);
GO

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO

CREATE TABLE gold.dim_date (
    date_key       DATE PRIMARY KEY,
    year            INT,
    month_name       NVARCHAR(20),
    month_num          INT,
    day_name             NVARCHAR(20),
    is_weekend             BIT
);
GO

IF OBJECT_ID('gold.fact_transactions', 'U') IS NOT NULL
    DROP TABLE gold.fact_transactions;
GO

CREATE TABLE gold.fact_transactions (
    transaction_id       NVARCHAR(50),
    customer_key           INT,          -- -1 = Unknown Customer, never NULL
    date_key                  DATE,
    transaction_datetime         DATETIME2,
    transaction_amount              DECIMAL(18,2),
    account_balance                    DECIMAL(18,2),
    balance_tier                          NVARCHAR(20)
);
GO

-- Clustered columnstore index: the right index type for a large
-- (1M+ row), append-only, aggregate-heavy fact table — analytics/ queries
-- are almost entirely GROUP BY / SUM / AVG over this table, which is
-- exactly what columnstore is built for. Typically a 5-10x+ read speedup
-- over a rowstore heap for this workload, at the cost of slower
-- individual-row lookups/updates — an acceptable trade-off for a fact
-- table that's only ever bulk-loaded, never row-by-row edited.
CREATE CLUSTERED COLUMNSTORE INDEX CCI_fact_transactions
    ON gold.fact_transactions;
GO
