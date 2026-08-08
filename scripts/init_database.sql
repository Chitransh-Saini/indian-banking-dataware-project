/*
===============================================================================
Create Database and Schemas
===============================================================================
Script Purpose:
    Creates a new database named 'IndianBanking_DataWarehouse', dropping and recreating it
    if it already exists, then sets up three schemas: 'bronze', 'silver',
    and 'gold'.

WARNING:
    Running this script drops the entire 'IndianBanking_DataWarehouse' database if it
    exists. All data in it will be permanently deleted. Make sure you don't
    have anything else relying on a database with this name before running.
===============================================================================
*/

USE master;
GO

-- Drop and recreate the database if it exists
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'IndianBanking_DataWarehouse')
BEGIN
    ALTER DATABASE IndianBanking_DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE IndianBanking_DataWarehouse;
END;
GO

-- Create 'IndianBanking_DataWarehouse' database
CREATE DATABASE IndianBanking_DataWarehouse;
GO

USE IndianBanking_DataWarehouse;
GO

-- Create schemas
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO