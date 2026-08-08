/*
===============================================================================
Load Script: Bronze Layer (Full Load)

Purpose:
1. Load raw bank_transactions.csv into the staging table.
2. Split the raw data into CRM customer data and Core Banking transactions.
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN

    DECLARE 
        @start_time DATETIME,
        @end_time DATETIME,
        @batch_start_time DATETIME,
        @batch_end_time DATETIME;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '=======================================';
        PRINT 'Loading Bronze Layer';
        PRINT '=======================================';

        -- Load raw data
        SET @start_time = GETDATE();

        PRINT '>> Loading raw bank transactions...';

        TRUNCATE TABLE bronze.raw_bank_transactions;

        BULK INSERT bronze.raw_bank_transactions
        FROM 'C:\Users\saini\Downloads\bank_transactions_csv\bank_transactions.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>> Raw data loaded successfully.';
        PRINT '>> Duration: ' 
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Load CRM customer data
        SET @start_time = GETDATE();

        PRINT '>> Loading CRM customer data...';

        TRUNCATE TABLE bronze.crm_customer_info;

        INSERT INTO bronze.crm_customer_info
            (CustomerID, CustomerDOB, CustGender, CustLocation)
        SELECT
            CustomerID,
            CustomerDOB,
            CustGender,
            CustLocation
        FROM (
            SELECT
                CustomerID,
                CustomerDOB,
                CustGender,
                CustLocation,
                ROW_NUMBER() OVER (
                    PARTITION BY CustomerID
                    ORDER BY TransactionID
                ) AS rn
            FROM bronze.raw_bank_transactions
            WHERE CustomerID IS NOT NULL
        ) t
        WHERE rn = 1;

        SET @end_time = GETDATE();

        PRINT '>> CRM data loaded successfully.';
        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Load Core Banking transaction data
        SET @start_time = GETDATE();

        PRINT '>> Loading Core Banking transactions...';

        TRUNCATE TABLE bronze.core_banking_transactions;

        INSERT INTO bronze.core_banking_transactions
            (
                TransactionID,
                CustomerID,
                CustAccountBalance,
                TransactionDate,
                TransactionTime,
                TransactionAmount
            )
        SELECT
            TransactionID,
            CustomerID,
            CustAccountBalance,
            TransactionDate,
            TransactionTime,
            [TransactionAmount (INR)]
        FROM bronze.raw_bank_transactions
        WHERE TransactionID IS NOT NULL;

        SET @end_time = GETDATE();

        PRINT '>> Core Banking data loaded successfully.';
        PRINT '>> Duration: '
            + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR)
            + ' seconds';


        -- Completion
        SET @batch_end_time = GETDATE();

        PRINT '=======================================';
        PRINT 'Bronze Layer Loaded Successfully';
        PRINT '>> Total Duration: '
            + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR)
            + ' seconds';
        PRINT '=======================================';

    END TRY

    BEGIN CATCH

        PRINT '=======================================';
        PRINT 'Bronze Layer Load Failed';
        PRINT 'Error: ' + ERROR_MESSAGE();
        PRINT '=======================================';

        THROW;

    END CATCH

END;