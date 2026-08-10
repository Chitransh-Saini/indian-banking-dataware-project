/*
===============================================================================
Performance Analysis
===============================================================================
Note on scope: the dataset has no branch/RM ID, so "performance" here is
measured at the location (city) level, standing in for a branch — the same
analysis pattern applies directly once real branch IDs are available.

Business Questions:
  1. Which locations are growing fastest year-over-year, and which are
     declining — early warning signals for a real branch network?
  2. How does each location rank against the overall average (over/under
     performing), using a running comparison rather than a flat total?
  3. Which locations have the best "quality" of transactions — high avg
     value per transaction, not just high volume — worth different
     resourcing than high-volume/low-value locations?
===============================================================================
*/

-- Q1: Year-over-year growth by location
WITH yearly AS (
    SELECT
        c.location,
        d.year,
        SUM(f.transaction_amount) AS yearly_value
    FROM gold.fact_transactions f
    JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    JOIN gold.dim_date d ON f.date_key = d.date_key
    GROUP BY c.location, d.year
)
SELECT
    location,
    year,
    yearly_value,
    ROUND(
        (yearly_value - LAG(yearly_value) OVER (PARTITION BY location ORDER BY year)) * 100.0
        / NULLIF(LAG(yearly_value) OVER (PARTITION BY location ORDER BY year), 0), 2
    ) AS yoy_pct_change
FROM yearly
ORDER BY location, year;


-- Q2: Each location's performance vs. the overall average (part-to-whole)
SELECT
    c.location,
    SUM(f.transaction_amount)                                        AS location_value,
    ROUND(AVG(SUM(f.transaction_amount)) OVER (), 2)                  AS avg_value_across_locations,
    ROUND(SUM(f.transaction_amount) -
        AVG(SUM(f.transaction_amount)) OVER (), 2)                    AS variance_from_avg
FROM gold.fact_transactions f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.location
HAVING COUNT(DISTINCT f.customer_key) >= 30
ORDER BY variance_from_avg DESC;


-- Q3: Volume vs. value-per-transaction quality ranking
SELECT
    c.location,
    COUNT(f.transaction_id)                       AS txn_volume,
    RANK() OVER (ORDER BY COUNT(f.transaction_id) DESC)          AS volume_rank,
    ROUND(AVG(f.transaction_amount), 2)            AS avg_txn_value,
    RANK() OVER (ORDER BY AVG(f.transaction_amount) DESC)        AS avg_value_rank
FROM gold.fact_transactions f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.location
HAVING COUNT(f.transaction_id) >= 100
ORDER BY txn_volume DESC;

-- Finding to write up: a location ranked high on volume but low on
-- avg_txn_value is doing lots of small transactions — different
-- operational needs (ATM/cash-handling capacity) than a low-volume,
-- high-avg-value location (needs relationship banking staff, not tellers).
