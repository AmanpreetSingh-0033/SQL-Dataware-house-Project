--------------------
-- The Secret
--------------------
-- Dimensions and Measures

/*
Ask the question that is the datatype = Number?
- No -> It is a dimension table
- Yes -> Than ask does it make sense to aggregate?
				- No -> It is a dimension
				- Yes -> It is a measure


*/
SELECT DISTINCT		
	category		--> Not numeric data
FROM gold.dim_products

SELECT DISTINCT		
	sales_amount	--> Numeric data
FROM gold.fact_sales

-- DIMENSIONS: Category, Product, Birthdate, ID
-- MEASURE: Sales, Quantity, Age


/*=========================================================================
1. DATABASE EXPLORATION
=========================================================================*/
-- Explore All Objects in the Database
SELECT *
FROM INFORMATION_SCHEMA.TABLES

-- Explore All Columns in the Database
SELECT *
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers'




/*========================================================================
2. DIMENSIONS EXPLORATIONS
	Identifying the unique values (or categories) in each dimension.
	Recognizing how data might be grouped or segmented, which is useful for later analysis.
	We need DISTINCT [DIMENSION]
=========================================================================*/
-- Explore All countries our customers come from 
SELECT DISTINCT country FROM gold.dim_customers

-- Explore All categories "The major Divisions"
SELECT DISTINCT category, subcategory, product_name FROM gold.dim_products
ORDER BY category, subcategory, product_name




/*=========================================================================
3. DATE EXPLORATION
	Identify the earliest and latest dates (boundaries)
	Understand the scope of data and the timespan
	We need MIN/MAX [DATE DIMENSION]
==========================================================================*/
-- Find the date of the first and last order
-- How many years of sales are available
SELECT 
	MIN(order_date) first_order_date,
	MAX(order_date) last_order_date,
	DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS order_range_months
FROM gold.fact_sales

-- Find the youngest and olderst customer
SELECT 
	MIN(birthdate) oldest_bdate,
	DATEDIFF(YEAR, MIN(birthdate), GETDATE()) oldest_AGE,
	MAX(birthdate) youngest_bdate,
	DATEDIFF(YEAR, MAX(birthdate), GETDATE()) youngest_AGE
FROM gold.dim_customers




/*========================================================================
4. MEASURES EXPLORATION
	Calculate the key matric of the business (Big Numbers)
	- Highest Level of Aggregation | Lowest Level of Details
	We use AggregateFunction [DIMENSIONS]
========================================================================*/
-- Find the Total Sales
SELECT SUM(sales_amount) AS total_sales FROM gold.fact_sales
-- Find how many items are sold
SELECT SUM(quantity) AS total_quantity FROM gold.fact_sales
-- Find the average selling price
SELECT AVG(price) AS average_selling_price FROM gold.fact_sales
-- Find the Total number of orders
SELECT COUNT(order_number) AS total_orders FROM gold.fact_sales 
SELECT COUNT(DISTINCT order_number) AS total_orders FROM gold.fact_sales 
-- Find the Total number of products
SELECT COUNT(product_key) AS total_products FROM gold.dim_products 
SELECT COUNT(DISTINCT product_key) AS total_products FROM gold.dim_products 
-- Find the Total number of customers
SELECT COUNT(customer_key) AS total_customers FROM gold.dim_customers
-- Find the Total number of customers that has placed an order
SELECT COUNT(DISTINCT customer_key) AS total_customers FROM gold.fact_sales
-- Generate Report that shows all key metrics of the business
SELECT 'Total Sales' as measure_name, SUM(sales_amount) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity) FROM gold.fact_sales
UNION ALL
SELECT 'Average Price', AVG(price) FROM gold.fact_sales
UNION ALL
SELECT 'Total No. Orders', COUNT(DISTINCT order_number) FROM gold.fact_sales
UNION ALL
SELECT 'Total No. Products', COUNT(product_key) FROM gold.dim_products
UNION ALL
SELECT 'Total No. Customers', COUNT(customer_key) FROM gold.fact_sales



/*========================================================================
5. MAGNITUDE ANALYSIS
	Comparing the measure values by categories. 
	It helps us understand the importance of different categories.
	[Measure] BY [Dimension]
========================================================================*/
-- Find the Total number of Customers by Country
SELECT 
	country,
	COUNT(customer_key) total_Customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_Customers DESC
-- Find total customers by gender
SELECT 
	gender,
	COUNT(gender) total_Customers
FROM gold.dim_customers
GROUP BY gender ORDER BY total_customers DESC
-- Find total products by category
SELECT 
	category,
	COUNT(product_key) total_products
FROM gold.dim_products
GROUP BY category ORDER BY total_products DESC
-- What is the average costs in each category?
SELECT 
	category,
	AVG(cost) Avg_cost
FROM gold.dim_products
GROUP BY category ORDER BY Avg_cost DESC
-- What is the total revenue generated for each category?
SELECT 
	p.category,
	SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY total_revenue DESC
-- Find total revenue generated by each customer
SELECT 
	c.customer_key,
	c.first_name,
	c.last_name,
	SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC
-- What is the distribution of sold items across countries?
SELECT 
	c.country,
	SUM(f.quantity) AS total_distribution
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_distribution DESC






/*=========================================================
6. RANKING ANALYSIS
	Order the value of the dimensions by measures
	Top N performance | Bottom N performance
	We use Rank [DIMENSION] By sumition[Measure] 
=========================================================*/
-- Which 5 products generate the highest revenue?
SELECT TOP 5
	p.product_name,
	SUM(fs.sales_amount) AS product_revenue
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products p
ON fs.product_key = p.product_key
GROUP BY p.product_name
ORDER BY product_revenue DESC
-- What are the 5 worst-performing products in terms of sales?
SELECT TOP 5
	p.product_name,
	SUM(fs.sales_amount) AS product_revenue
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products p
ON fs.product_key = p.product_key
GROUP BY p.product_name
ORDER BY product_revenue
-- Find the top 10 customers who have generated the highest revenue
SELECT *
FROM (
	SELECT
		c.customer_key,
		c.first_name,
		c.last_name,
		SUM(fs.sales_amount) AS product_revenue,
		ROW_NUMBER() OVER (ORDER BY SUM(fs.sales_amount) DESC) AS rank_customers
	FROM gold.fact_sales fs
	LEFT JOIN gold.dim_customers c
	ON fs.customer_key = c.customer_key
	GROUP BY c.customer_key, c.first_name, c.last_name
)t 
WHERE rank_customers <= 10
-- Find the 3 customers with the fewest orders placed
SELECT TOP 3
	c.customer_key,
	c.first_name,
	c.last_name,
	COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers c
ON fs.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_orders




