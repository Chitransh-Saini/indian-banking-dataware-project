/*
===============================================================================
Sales (Transaction Volume) Analysis
===============================================================================
Business Questions:
  1. What's the weekly transaction value trend, and where are the
     inflection points?
  2. Is there a weekday vs. weekend transaction pattern the bank should plan
     staffing/liquidity around?
  3. Which week/tier combination is driving growth or decline, so any
     dip can be isolated to a specific segment rather than "sales are down"?

Note on grain: verified the actual data only spans 1 Aug - 21 Oct 2016
(55 unique transaction days, ~82 calendar days). That's under 3 partial
months — a month-over-month trend would be comparing one full month
(September) against two partial ones, which overstates or understates
swings that are really just partial-period artifacts. Weekly grain gives
~11-12 comparable data points instead of 3 misleading ones, so it's the
primary trend here; a monthly rollup is included after but should be
read with that caveat.
===============================================================================
*/

-- Q1a: Weekly transaction value trend (primary — see grain note above)
WITH weekly AS (
    SELECT
        DATEPART(YEAR, d.date_key)                            AS yr,
        DATEPART(ISO_WEEK, d.date_key)                          AS iso_week,
        MIN(d.date_key)                                          AS week_start,
        SUM(f.transaction_amount)                                AS weekly_value
    FROM gold.fact_transactions f
    JOIN gold.dim_date d ON f.date_key = d.date_key
    GROUP BY DATEPART(YEAR, d.date_key), DATEPART(ISO_WEEK, d.date_key)
)
SELECT
    week_start,
    weekly_value,
    ROUND(
        (weekly_value - LAG(weekly_value) OVER (ORDER BY yr, iso_week)) * 100.0
        / NULLIF(LAG(weekly_value) OVER (ORDER BY yr, iso_week), 0), 2
    ) AS wow_pct_change
FROM weekly
ORDER BY yr, iso_week;


-- Q1b: Monthly rollup (secondary — read with the partial-month caveat above)
WITH monthly AS (
    SELECT
        d.year,
        d.month_num,
        d.month_name,
        SUM(f.transaction_amount) AS monthly_value
    FROM gold.fact_transactions f
    JOIN gold.dim_date d ON f.date_key = d.date_key
    GROUP BY d.year, d.month_num, d.month_name
)
SELECT
    year,
    month_name,
    monthly_value,
    ROUND(
        (monthly_value - LAG(monthly_value) OVER (ORDER BY year, month_num)) * 100.0
        / NULLIF(LAG(monthly_value) OVER (ORDER BY year, month_num), 0), 2
    ) AS mom_pct_change
FROM monthly
ORDER BY year, month_num;

-- Finding to write up: name the specific week with the sharpest drop/rise
-- and cross-check it against Q3 below before concluding why.


-- Q2: Weekday vs weekend pattern
SELECT
    d.is_weekend,
    COUNT(f.transaction_id)                    AS total_transactions,
    SUM(f.transaction_amount)                    AS total_value,
    ROUND(AVG(f.transaction_amount), 2)          AS avg_txn_value
FROM gold.fact_transactions f
JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY d.is_weekend;


-- Q3: Which tier drove a given month's change (isolate the growth driver)
SELECT
    d.year,
    d.month_name,
    f.balance_tier,
    SUM(f.transaction_amount) AS tier_monthly_value
FROM gold.fact_transactions f
JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month_num, d.month_name, f.balance_tier
ORDER BY d.year, d.month_num, tier_monthly_value DESC;
