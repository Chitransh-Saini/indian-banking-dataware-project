/*
===============================================================================
Load Script: Silver Layer (Cleanse & Standardize)
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN

    DECLARE
        @start_time DATETIME,
        @end_time DATETIME,
        @batch_start_time DATETIME,
        @batch_end_time DATETIME;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '=======================================';
        PRINT 'Loading Silver Layer';
        PRINT '=======================================';


        -- CRM Customer Info

        SET @start_time = GETDATE();

        PRINT '>> Loading CRM customer data...';

        TRUNCATE TABLE silver.crm_customer_info;

        INSERT INTO silver.crm_customer_info
        (
            CustomerID,
            CustomerDOB,
            customer_age,
            CustGender,
            CustLocation,
            dq_flag
        )
        SELECT
            CustomerID,

            TRY_CONVERT(
                DATE,
                CustomerDOB,
                3
            ) AS CustomerDOB,

            DATEDIFF(
                YEAR,
                TRY_CONVERT(DATE, CustomerDOB, 3),
                '2016-10-21'
            ) AS customer_age,

            CASE
                WHEN UPPER(LTRIM(RTRIM(CustGender))) IN ('M', 'MALE')
                    THEN 'Male'

                WHEN UPPER(LTRIM(RTRIM(CustGender))) IN ('F', 'FEMALE')
                    THEN 'Female'

                ELSE 'Unknown'
            END AS CustGender,

            UPPER(LTRIM(RTRIM(CustLocation))) AS CustLocation,

            CASE
                WHEN TRY_CONVERT(DATE, CustomerDOB, 3) IS NULL
                    THEN 'INVALID_DOB'

                WHEN YEAR(TRY_CONVERT(DATE, CustomerDOB, 3)) <= 1900
                    THEN 'MISSING_DOB_SENTINEL'

                WHEN DATEDIFF(
                        YEAR,
                        TRY_CONVERT(DATE, CustomerDOB, 3),
                        '2016-10-21'
                     ) NOT BETWEEN 18 AND 100
                    THEN 'INVALID_DOB'

                WHEN CustLocation IS NULL
                     OR LTRIM(RTRIM(CustLocation)) = ''
                    THEN 'MISSING_LOCATION'

                ELSE 'OK'
            END AS dq_flag

        FROM
        (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY CustomerID
                    ORDER BY dwh_load_date DESC
                ) AS rn

            FROM bronze.crm_customer_info

            WHERE CustomerID IS NOT NULL
        ) t

        WHERE rn = 1;

        SET @end_time = GETDATE();

        PRINT '>> CRM data loaded successfully.';
        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Core Banking Transactions

        SET @start_time = GETDATE();

        PRINT '>> Loading Core Banking transactions...';

        TRUNCATE TABLE silver.core_banking_transactions;

        INSERT INTO silver.core_banking_transactions
        (
            TransactionID,
            CustomerID,
            CustAccountBalance,
            transaction_datetime,
            TransactionAmount,
            balance_tier,
            dq_flag
        )
        SELECT
            TransactionID,
            CustomerID,

            bal AS CustAccountBalance,

            TRY_CONVERT(
                DATETIME2,
                CONVERT(
                    VARCHAR(10),
                    TRY_CONVERT(DATE, TransactionDate, 3),
                    23
                ) + ' ' +
                STUFF(
                    STUFF(
                        RIGHT('000000' + TransactionTime, 6),
                        5,
                        0,
                        ':'
                    ),
                    3,
                    0,
                    ':'
                )
            ) AS transaction_datetime,

            amt AS TransactionAmount,

            CASE
                WHEN bal IS NULL
                    THEN 'Unknown'

                WHEN bal < 10000
                    THEN 'Mass Market'

                WHEN bal <= 100000
                    THEN 'Mass Affluent'

                WHEN bal <= 1000000
                    THEN 'Affluent'

                ELSE 'HNI'
            END AS balance_tier,

            CASE
                WHEN amt IS NULL OR amt <= 0
                    THEN 'ZERO_OR_NEGATIVE_AMOUNT'

                WHEN CustomerID IS NULL
                    THEN 'MISSING_CUSTOMER'

                WHEN bal IS NULL
                    THEN 'MISSING_BALANCE'

                ELSE 'OK'
            END AS dq_flag

        FROM
        (
            SELECT
                TransactionID,
                CustomerID,
                TransactionDate,
                TransactionTime,

                TRY_CONVERT(
                    DECIMAL(18,2),
                    CustAccountBalance
                ) AS bal,

                TRY_CONVERT(
                    DECIMAL(18,2),
                    TransactionAmount
                ) AS amt

            FROM bronze.core_banking_transactions

            WHERE TransactionID IS NOT NULL
        ) src;


        SET @end_time = GETDATE();

        PRINT '>> Core Banking data loaded successfully.';
        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Completion

        SET @batch_end_time = GETDATE();

        PRINT '=======================================';
        PRINT 'Silver Layer Loaded Successfully';
        PRINT '>> Total Duration: '
            + CAST(
                DATEDIFF(
                    SECOND,
                    @batch_start_time,
                    @batch_end_time
                ) AS NVARCHAR
              )
            + ' seconds';
        PRINT '=======================================';


    END TRY

    BEGIN CATCH

        PRINT '=======================================';
        PRINT 'Silver Layer Load Failed';
        PRINT 'Error: ' + ERROR_MESSAGE();
        PRINT '=======================================';

        THROW;

    END CATCH

END;
