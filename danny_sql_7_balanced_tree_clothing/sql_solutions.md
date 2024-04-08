# Balanced Tree Clothing SQL Project
- [Balanced Tree Clothing SQL Project](#balanced-tree-clothing-sql-project)
	- [Summary](#summary)
	- [Solution](#solution)
		- [A. High Level Sales Analysis](#a-high-level-sales-analysis)
		- [B. Transaction Analysis](#b-transaction-analysis)
		- [C. PRODUCT ANALYSIS](#c-product-analysis)


## Summary
This file note down my solutions & explanation for project "Balanced Tree Clothing" using PostgreSQL Check the problem [here](https://github.com/NgocHueLy/balanced_tree_clothing/blob/main/case_study_problem.md).


## Solution

### A. High Level Sales Analysis
1. What was the total quantity sold for all products?
2. What is the total generated revenue for all products before discounts?
3. What was the total discount amount for all products?

``` sql
SELECT 
	SUM(qty) AS total_qty_sold,
	SUM(price * qty) AS total_revenue,
	SUM(discount * qty * price / 100.0) AS total_discount
FROM balanced_tree.sales;
```

Output:
| total_qty_sold | total_revenue | total_discount |
| :------------- | :------------ | :------------- |
| 45216          | 1289453       | 156229.14      |

### B. Transaction Analysis

1. How many unique transactions were there?

``` sql
SELECT 
	COUNT(DISTINCT txn_id) AS number_unique_transaction
FROM balanced_tree.sales;
```

Output
| number_unique_transaction |
| :------------------------ |
| 2500                      |


2. What is the average unique products purchased in each transaction?

```sql
SELECT 
	ROUND(AVG(num_unique_product)) AS avg_unique_products
FROM (
	SELECT
		txn_id,
		COUNT(prod_id) AS num_unique_product
	FROM balanced_tree.sales
	GROUP BY 1
) t;
```
Output
| avg_unique_products |
| :------------------ |
| 6                   |


3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?

```sql
-- create revenue cte
WITH cte_transaction_revenue AS (
	SELECT
		txn_id,
		SUM(price * qty) as revenue
	FROM balanced_tree.sales
	GROUP BY 1
	ORDER BY 2
)

-- calculate percentiles
SELECT 
	percentile_cont(0.25) within group (order by revenue) AS percentile_25,
	percentile_cont(0.5) within group (order by revenue) AS percentile_50,
	percentile_cont(0.75) within group (order by revenue) AS percentile_75		
FROM cte_transaction_revenue;
```
Output
| percentile_25 | percentile_50 | percentile_75 |
| :------------ | :------------ | :------------ |
| 375.75        | 509.5         | 647           |


4. What is the average discount value per transaction?

``` sql 

SELECT 
	ROUND(AVG(discount_value),2) AS avg_discount_per_transaction
FROM (
	SELECT
		txn_id,
		SUM(discount * qty * price / 100) AS discount_value
	FROM balanced_tree.sales
	GROUP BY 1
) temp_table;

```

Output: 

| avg_discount_per_transaction |
| :--------------------------- |
| 59.79                        |



\
5. What is the percentage split of all transactions for members vs non-members?

``` sql

SELECT
	member,
	COUNT(DISTINCT txn_id) AS number_transaction,
	CAST(COUNT (DISTINCT txn_id) AS float)* 100 / 
		CAST((SELECT COUNT(DISTINCT txn_id) FROM balanced_tree.sales) AS float) as percent_transaction
FROM balanced_tree.sales
GROUP BY 1;

```

Output: 
| member | number_transaction | percent_transaction |
| :----- | :----------------- | :------------------ |
| FALSE  | 995                | 39.8                |
| TRUE   | 1505               | 60.2                |

\
6. What is the average revenue for member transactions and non-member transactions?

```sql

-- cte to calculate revenue for member and non-member transactions
WITH cte_revenue_per_transaction AS (
	SELECT 
	member,
	txn_id,
	SUM(price * qty) AS revenue_per_transaction
FROM balanced_tree.sales
GROUP BY 1, 2
)

-- average revenue by member
SELECT 
	member,
	ROUND(AVG(revenue_per_transaction),2) AS avg_revenue
FROM cte_revenue_per_transaction
GROUP BY 1;
```

Output: \
| member | avg_revenue |
| :----- | :---------- |
| FALSE  | 515.04      |
| TRUE   | 516.27      |

\

### C. PRODUCT ANALYSIS

1. What are the top 3 products by total revenue before discount?

```sql
SELECT
	pd.product_name,
	sum(s.qty * s.price) AS revenue
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;
```

Output:
| product_name                 | revenue |
| :--------------------------- | :------ |
| Blue Polo Shirt - Mens       | 217683  |
| Grey Fashion Jacket - Womens | 209304  |
| White Tee Shirt - Mens       | 152000  |
|                              |         |
\

2. What is the total quantity, revenue and discount for each segment?

```sql
SELECT
	pd.segment_name,
	sum(s.qty) AS total_quantity,
	sum(s.qty * s.price) AS total_revenue,
	ROUND(sum(s.qty * s.price * s.discount / 100.0)) AS total_discount
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1;
```

Output:

| segment_name | total_quantity | total_revenue | total_discount |
| :----------- | :------------- | :------------ | :------------- |
| Shirt        | 11265          | 406143        | 49594          |
| Jeans        | 11349          | 208350        | 25344          |
| Jacket       | 11385          | 366983        | 44277          |
| Socks        | 11217          | 307977        | 37013          |


\


3. What is the top selling product for each segment?

``` sql
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
```

Output:
| segment_name | top_selling_product           |
| :----------- | :---------------------------- |
| Jacket       | Grey Fashion Jacket - Womens  |
| Jeans        | Navy Oversized Jeans - Womens |
| Shirt        | Blue Polo Shirt - Mens        |
| Socks        | Navy Solid Socks - Mens       |

\

4. What is the total quantity, revenue and discount for each category?

```sql
SELECT
	pd.category_name,
	sum(s.qty) AS total_quantity,
	sum(s.qty * s.price) AS total_revenue,
	ROUND(sum(s.qty * s.price * s.discount / 100.0)) AS total_discount
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1;

```
Output:

| category_name | total_quantity | total_revenue | total_discount |
| :------------ | :------------- | :------------ | :------------- |
| Mens          | 22482          | 714120        | 86608          |
| Womens        | 22734          | 575333        | 69621          |

\

5. What is the top selling product for each category?

```sql

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
```
Output:
| category_name | top_selling_product          |
| :------------ | :--------------------------- |
| Mens          | Blue Polo Shirt - Mens       |
| Womens        | Grey Fashion Jacket - Womens |
|               |                              |
\

6. What is the percentage split of revenue by product for each segment?

```sql
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
```

Output:

| segment_name | revenue | percent_revenue |
| :----------- | :------ | :-------------- |
| Shirt        | 406143  | 31.5            |
| Jacket       | 366983  | 28.5            |
| Socks        | 307977  | 23.9            |
| Jeans        | 208350  | 16.2            |


\

7. What is the percentage split of revenue by segment for each category?

```sql

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

```

Output:

| category_name | segment_name | revenue | percent_revenue_by_category |
| :------------ | :----------- | :------ | :-------------------------- |
| Mens          | Shirt        | 406143  | 56.9                        |
| Mens          | Socks        | 307977  | 43.1                        |
| Womens        | Jacket       | 366983  | 63.8                        |
| Womens        | Jeans        | 208350  | 36.2                        |
|               |              |         |                             |
\

8. What is the percentage split of total revenue by category?
```sql
SELECT 
	pd.category_name,
	SUM(s.qty * s.price) AS revenue,
	ROUND(SUM(s.qty * s.price) * 100.0
		/ (SELECT SUM (price * qty) FROM balanced_tree.sales ), 1) AS percent_revenue
FROM balanced_tree.product_details pd
INNER JOIN balanced_tree.sales s
ON s.prod_id = pd.product_id
GROUP BY 1;

```

Output:
| category_name | revenue | percent_revenue |
| :------------ | :------ | :-------------- |
| Mens          | 714120  | 55.4            |
| Womens        | 575333  | 44.6            |

\



9. What is the total transaction “penetration” for each product? 
-- -- (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
```sql 
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

```
Output:

| product_name                     | transaction_penetration |
| :------------------------------- | :---------------------- |
| White Tee Shirt - Mens           | 50.72                   |
| Navy Solid Socks - Mens          | 51.24                   |
| Grey Fashion Jacket - Womens     | 51                      |
| Navy Oversized Jeans - Womens    | 50.96                   |
| Pink Fluro Polkadot Socks - Mens | 50.32                   |
| Khaki Suit Jacket - Womens       | 49.88                   |
| Black Straight Jeans - Womens    | 49.84                   |
| White Striped Socks - Mens       | 49.72                   |
| Blue Polo Shirt - Mens           | 50.72                   |
| Indigo Rain Jacket - Womens      | 50                      |
| Cream Relaxed Jeans - Womens     | 49.72                   |
| Teal Button Up Shirt - Mens      | 49.68                   |

\


10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?

```sql
WITH cte_3_prod_transaction_id AS (
	SELECT txn_id	
	FROM balanced_tree.sales	
	GROUP BY 1
	HAVING COUNT(txn_id) = 3
), 
-- transaction and product_detail of transactions with 3 differnet products
cte_3_prod_id AS (
	SELECT s.txn_id, prod_id, pd.product_name
	FROM balanced_tree.sales s
	JOIN cte_3_prod_transaction_id c 
	ON s.txn_id = c.txn_id
	JOIN balanced_tree.product_details pd
	ON s.prod_id = pd.product_id
	ORDER BY s.txn_id, prod_id
), 
-- group result table by transaction_id
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
```

Output:

| combo_name |
| :---------------------------------------------------------------------------------------- |
| White Tee Shirt - Mens, Navy Oversized Jeans - Womens, Cream Relaxed Jeans - Womens       |
| White Striped Socks - Mens, Navy Oversized Jeans - Womens, Khaki Suit Jacket - Womens     |
| Navy Oversized Jeans - Womens, Teal Button Up Shirt - Mens, Black Straight Jeans - Womens |
| White Tee Shirt - Mens, Navy Oversized Jeans - Womens, Black Straight Jeans - Womens      |
| Blue Polo Shirt - Mens, Pink Fluro Polkadot Socks - Mens, Navy Oversized Jeans - Womens   |
|                                                                                           |

