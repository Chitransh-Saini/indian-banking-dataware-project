/*
===============================================================================
Product Analysis
===============================================================================
Note on scope: the raw dataset doesn't include an explicit loan/product
table, so this file treats account `balance_tier` (Mass Market / Mass
Affluent / Affluent / HNI) as a proxy for banking product segment — the
same way a bank would decide which products (savings vs. premium accounts,
credit cards, wealth management) to offer each tier. State this framing
explicitly if asked about it in an interview — it's a deliberate design
choice, not a data gap you missed.

Business Questions:
  1. Which balance tier generates the highest average transaction value,
     and is it proportionate to how many customers sit in that tier?
  2. Are HNI customers being transacted with at a frequency that matches
     their balance, or are they under-engaged (churn/attrition risk)?
  3. What's the average transaction size by tier — does it suggest tiers
     are using the account for daily spending vs. occasional large moves?
===============================================================================
*/

-- Q1: Value concentration by tier
SELECT
    balance_tier,
    COUNT(DISTINCT customer_key)               AS customers,
    COUNT(transaction_id)                       AS total_transactions,
    SUM(transaction_amount)                      AS total_value,
    ROUND(AVG(transaction_amount), 2)            AS avg_txn_value,
    ROUND(SUM(transaction_amount) * 100.0 /
        SUM(SUM(transaction_amount)) OVER (), 2) AS pct_of_total_value
FROM gold.fact_transactions
GROUP BY balance_tier
ORDER BY total_value DESC;


-- Q2: Engagement frequency by tier (transactions per customer)
SELECT
    balance_tier,
    COUNT(transaction_id) * 1.0 / NULLIF(COUNT(DISTINCT customer_key), 0) AS avg_txns_per_customer
FROM gold.fact_transactions
GROUP BY balance_tier
ORDER BY avg_txns_per_customer ASC;

-- Finding to write up: if HNI shows the lowest txns_per_customer despite
-- highest balances, that's a real, defensible insight — those customers
-- likely park money but transact elsewhere, i.e. wallet-share risk.


-- Q3: Transaction size distribution within each tier
SELECT
    balance_tier,
    MIN(transaction_amount)                          AS min_txn,
    ROUND(AVG(transaction_amount), 2)                 AS avg_txn,
    MAX(transaction_amount)                            AS max_txn,
    ROUND(STDEV(transaction_amount), 2)                AS stddev_txn
FROM gold.fact_transactions
GROUP BY balance_tier
ORDER BY avg_txn DESC;
