-- High Level Sales Analysis -----------------------------------------------------------------------------------

-- 1. What was the total quantity sold for all products?
SELECT 
	SUM(qty) AS total_qty_sold,
	SUM(price * qty) AS total_revenue,
	SUM(discount * qty * price / 100.0) AS total_discount
FROM balanced_tree.sales;



-- Transaction Analysis -----------------------------------------------------------------------------------------
-- --1. How many unique transactions were there?
SELECT 
	COUNT(DISTINCT txn_id) AS number_unique_transaction
FROM balanced_tree.sales;


-- --2. What is the average unique products purchased in each transaction?
SELECT 
	ROUND(AVG(num_unique_product)) AS avg_unique_products
FROM (
	SELECT
		txn_id,
		COUNT(prod_id) AS num_unique_product
	FROM balanced_tree.sales
	GROUP BY 1
) t;

-- -- 3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?
-- -- CTE calulate revenue per transaction
-- -- find percentile based on CTE
WITH cte_transaction_revenue AS (
	SELECT
		txn_id,
		SUM(price * qty) as revenue
	FROM balanced_tree.sales
	GROUP BY 1
	ORDER BY 2
)
SELECT 
	percentile_cont(0.25) within group (order by revenue) AS percentile_25,
	percentile_cont(0.5) within group (order by revenue) AS percentile_50,
	percentile_cont(0.75) within group (order by revenue) AS percentile_75		
FROM cte_transaction_revenue;

-- --4. What is the average discount value per transaction?
SELECT 
	ROUND(AVG(discount_value),2) AS avg_discount_per_transaction
FROM (
	SELECT
		txn_id,
		SUM(discount * qty * price / 100) AS discount_value
	FROM balanced_tree.sales
	GROUP BY 1
) temp_table;

-- --5. What is the percentage split of all transactions for members vs non-members?
SELECT
	member,
	COUNT(DISTINCT txn_id) AS number_transaction,
	CAST(COUNT (DISTINCT txn_id) AS float)* 100 / 
		CAST((SELECT COUNT(DISTINCT txn_id) FROM balanced_tree.sales) AS float) as percent_transaction
FROM balanced_tree.sales
GROUP BY 1;


-- --6. What is the average revenue for member transactions and non-member transactions?
WITH cte_revenue_per_transaction AS (
	SELECT 
	member,
	txn_id,
	SUM(price * qty) AS revenue_per_transaction
FROM balanced_tree.sales
GROUP BY 1, 2
)
SELECT 
	member,
	ROUND(AVG(revenue_per_transaction),2) AS avg_revenue
FROM cte_revenue_per_transaction
GROUP BY 1;



-- PRODUCT ANALYSIS ------------------------------------------------------------------------------------------
-- --1. What are the top 3 products by total revenue before discount?
SELECT
	pd.product_name,
	sum(s.qty * s.price) AS revenue
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;

-- -- 2. What is the total quantity, revenue and discount for each segment?
SELECT
	pd.segment_name,
	sum(s.qty) AS total_quantity,
	sum(s.qty * s.price) AS total_revenue,
	ROUND(sum(s.qty * s.price * s.discount / 100.0)) AS total_discount
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1;

-- -- 3. What is the top selling product for each segment?
WITH cte_product_segment_rank AS (
	SELECT
		pd.segment_name,
		pd.product_name,
		sum(s.qty) AS total_quantity,
		DENSE_RANK() OVER (
			PARTITION BY pd.segment_name
			ORDER BY sum(s.qty) DESC
		) AS product_rank
	FROM balanced_tree.product_details pd
	INNER JOIN balanced_tree.sales s
	ON s.prod_id = pd.product_id
	GROUP BY 1, 2
)
SELECT
	segment_name,
	product_name as top_selling_product
FROM cte_product_segment_rank
WHERE product_rank = 1;


-- -- 4. What is the total quantity, revenue and discount for each category?

