/*
============================================================================================
DDL Script: Create Gold Views
=============================================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema)
    
    Each view performs transformations and combines data from the Silver layer
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
============================================================================================
*/

--1. Create dimension customers
--================================
-- Main Query
--================================
-- Since all the information below is describing the customer's information i.e. descriptive information thus it is a DIMENSION TABLE
-- SURROGATE KEYS: System-generated unique identifiers assigned to each record in a table
-- Either define it in DDL or Query-based using Window function(Row_Number)
IF OBJECT_ID('gold.dim_customers', 'V')
  DROP VIEW gold.dim_customers;
GO
  
CREATE VIEW gold.dim_customers AS
SELECT 
	ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,		--> follow naming convensions that all surrogate keys should end with _key as suffix
	ci.cst_id AS customer_id,
	ci.cst_key AS customer_number,
	ci.cst_firstname AS first_name, 
	ci.cst_lastname AS last_name,
	la.cntry AS country,
	ci.cst_marital_status AS marital_status,
	COALESCE(NULLIF(ci.cst_gndr, 'n/a'), ca.gen, 'n/a') AS gender,
	ca.bdate AS birthdate,
	ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON		ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON		ci.cst_key = la.cid
GO



--2. Create Dimension Products
--===============================
-- Main Query
--==============================
-- This is the DIMENSION TABLE
IF OBJECT_ID('gold.dim_products', 'V')
  DROP VIEW gold.dim_products;
GO
  
CREATE VIEW gold.dim_products AS 
SELECT 
	ROW_NUMBER() OVER(ORDER BY prd_start_dt, prd_key) product_key,  --> surrogate key
	pn.prd_id AS product_id,
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,
	pn.cat_id AS category_id,
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance AS maintenance_required,
	pn.prd_cost AS cost,
	pn.prd_line AS product_line,
	pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL		--> filter out all historical data
GO






-- 3. Create fact_sales
-- The crm_sales_details is connecting multiple dimensions as it has multiple measures values and dates and keys thus it is a FACT TABLE
IF OBJECT_ID('gold.fact_sales', 'V')
  DROP VIEW gold.fact_sales;
GO
  
CREATE VIEW gold.fact_sales AS
SELECT
	sd.sls_ord_num AS order_number,
	pr.product_key,
	cu.customer_key,
	sd.sls_order_dt AS order_date,
	sd.sls_ship_dt AS shipping_date,
	sd.sls_due_dt AS due_date,
	sd.sls_sales AS sales_amount,
	sd.sls_quantity AS quantity,
	sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.customer_id;
GO
