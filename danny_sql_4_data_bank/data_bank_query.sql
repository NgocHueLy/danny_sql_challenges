select count(*) from dbt.data_bank.customer_nodes;
select * from dbt.data_bank.customer_transactions;
select * from dbt.data_bank.regions;

-- ################# A. Customer Nodes Exploration

-- 1. How many unique nodes are there on the Data Bank system?

SELECT COUNT (DISTINCT node_id) AS unique_nodes
FROM dbt.data_bank.customer_nodes;

-- 2. What is the number of nodes per region?

SELECT 
	region_id,
	COUNT (node_id) AS node_counts
FROM dbt.data_bank.customer_nodes
GROUP BY region_id;

-- 3. How many customers are allocated to each region?

SELECT 
	region_id,
	COUNT (DISTINCT customer_id) AS customer_counts
FROM dbt.data_bank.customer_nodes
GROUP BY region_id;

-- 4. How many days on average are customers reallocated to a different node?

-- Upon checking some "end_year" has year '9999', this represent the current node of a customer.
-- To calculate the numbers of day a customer stays on a node, current node_id will be removed.
WITH node_reallocated_days AS ( -- data when node_id not a current node
	SELECT
		customer_id,
		node_id,
		region_id,
		SUM(end_date - start_date) AS node_day_counts
	FROM 
		dbt.data_bank.customer_nodes
	WHERE
		end_date != '9999-12-31'
	GROUP BY 1,2,3
)
SELECT ROUND(AVG(node_day_counts),0) AS reallocated_days_avg
FROM node_reallocated_days;



-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH node_reallocated_days AS ( -- data when node_id not a current node
	SELECT
		customer_id,
		node_id,
		region_id,
		SUM(end_date - start_date) AS node_day_counts
	FROM 
		dbt.data_bank.customer_nodes
	WHERE
		end_date != '9999-12-31'
	GROUP BY 1,2,3
)

SELECT
	region_id,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY node_day_counts) AS reallocated_days_mean,
	PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY node_day_counts) AS reallocated_days_80th,
	PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY node_day_counts) AS mean_reallocated_days_95th
FROM
	node_reallocated_days
GROUP BY
	region_id;




-- ################# B. Customer Transactions
-- 1. What is the unique count and total amount for each transaction type?
SELECT
	txn_type As transaction_type,
	COUNT(txn_type) AS transaction_counts,
	SUM(txn_amount) AS transaction_amounts
FROM dbt.data_bank.customer_transactions
GROUP BY 1;

-- 2. What is the average total historical deposit counts and amounts for all customers?
WITH cte AS (
	SELECT 
	customer_id,
	COUNT(customer_id) AS total_counts,
	SUM(txn_amount) AS total_amounts
	FROM dbt.data_bank.customer_transactions
	WHERE txn_type = 'deposit'
	GROUP BY 1
)
SELECT 
	ROUND(AVG(total_counts),0) as average_counts,
	ROUND(AVG(total_amounts),0) AS average_amounts
FROM cte;


-- 3. For each month - how many Data Bank customers make more than 1 deposit
-- and either 1 purchase or 1 withdrawal in a single month?
WITH monthly_txn AS (
	SELECT
		customer_id,
		DATE_TRUNC('month', txn_date) AS transaction_month,
		SUM(CASE WHEN txn_type='deposit' THEN 1 ELSE 0 END) AS deposits,
		SUM(CASE WHEN txn_type!='deposit' THEN 1 ELSE 0 END) AS withdrawls_or_purchases
	FROM dbt.data_bank.customer_transactions
	GROUP BY 1, 2
	ORDER BY 1, 2
)
	
SELECT
	transaction_month,
	COUNT(customer_id) AS customer_counts
FROM monthly_txn
WHERE deposits > 1 AND withdrawls_or_purchases = 1
GROUP BY 1
ORDER BY 1;

-- 4. What is the closing balance for each customer at the end of the month?
-- GET THE LAST BALANCE ROW FOR EACH MONTH
WITH cte AS (
	SELECT 
		customer_id,
		txn_date,
		DATE_TRUNC('month', txn_date) AS txn_month,
		SUM((CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END)
		- (CASE WHEN txn_type != 'deposit' THEN txn_amount ELSE 0 END)) AS balance
	FROM dbt.data_bank.customer_transactions
	GROUP BY customer_id, txn_date, txn_month
), balances AS(
	SELECT
		*,
		SUM(balance) OVER (PARTITION BY customer_id ORDER BY txn_date ) AS running_sum,
		ROW_NUMBER() OVER (PARTITION BY customer_id, txn_month  ORDER BY txn_date DESC ) AS rn
	FROM cte
)
SELECT 
	customer_id,
	txn_month  + interval '1 month' - interval '1 day' AS end_of_month, -- add a month then take away a day
	running_sum AS closing_balance
FROM balances
WHERE rn = 1;
-- 5. What is the percentage of customers who increase their closing balance by more than 5%?

-- can try lead function instead of self join closing_balance CTE
WITH cte AS (
	SELECT 
		customer_id,
		txn_date,
		DATE_TRUNC('month', txn_date) AS txn_month,
		SUM((CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END)
		- (CASE WHEN txn_type != 'deposit' THEN txn_amount ELSE 0 END)) AS balance
	FROM dbt.data_bank.customer_transactions
	GROUP BY customer_id, txn_date, txn_month
), balances AS(
	SELECT
		*,
		SUM(balance) OVER (PARTITION BY customer_id ORDER BY txn_date ) AS running_sum,
		ROW_NUMBER() OVER (PARTITION BY customer_id, txn_month  ORDER BY txn_date DESC ) AS rn
	FROM cte
), closing_balance AS (
	SELECT 
		customer_id,
		txn_month  + interval '1 month' - interval '1 day' AS end_of_month, -- add a month then take away a day
		txn_month - interval '1 day' AS previous_end_of_month,
		running_sum AS closing_balance
	FROM balances
	WHERE rn = 1
), percentage_increase AS (
	SELECT 
		CB1.customer_id,
		CB1.end_of_month,
		CB1.closing_balance,	
		CB2.closing_balance AS future_closing_balance,
		CB2.closing_balance/CB1.closing_balance -1 AS percentage_increase,
		-- CB2.closing_balance > CB1.closing_balance to remove records with bigger negative in future closing balance
		CASE 
			WHEN (CB2.closing_balance/CB1.closing_balance -1 >= 0.05 
				AND CB2.closing_balance > CB1.closing_balance ) THEN 1 ELSE 0 
		END AS percentage_increase_flag
	FROM closing_balance CB1
	JOIN closing_balance CB2
	ON CB1.customer_id = CB2.customer_id AND CB1.end_of_month = CB2.previous_end_of_month
	WHERE CB1.closing_balance != 0
)
SELECT
	SUM(percentage_increase_flag) * 1.0 / COUNT(percentage_increase_flag) AS percentage_customer_increase_closing_balance
FROM percentage_increase

	
