/*
-- ADVANCE ANALYTICS
*/

/*========================================================
1. CHANGE OVER TIME
	Analyze how a measure evolves over time. 
	Helps track trends and identify seasonality in your data.
	Aggregate[Measure] By [Dimension]
=========================================================*/
-- Analyse sales performance over time
USE DataWarehouse;
SELECT 
	YEAR(order_date) AS order_year,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date) 
ORDER BY order_year

SELECT 
	DATEPART(YEAR, order_date) AS order_year,
	DATENAME(MONTH, order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATEPART(YEAR, order_date), DATENAME(MONTH, order_date)
ORDER BY order_year, order_month

SELECT 
	DATETRUNC(MONTH, order_date) AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY order_date

SELECT 
	FORMAT(order_date, 'yyyy-MMM') AS order_date,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM') 
ORDER BY order_date







/*===================================================================
2. CUMULATIVE ANALYSIS
	Aggregating the data progressively over time.
	Helps to understand whether our business is growing or declining
	Aggregate[CUMULATIVE MEASURE] By [DATE DIMENSION]
====================================================================*/
-- Calculate the total sales per month and the running total of sales over time
SELECT 
	order_date,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
	AVG(avg_price) OVER(ORDER BY order_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS moving_avg_price 	
FROM (
	SELECT
		DATETRUNC(MONTH, order_date) AS order_date,
		SUM(sales_amount) AS total_sales,
		AVG(price) AS avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(MONTH, order_date)
)t








/*================================================================================================
3. PERFORMANCE ANALYSIS
	Process of comparing the current value to the target value.
	Helps measure success and compare performance.
	Current[Measure] - Target[Measure]
================================================================================================*/
-- Analyse the yearly performance of products by comparing each product's sales to both
-- its average sales performance and the previous year's sales.
WITH yearly_product_sales AS (
	SELECT 
		YEAR(f.order_date) AS order_year,
		p.product_name,
		SUM(f.sales_amount) AS current_sales
	
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	WHERE f.order_date IS NOT NULL
	GROUP BY YEAR(f.order_date), p.product_name
) 
SELECT
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER (PARTITION BY product_name) diff_avg,
	CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
		 WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
		 ELSE 'Avg'
	END avg_change,
	LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC) py_sales,
	current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC) AS diff_py,
	CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC) > 0 THEN 'Increase'
		 WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year ASC) < 0 THEN 'Decrease'
		 ELSE 'No Change'
	END py_change
FROM yearly_product_sales
ORDER BY product_name, order_year






