CREATE TABLE PRODUCTS(
product_id INT PRIMARY KEY,
product_name VARCHAR(50),
price FLOAT
);

CREATE TABLE CITY(
city_id INT PRIMARY KEY,
city_name VARCHAR(15),
population INT,
estimated_rent INT,
city_rank INT
);

CREATE TABLE CUSTOMERS(
customer_id INT PRIMARY KEY,
customer_name VARCHAR(20),
city_id INT,
FOREIGN KEY (city_id) REFERENCES CITY(city_id)
);

CREATE TABLE SALES(
sale_id INT PRIMARY KEY,
sale_date DATE,
product_id INT,
FOREIGN KEY(product_id) REFERENCES PRODUCTS(product_id),
customer_id INT,
FOREIGN KEY(customer_id) REFERENCES CUSTOMERS(customer_id),
total FLOAT,
rating INT
);

--Coffee Consumers Count
--How many people in each city are estimated to consume coffee, given that 25% of the population does?
SELECT 
	city_name,
	ROUND(
	(population * 0.25)/1000000, 
	2) as coffee_consumers_in_millions,
	city_rank
FROM city
ORDER BY 2 DESC

--Total Revenue from Coffee Sales
--What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
SELECT C.city_name, SUM(S.total) AS TOTAL_REVENUE
FROM SALES S
JOIN CUSTOMERS CS ON S.customer_id=CS.customer_id
JOIN CITY C ON CS.city_id=C.city_id
WHERE sale_date BETWEEN '2023-10-01' AND '2023-12-31'
GROUP BY C.city_name
ORDER BY TOTAL_REVENUE DESC;

--Sales Count for Each Product
--How many units of each coffee product have been sold?
SELECT product_name, COUNT(S.sale_id) AS Total_quantity_sold,SUM(s.total) AS sales_amout FROM SALES S
LEFT JOIN PRODUCTS P ON S.product_id=P.product_id
GROUP BY P.product_id
ORDER BY 2 DESC;

--Average Sales Amount per City
--What is the average sales amount per customer in each city?
SELECT 
 city_name,ROUND(SUM(S.total)) AS TOTAL_REVENUE,
 ROUND(SUM(S.total)::numeric / COUNT(DISTINCT S.customer_id), 2) AS avg_revenue_per_customer
 
FROM SALES S
JOIN CUSTOMERS C ON S.customer_id = C.customer_id
JOIN CITY CI ON C.city_id = CI.city_id
GROUP BY CI.city_name
ORDER BY 2 DESC;

-- City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current cx, estimated coffee consumers (25%) 

WITH CITY_TABLE AS(
SELECT 
	city_name,
	population,
	ROUND(
	(population * 0.25)/1000000, 
	2) as coffee_consumers_in_millions
	
FROM city

),

CUSTOMER_TABLE AS(
SELECT 
		ci.city_name,
		COUNT(DISTINCT c.customer_id) as unique_cust
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
)

SELECT CUSTOMER_TABLE.city_name,
       CUSTOMER_TABLE.unique_cust,
	   CITY_TABLE.population,
	   CITY_TABLE.coffee_consumers_in_millions
FROM CITY_TABLE
JOIN CUSTOMER_TABLE ON CITY_TABLE.city_name = CUSTOMER_TABLE.city_name

-- Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?
SELECT 
  *            
FROM (
    SELECT 
        CI.city_name,
        P.product_name,
		COUNT(S.sale_id) AS TOTAL_ORDERS,
        SUM(S.total) AS total_sales,
        ROW_NUMBER() OVER (PARTITION BY CI.city_name ORDER BY COUNT(S.SALE_ID) DESC) AS rank
    FROM SALES S
    JOIN products P ON S.product_id = P.product_id
    JOIN customers C ON S.customer_id = C.customer_id
    JOIN city CI ON C.city_id = CI.city_id
    GROUP BY CI.city_name, P.product_name
) AS RANKED
WHERE rank <= 3
ORDER BY city_name, TOTAL_ORDERS DESC;

-- Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?
SELECT CI.city_name, COUNT(DISTINCT S.customer_id) AS unique_customers
FROM CITY ci
JOIN CUSTOMERS C ON CI.city_id = C.city_id
JOIN SALES S ON C.customer_id = S.customer_id
GROUP BY CI.city_name
ORDER BY 2 DESC;

-- Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer
with avg_sales AS (

SELECT 
 city_name,ROUND(SUM(S.total)) AS TOTAL_REVENUE,
 ROUND(SUM(S.total)::numeric / COUNT(DISTINCT S.customer_id), 2) AS avg_revenue_per_customer
 
FROM SALES S
JOIN CUSTOMERS C ON S.customer_id = C.customer_id
JOIN CITY CI ON C.city_id = CI.city_id
GROUP BY CI.city_name
ORDER BY 2 DESC

)
, avg_rent AS(

SELECT CI.city_name,ROUND(SUM(CI.estimated_rent)) AS total_rent,
ROUND((CI.estimated_rent)::numeric / COUNT(DISTINCT S.customer_id)::numeric, 2) AS avg_rent_per_customer
FROM SALES S
JOIN CUSTOMERS C ON S.customer_id = C.customer_id
JOIN CITY CI ON C.city_id = CI.city_id
GROUP BY CI.city_name,CI.estimated_rent
ORDER BY 2 DESC
)

SELECT ar.city_name,avgs.avg_revenue_per_customer,ar.avg_rent_per_customer
FROM avg_rent ar
join avg_sales avgs on ar.city_name=avgs.city_name
GROUP BY 1,ar.avg_rent_per_customer,avgs.avg_revenue_per_customer
ORDER BY 2 DESC;

--Monthly Sales Growth
--Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly).
-- Sales growth rate: Monthly growth per city
WITH monthly_sales AS (
  SELECT 
    ci.city_name,
    TO_CHAR(s.sale_date, 'YYYY-MM') AS sale_month,
    SUM(s.total) AS monthly_sales
  FROM sales s
  JOIN customers c ON s.customer_id = c.customer_id
  JOIN city ci ON c.city_id = ci.city_id
  GROUP BY ci.city_name, TO_CHAR(s.sale_date, 'YYYY-MM')
),

sales_with_growth AS (
  SELECT 
    city_name,
    sale_month,
    monthly_sales,
    LAG(monthly_sales) OVER (PARTITION BY city_name ORDER BY sale_month) AS previous_month_sales
  FROM monthly_sales
)

SELECT 
  city_name,
  sale_month,
  monthly_sales,
  previous_month_sales,
  ROUND(
    ((monthly_sales - previous_month_sales)
    / NULLIF(previous_month_sales, 0))::numeric * 100, 2
  ) AS sales_growth_percent
FROM sales_with_growth
WHERE previous_month_sales IS NOT NULL
ORDER BY city_name, sale_month;

-- Market Potential Analysis
-- Top 3 cities by highest total sales
SELECT 
  ci.city_name,
  SUM(s.total) AS total_sale,
  ci.estimated_rent,
  COUNT(DISTINCT s.customer_id) AS total_customers,
  -- Placeholder: assuming 25% of customers drink coffee
 ROUND(
	(population * 0.25)/1000000, 
	2) AS coffee_consumer_in_million
FROM city ci
JOIN customers c ON ci.city_id = c.city_id
JOIN sales s ON c.customer_id = s.customer_id
GROUP BY ci.city_name, ci.estimated_rent,population
ORDER BY total_sale DESC
LIMIT 3;

--MONTHLY SALES
select to_char(sale_date,'MM-YY'), sum(total)
from sales
group by to_char(sale_date,'MM-YY')
order by 1

