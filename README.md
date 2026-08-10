# Indian Banking Data Warehouse & Customer Analytics Project

Building a data warehouse and analytics layer on real Indian bank customer
transaction data (1M+ records), following the Medallion Architecture
(Bronze → Silver → Gold), with an original analytics layer answering
specific business questions.

> **Attribution:** the bronze/silver/gold pipeline pattern and project
> structure follow the approach taught in Data With Baraa's SQL Data
> Warehouse course. The dataset choice, schema design, data-quality rules,
> and everything in `analytics/` are original work built for this project.

---

## 🏗️ Data Architecture

Medallion Architecture with **Bronze**, **Silver**, and **Gold** layers:

1. **Bronze** — raw ingestion of the source file into a staging table,
   then split into two logical source feeds (CRM customer data, Core
   Banking transaction data) entirely in T-SQL, simulating a realistic
   multi-system integration.
2. **Silver** — cleansed, standardized, deduplicated, with explicit
   data-quality flags (not silent row drops), plus indexes on the join/
   filter columns analytics and gold-load queries actually use.
3. **Gold** — materialized star schema (`dim_customers`, `dim_date`,
   `fact_transactions`) loaded once via a stored procedure, with a
   clustered columnstore index on the fact table for fast aggregate
   queries — not recomputed live on every read.

## 📖 Project Overview

- **Data source:** [Bank Customer Segmentation (1M+ Transactions)](https://www.kaggle.com/datasets/shivamb/bank-customer-segmentation) — Kaggle, Indian bank customer + transaction data. **Verified against the real file:** 1,048,567 transactions, 884,265 unique customers, spanning 1 Aug – 21 Oct 2016.
- **Data Modeling:** star schema optimized for analytical queries
- **Data Quality:** six real, profiled data-quality issues handled explicitly rather than assumed — see `docs/data_catalog.md` for the full list (non-standard date formats, a DOB sentinel value affecting 5.47% of customers, malformed time strings, null balances, etc.)
- **Analytics:** four SQL analysis files, each answering real business
  questions (see `analytics/README.md`) — customer segmentation & single-transaction risk (83.8% of customers transact only once), product/balance-tier performance, weekly transaction trends, and location-level performance

## 📂 Repository Structure

```
sql-data-warehouse-project/
│
├── dataset/                            # Sample CSVs + split script (full data via Kaggle, not committed)
│   ├── crm/sample_crm_customer_info.csv
│   ├── core_banking/sample_core_banking_transactions.csv
│   └── README.md
│
├── docs/
│   ├── data_catalog.md                 # Source-to-bronze-to-silver-to-gold mapping
│   ├── data_architecture.drawio
│   └── data_models.drawio
│
├── scripts/
│   ├── init_database.sql                # Run FIRST — creates DataWarehouse DB + bronze/silver/gold schemas
│   ├── split_source_data.py            # OPTIONAL — Python alternative to the T-SQL split below
│   ├── bronze/                         # Raw staging load + T-SQL split into CRM/Core Banking feeds
│   ├── silver/                         # DDL + cleansing/transform scripts, plus join/filter indexes
│   └── gold/                           # Materialized star schema: DDL (tables + columnstore index) + load
│
├── analytics/                          # Original business-question SQL analysis
│   ├── customer_analysis.sql
│   ├── product_analysis.sql
│   ├── sales_analysis.sql
│   ├── performance_analysis.sql
│   └── README.md
│
├── tests/
├── README.md
└── LICENSE
```

## 🛠️ Tools

- SQL Server / SSMS
- Kaggle dataset (linked above)
- Draw.io for architecture diagrams

## 🛡️ License

MIT License.