/*==============================================================================
4. PART-TO-WHOLE (Proportional)
	Analyse how an individual part is performing compared to the overall,
	allowing us to understand which category has the greatest impact on the business
	([Measure]/Total[Measure]) * 100 By [Dimension]
==============================================================================*/
-- Which category contribute the most to the overall sales
WITH category_sales AS (
	SELECT 
		p.category,
		SUM(f.sales_amount) AS total_sales
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	GROUP BY p.category
) 
SELECT 
	category,
	total_sales,
	SUM(total_sales) OVER() overall_sales,
	CONCAT ( ROUND(( CAST (total_sales AS FLOAT)/SUM(total_sales) OVER() ) * 100, 2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC







/*=================================================================================
--5. DATA SEGMENTATION
	Group the data based on a specific range.
	Helps understand the correlation between two measures
	[Measure] By [Measure]
===============================================================================*/
-- Segment products into cost ranges and count how many products fall into each segment
WITH product_segment AS (
SELECT
	product_key,
	product_name,
	cost,
	CASE WHEN cost < 100 THEN 'Below 100'
		 WHEN cost BETWEEN 100 AND 499 THEN '100-499'
		 WHEN cost BETWEEN 500 AND 999 THEN '500-999'
		 ELSE '1000 And Above' 
	END cost_range
FROM gold.dim_products
)
SELECT
	cost_range,
	COUNT(product_key) AS Number_of_products
FROM product_segment
GROUP BY cost_range
ORDER BY Number_of_products DESC

/* Group customers into three segments based on their spending behavior:
	- VIP: Customers with at least 12 months of history ans spending more than €5000.
	- Regular: Customers with at least 12 months of history but spending €5000 or less.
	- New: Customers with a lifespan less than 12 months.
And find the total number of customers by each group
*/
WITH customer_spending AS (
SELECT
	c.customer_key,
	SUM(f.sales_amount) AS total_spending,
	MIN(order_date) first_order,
	MAX(order_date) last_order,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
), final_aggregation AS (
SELECT
	customer_key,
	CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
		 WHEN lifespan >= 12 THEN 'Regular'
		 ELSE 'New'
	END customer_segment
FROM customer_spending
)
SELECT
	customer_segment,
	COUNT(customer_key) AS no_of_customers
FROM final_aggregation
GROUP BY customer_segment
ORDER BY no_of_customers DESC









/*====================================================================================
6. REPORTING
====================================================================================*/
/*
======================
Customer Report
======================
Purpose:
	- This report consolidates key customer metrics and behaviors

Highlights:
	i) Gathers essential fields such as names, ages, and transaction details.
	ii) Segments customers into categories (VIP, Regular, New) and age groups.
	iii) Aggregates customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	iv) Calculates valuable KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend
========================================================================================
*/

CREATE VIEW gold.report_customers AS 
WITH base_query AS (
	--1. Base Query: Retrieves core columns from tables
	SELECT 
		f.order_number,
		f.product_key,
		f.order_date,
		f.sales_amount,
		f.quantity,
		c.customer_key,
		c.customer_number,
		CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
		DATEDIFF(YEAR, birthdate, GETDATE()) AS age
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c
	ON f.customer_key = c.customer_key
	WHERE order_date IS NOT NULL
), customer_aggregation AS (
	--2. Customer Aggregations: Summarizes key metrics at the customer level
	SELECT 
		customer_key,
		customer_number,
		customer_name,
		age,
		COUNT(DISTINCT order_number) as total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(DISTINCT product_key) AS total_products,
		MAX(order_date) AS last_order_date,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) lifespan
	FROM base_query
	GROUP BY customer_key, customer_number, customer_name, age
)
SELECT 
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE WHEN age < 20 THEN 'Under 20'
		 WHEN age BETWEEN 20 AND 29 THEN '20-29'
		 WHEN age BETWEEN 30 AND 39 THEN '30-39'
		 WHEN age BETWEEN 40 AND 49 THEN '40-49'
		 ELSE '50 and above'
	END AS age_group,
	CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		 WHEN lifespan >= 12 THEN 'Regular'
		 ELSE 'New'
	END customer_segment,
	last_order_date,
	DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
	total_orders,
	total_sales,
	total_quantity AS total_quantity_purchased,
	total_products,
	-- Compute average order value (AVO)
	ISNULL(total_sales/NULLIF(total_orders, 0), 0) AS avg_order_value,
	-- Compute average monthly spent
	ISNULL(total_sales/NULLIF(lifespan, 0), total_sales) AS avg_monthly_spent
FROM customer_aggregation


SELECT * FROM gold.report_customers;





-- Homework to do
/*
======================
Product Report
======================
Purpose:
	- This report consolidates key product metrics and behaviors

Highlights:
	i) Gathers essential fields such as product name, category, subcategory and cost.
	ii) Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers
	iii) Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in months)
	iv) Calculates valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
========================================================================================
*/

SELECT * FROM gold.dim_products

CREATE VIEW gold.report_products AS
WITH base_query AS (
	SELECT
		f.order_number,
		f.product_key,
		f.customer_key,
		f.order_date,
		f.sales_amount,
		f.quantity,
		p.product_id,
		p.product_name,
		p.category,
		p.subcategory,
		p.product_number,
		p.category_id,
		p.product_line,
		p.cost
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	WHERE f.order_date IS NOT NULL
), product_aggregation AS (
	SELECT
		product_key,
		product_number,
		product_name,
		category,
		subcategory,
		cost,
		COUNT(order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity_sold,
		COUNT(DISTINCT customer_key) AS total_customers,
		MAX(order_date) AS last_order_date,
		DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
	FROM base_query
	GROUP BY product_key, product_number, product_name, category, subcategory, cost
) 
SELECT
	product_key,
	product_number,
	product_name,
	category,
	subcategory,
	cost,
	CASE WHEN total_sales > 1000000 THEN 'High Performer'
		 WHEN total_sales > 100000 THEN 'Mid-Range Performer'
		 ELSE 'Low-Performer'
	END product_segment,
	total_orders,
	total_sales,
	total_quantity_sold,
	total_customers,
	lifespan,
	DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
	-- AVERAGE ORDER REVENUE
	ISNULL(total_sales/ NULLIF(total_orders, 0), total_sales) AS avg_order_revenue,
	-- AVERAGE MONTHLY REVENUE
	ISNULL(total_sales/ NULLIF(lifespan, 0), total_sales) AS avg_monthly_revenue
FROM product_aggregation;