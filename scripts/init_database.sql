/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'OlistDataWarehouse' after checking
    if it already exists. If the database exists, it is dropped and recreated.
    The script then sets up three schemas within the database:
    'bronze', 'silver', and 'gold'.

WARNING:
    Running this script will drop the entire 'OlistDataWarehouse' database if it
    exists. All data in the database will be permanently deleted. Proceed with
    caution and make sure you have a backup before running this script.
    (The source database Olist_Retail_DB is NOT touched.)
=============================================================
*/

USE master;
GO

-- Drop and recreate the 'OlistDataWarehouse' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'OlistDataWarehouse')
BEGIN
    ALTER DATABASE OlistDataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OlistDataWarehouse;
END;
GO

-- Create the 'OlistDataWarehouse' database
CREATE DATABASE OlistDataWarehouse;
GO

USE OlistDataWarehouse;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
