/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Purpose:
    Cleaned, typed, deduplicated versions of bronze data, with explicit
    data-quality flags rather than silent row drops.
===============================================================================
*/

IF OBJECT_ID('silver.crm_customer_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_customer_info;
GO

CREATE TABLE silver.crm_customer_info (
    CustomerID       NVARCHAR(50) PRIMARY KEY,
    CustomerDOB      DATE,
    customer_age     INT,
    CustGender       NVARCHAR(10),
    CustLocation     NVARCHAR(100),
    dq_flag          NVARCHAR(50),      -- 'OK', 'INVALID_DOB', 'MISSING_LOCATION'
    dwh_load_date    DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.core_banking_transactions', 'U') IS NOT NULL
    DROP TABLE silver.core_banking_transactions;
GO

CREATE TABLE silver.core_banking_transactions (
    TransactionID        NVARCHAR(50) PRIMARY KEY,
    CustomerID            NVARCHAR(50),
    CustAccountBalance    DECIMAL(18,2),
    transaction_datetime  DATETIME2,
    TransactionAmount     DECIMAL(18,2),
    balance_tier          NVARCHAR(20),  -- computed in load step, used by product_analysis
    dq_flag                NVARCHAR(50),  -- 'OK', 'NEGATIVE_AMOUNT', 'MISSING_CUSTOMER'
    dwh_load_date          DATETIME2 DEFAULT GETDATE()
);
GO

-- Nonclustered index on CustomerID: the PK above is on TransactionID, so
-- without this, every join from transactions back to a customer (used
-- heavily when loading gold.fact_transactions) forces a full table scan
-- across 1M+ rows. This is the single biggest cheap win before touching
-- the gold layer.
CREATE NONCLUSTERED INDEX IX_core_banking_transactions_CustomerID
    ON silver.core_banking_transactions (CustomerID);
GO

CREATE NONCLUSTERED INDEX IX_core_banking_transactions_dq_flag
    ON silver.core_banking_transactions (dq_flag)
    INCLUDE (transaction_datetime, TransactionAmount, CustAccountBalance, balance_tier);
GO
