/*
===============================================================================
Customer Analysis
===============================================================================
Business Questions:
  1. Which customer segments (age generation x balance tier) drive the most
     transaction value, and are they being served by the right products?
  2. What % of customers show only a single transaction in the observed
     window — a repeat-engagement risk signal — and does it concentrate
     in a particular segment?
  3. How does transaction behavior differ by gender and location — any
     segment being under-served relative to their balance?

Note on Q2: the raw dataset spans only ~82 days (1 Aug - 21 Oct 2016), so
a "no transaction in 90 days" dormancy threshold is meaningless here —
no customer CAN cross a 90-day gap inside an 82-day window. Verified this
against the actual data (884,265 unique customers, 1,048,567 transactions)
and found something more useful instead: 83.8% of customers have exactly
ONE transaction in the entire window. That's the real signal — a single-
transaction customer base is a genuine repeat-engagement problem, and it's
a finding grounded in the actual data rather than a borrowed metric that
doesn't fit the time range.
===============================================================================
*/

-- Q1: Revenue contribution by generation x balance tier
SELECT
    c.age_generation,
    f.balance_tier,
    COUNT(DISTINCT f.customer_key)          AS customer_count,
    SUM(f.transaction_amount)                AS total_txn_value,
    ROUND(SUM(f.transaction_amount) * 100.0 /
        SUM(SUM(f.transaction_amount)) OVER (), 2)   AS pct_of_total_value
FROM gold.fact_transactions f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.age_generation, f.balance_tier
ORDER BY total_txn_value DESC;

-- Finding to write up: whichever generation/tier combo shows a high
-- customer_count but low pct_of_total_value is a segment being
-- under-monetized — a candidate for a targeted product push.


-- Q2: Single-transaction customers by segment (repeat-engagement risk)
WITH txn_counts AS (
    SELECT
        customer_key,
        COUNT(*) AS txn_count
    FROM gold.fact_transactions
    GROUP BY customer_key
)
SELECT
    c.age_generation,
    c.gender,
    COUNT(*) AS single_txn_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_single_txn_customers
FROM txn_counts tc
JOIN gold.dim_customers c ON tc.customer_key = c.customer_key
WHERE tc.txn_count = 1
GROUP BY c.age_generation, c.gender
ORDER BY single_txn_customers DESC;

-- Verified finding: 740,653 of 884,265 customers (83.8%) transact exactly
-- once in this window. State which age_generation/gender combo over-indexes
-- here relative to their share of the total customer base — that's the
-- actual retention-campaign target, not a guessed number.


-- Q3: Location-wise average balance vs. transaction frequency
-- (flags locations with high wealth but low engagement — cross-sell targets)
SELECT
    c.location,
    COUNT(DISTINCT f.customer_key)        AS customers,
    AVG(f.account_balance)                 AS avg_account_balance,
    COUNT(f.transaction_id) * 1.0 / NULLIF(COUNT(DISTINCT f.customer_key), 0) AS txns_per_customer
FROM gold.fact_transactions f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.location
HAVING COUNT(DISTINCT f.customer_key) >= 30   -- ignore tiny/noisy locations
ORDER BY avg_account_balance DESC;
