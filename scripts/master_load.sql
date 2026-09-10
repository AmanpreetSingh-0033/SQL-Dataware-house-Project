/*
===============================================================================
Master Execution Script: Data Warehouse Build & ETL Pipeline
===============================================================================
Script Purpose:
    Runs the full Data Warehouse build pipeline in sequence:
    1. Executing Bronze Layer Load Procedure (bronze.load_bronze)
    2. Executing Silver Layer Load Procedure (silver.load_silver)
    3. Verifying Gold Layer Views (dim_customers, dim_products, fact_sales)
===============================================================================
*/

USE DataWarehouse;
GO

PRINT '======================================================';
PRINT 'Starting Full Data Warehouse ETL Pipeline';
PRINT '======================================================';

PRINT '>> Step 1: Executing Load Bronze Layer...';
EXEC bronze.load_bronze;
GO

PRINT '>> Step 2: Executing Load Silver Layer...';
EXEC silver.load_silver;
GO

PRINT '>> Step 3: Verifying Gold Layer Views...';
SELECT 'dim_customers' AS object_name, COUNT(*) AS record_count FROM gold.dim_customers
UNION ALL
SELECT 'dim_products', COUNT(*) FROM gold.dim_products
UNION ALL
SELECT 'fact_sales', COUNT(*) FROM gold.fact_sales;
GO

PRINT '======================================================';
PRINT 'Data Warehouse Build Completed Successfully!';
PRINT '======================================================';
