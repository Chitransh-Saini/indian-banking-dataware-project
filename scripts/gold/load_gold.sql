/*
===============================================================================
Load Script: Gold Layer (Full Load)
===============================================================================
Purpose:
    Populate the materialized gold tables from silver. Run once per ETL
    cycle (or after any silver reload) — NOT on every analytics query,
    which was the performance problem with the earlier view-based design.

    Run order: dim_customers -> dim_date -> fact_transactions (fact load
    joins against the now-materialized, now-indexed dim_customers table,
    not against silver directly, which is faster than the old view join).
===============================================================================
*/

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN

    DECLARE
        @start_time DATETIME,
        @end_time DATETIME,
        @batch_start_time DATETIME,
        @batch_end_time DATETIME;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '=======================================';
        PRINT 'Loading Gold Layer';
        PRINT '=======================================';

        -- ============ dim_customers ============
        SET @start_time = GETDATE();
        PRINT '>> Loading gold.dim_customers...';

        TRUNCATE TABLE gold.dim_customers;

        INSERT INTO gold.dim_customers (customer_key, customer_id, customer_age, age_generation, gender, location)
        SELECT
            ROW_NUMBER() OVER (ORDER BY CustomerID)  AS customer_key,
            CustomerID                                AS customer_id,
            customer_age,
            CASE
                WHEN customer_age < 25              THEN 'Gen Z (18-24)'
                WHEN customer_age BETWEEN 25 AND 40 THEN 'Millennial (25-40)'
                WHEN customer_age BETWEEN 41 AND 56 THEN 'Gen X (41-56)'
                ELSE 'Boomer (57+)'
            END                                        AS age_generation,
            CustGender                                AS gender,
            CustLocation                              AS location
        FROM silver.crm_customer_info
        WHERE dq_flag = 'OK';

        -- Unknown Customer member (customer_key = -1) — see docs/data_catalog.md
        INSERT INTO gold.dim_customers (customer_key, customer_id, customer_age, age_generation, gender, location)
        VALUES (-1, 'UNKNOWN', NULL, 'Unknown', 'Unknown', 'Unknown');

        SET @end_time = GETDATE();
        PRINT '>> dim_customers loaded. Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        -- ============ dim_date ============
        SET @start_time = GETDATE();
        PRINT '>> Loading gold.dim_date...';

        TRUNCATE TABLE gold.dim_date;

        INSERT INTO gold.dim_date (date_key, year, month_name, month_num, day_name, is_weekend)
        SELECT DISTINCT
            CAST(transaction_datetime AS DATE)                    AS date_key,
            YEAR(transaction_datetime)                            AS year,
            DATENAME(MONTH, transaction_datetime)                 AS month_name,
            MONTH(transaction_datetime)                            AS month_num,
            DATENAME(WEEKDAY, transaction_datetime)                AS day_name,
            CASE
                WHEN DATENAME(WEEKDAY, transaction_datetime) IN ('Saturday','Sunday')
                THEN 1 ELSE 0
            END                                                     AS is_weekend
        FROM silver.core_banking_transactions
        WHERE dq_flag = 'OK';

        SET @end_time = GETDATE();
        PRINT '>> dim_date loaded. Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        -- ============ fact_transactions ============
        SET @start_time = GETDATE();
        PRINT '>> Loading gold.fact_transactions...';

        TRUNCATE TABLE gold.fact_transactions;

        INSERT INTO gold.fact_transactions
            (transaction_id, customer_key, date_key, transaction_datetime, transaction_amount, account_balance, balance_tier)
        SELECT
            t.TransactionID                     AS transaction_id,
            COALESCE(c.customer_key, -1)        AS customer_key,
            CAST(t.transaction_datetime AS DATE) AS date_key,
            t.transaction_datetime,
            t.TransactionAmount                  AS transaction_amount,
            t.CustAccountBalance                 AS account_balance,
            t.balance_tier
        FROM silver.core_banking_transactions t
        LEFT JOIN gold.dim_customers c
            ON t.CustomerID = c.customer_id
        WHERE t.dq_flag = 'OK';

        SET @end_time = GETDATE();
        PRINT '>> fact_transactions loaded. Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';


        SET @batch_end_time = GETDATE();
        PRINT '=======================================';
        PRINT 'Gold Layer Loaded Successfully';
        PRINT '>> Total Duration: '
            + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '=======================================';

    END TRY
    BEGIN CATCH
        PRINT '=======================================';
        PRINT 'Gold Layer Load Failed';
        PRINT 'Error: ' + ERROR_MESSAGE();
        PRINT '=======================================';
        THROW;
    END CATCH

END;
GO
