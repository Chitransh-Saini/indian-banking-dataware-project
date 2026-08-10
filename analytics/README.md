# Analytics Layer

SQL-based analysis built on top of the `gold` star schema, answering
specific business questions rather than generic "top N" queries.

| File | Business Focus | Key Questions Answered |
|---|---|---|
| `customer_analysis.sql` | Customer segmentation & dormancy | Which segments drive value? Who's at dormancy risk? Which locations are under-monetized? |
| `product_analysis.sql` | Balance-tier (product proxy) performance | Which tier concentrates value? Are HNI customers under-engaged? |
| `sales_analysis.sql` | Transaction volume trends | MoM trend, weekday/weekend pattern, which tier drives a given month's swing |
| `performance_analysis.sql` | Location-level performance | YoY growth by location, over/under-performers, volume vs. value-per-transaction |

## How to use this section in your resume/portfolio
Don't just link the files — write 2-3 sentences per file stating the
**actual finding** once you run these against the real dataset, e.g.:

> "Identified that HNI-tier customers (18% of balance value) transact
> 40% less frequently than Mass Affluent customers — flagged as a
> wallet-share risk and a target segment for a relationship-banking
> outreach program."

That sentence — a number + an interpretation + a recommendation — is what
turns this from "I wrote SQL" into "I did analysis." Fill in the real
numbers after running the queries; don't guess them.

## Attribution
The bronze/silver/gold pipeline pattern in this repository follows the
medallion architecture approach taught by Data With Baraa's SQL Data
Warehouse course. The dataset, business questions, schema design, and all
analysis in this `analytics/` folder are original work built for this
project.
