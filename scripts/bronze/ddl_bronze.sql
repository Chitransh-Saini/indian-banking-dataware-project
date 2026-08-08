/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Purpose:
    bronze.raw_bank_transactions is a 1:1 staging copy of the single source
    CSV, exactly as it arrives (all 9 columns, no transformation).

    bronze.crm_customer_info and bronze.core_banking_transactions are the
    two logical source tables the raw staging table gets split into —
    simulating a CRM feed and a Core Banking feed, done entirely in T-SQL
    (see load_bronze.sql). No external scripting needed.
===============================================================================
*/
IF OBJECT_ID('bronze.raw_bank_transactions', 'U') IS NOT NULL
    DROP TABLE bronze.raw_bank_transactions;
GO

CREATE TABLE bronze.raw_bank_transactions (
    TransactionID               NVARCHAR(50),
    CustomerID                  NVARCHAR(50),
    CustomerDOB                 NVARCHAR(20),
    CustGender                  NVARCHAR(10),
    CustLocation                NVARCHAR(100),
    CustAccountBalance          NVARCHAR(50),
    TransactionDate             NVARCHAR(20),
    TransactionTime             NVARCHAR(20),
    [TransactionAmount (INR)]   NVARCHAR(50)
);
GO

IF OBJECT_ID('bronze.crm_customer_info', 'U') IS NOT NULL
    DROP TABLE bronze.crm_customer_info;
GO

CREATE TABLE bronze.crm_customer_info (
    CustomerID       NVARCHAR(50),
    CustomerDOB      NVARCHAR(20),   -- kept as text in bronze; source format is inconsistent (dd/mm/yy)
    CustGender       NVARCHAR(10),
    CustLocation     NVARCHAR(100),
    dwh_load_date    DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('bronze.core_banking_transactions', 'U') IS NOT NULL
    DROP TABLE bronze.core_banking_transactions;
GO

CREATE TABLE bronze.core_banking_transactions (
    TransactionID       NVARCHAR(50),
    CustomerID          NVARCHAR(50),
    CustAccountBalance  NVARCHAR(100),
    TransactionDate     NVARCHAR(20),   -- kept as text in bronze
    TransactionTime     NVARCHAR(20),
    TransactionAmount   NVARCHAR(100),
    dwh_load_date       DATETIME2 DEFAULT GETDATE()
);
GO