SELECT
	pd.category_name,
	sum(s.qty) AS total_quantity,
	sum(s.qty * s.price) AS total_revenue,
	ROUND(sum(s.qty * s.price * s.discount / 100.0)) AS total_discount
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1;


-- --5. What is the top selling product for each category?

WITH cte_product_cate_rank AS (
	SELECT
		pd.category_name,
		pd.product_name,
		sum(s.qty) AS total_quantity,
		DENSE_RANK() OVER (
			PARTITION BY pd.category_name
			ORDER BY sum(s.qty) DESC
		) AS product_rank
	FROM balanced_tree.product_details pd
	INNER JOIN balanced_tree.sales s
	ON s.prod_id = pd.product_id
	GROUP BY 1, 2
)
SELECT
	category_name,
	product_name as top_selling_product
FROM cte_product_cate_rank
WHERE product_rank = 1;


-- --6. What is the percentage split of revenue by product for each segment?
SELECT 
	pd.segment_name,
	SUM(s.price * s.qty) AS revenue,
	ROUND(SUM(s.price * s.qty) * 100.0
		/(SELECT SUM(price * qty) 
		  FROM balanced_tree.sales ),1)
		AS percent_revenue
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1
ORDER BY 2 DESC;


-- --7. What is the percentage split of revenue by segment for each category?
WITH cte_revenue_per_category AS (
	SELECT
		pd.category_name,
		SUM(s.qty * s.price) AS total_cate_revenue
	FROM balanced_tree.product_details pd
	INNER JOIN balanced_tree.sales s
	ON s.prod_id = pd.product_id
	GROUP BY 1
)
SELECT 
	pd.category_name,
	pd.segment_name,
	SUM(s.price * s.qty) AS revenue,
-- 	r.total_cate_revenue,
	ROUND(SUM(s.price * s.qty) * 100.0
		/ r.total_cate_revenue, 1) 
		AS percent_revenue_by_category
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
INNER JOIN cte_revenue_per_category r
ON pd.category_name = r.category_name
GROUP BY 1, 2, r.total_cate_revenue
ORDER BY 1;

-- --8. What is the percentage split of total revenue by category?

SELECT 
	pd.category_name,
	SUM(s.qty * s.price) AS revenue,
	ROUND(SUM(s.qty * s.price) * 100.0
		/ (SELECT SUM (price * qty) FROM balanced_tree.sales ), 1) AS percent_revenue
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1;

-- --9. What is the total transaction “penetration” for each product? 
-- -- (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)

SELECT
	pd.product_name,
	ROUND (COUNT (s.txn_id) * 100.0
			/ (SELECT COUNT (DISTINCT txn_id) 
		   		FROM balanced_tree.sales), 2)
		AS transaction_penetration

FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id 
GROUP BY 1;	


-- --10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
-- self join 3 table order by product id -> 3 product 1 one row, combine 3 columns & count 

-- transaction_id that has 3 different products
WITH cte_3_prod_transaction_id AS (
	SELECT txn_id	
	FROM balanced_tree.sales	
	GROUP BY 1
	HAVING COUNT(txn_id) = 3
), 
-- transaction and product_detail in transaction with 3 differnet products
cte_3_prod_id AS (
	SELECT s.txn_id, prod_id, pd.product_name
	FROM balanced_tree.sales s
	JOIN cte_3_prod_transaction_id c 
	ON s.txn_id = c.txn_id
	JOIN balanced_tree.product_details pd
	ON s.prod_id = pd.product_id
	ORDER BY s.txn_id, prod_id
), 
-- group result table
combo AS (
	SELECT 
		txn_id,
		string_agg(product_name, ', ') AS combo_name
	FROM cte_3_prod_id
	GROUP BY 1
),
-- calculate combo frequency
combo_frequency AS (
	SELECT 
		combo_name,
		COUNT(combo_name) AS combo_count
	FROM combo
	GROUP BY 1
	ORDER BY 2 DESC
)
-- get combinations that are most ordered
SELECT combo_name
FROM combo_frequency
WHERE combo_count IN (
	SELECT MAX(combo_count) FROM combo_frequency)
;


