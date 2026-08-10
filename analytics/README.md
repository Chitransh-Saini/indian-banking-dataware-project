# Analytics Layer

SQL-based analysis built on top of the `gold` star schema, answering
specific business questions rather than generic "top N" queries.

| File | Business Focus | Key Questions Answered |
|---|---|---|
| `customer_analysis.sql` | Customer segmentation & dormancy | Which segments drive value? Who's at dormancy risk? Which locations are under-monetized? |
| `product_analysis.sql` | Balance-tier (product proxy) performance | Which tier concentrates value? Are HNI customers under-engaged? |
| `sales_analysis.sql` | Transaction volume trends | MoM trend, weekday/weekend pattern, which tier drives a given month's swing |
| `performance_analysis.sql` | Location-level performance | YoY growth by location, over/under-performers, volume vs. value-per-transaction |


## Attribution
The bronze/silver/gold pipeline pattern in this repository follows the
medallion architecture approach taught by Data With Baraa's SQL Data
Warehouse course. The dataset, business questions, schema design, and all
analysis in this `analytics/` folder are original work built for this
project.
