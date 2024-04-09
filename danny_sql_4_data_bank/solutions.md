# A. Customer Nodes Exploration

1. How many unique nodes are there on the Data Bank system?

```sql
SELECT COUNT (DISTINCT node_id) AS unique_nodes
FROM dbt.data_bank.customer_nodes;
```
Use COUNT DISCTINCT for unique count, there are 5 unique nodes on system.
| unique_nodes |
| :----------- |
| 5            |

2. What is the number of nodes per region?

```sql
SELECT 
	region_id,
	COUNT (node_id) AS node_counts
FROM dbt.data_bank.customer_nodes
GROUP BY region_id;
```

| region_id | node_counts |
| :-------- | :---------- |
| 1         | 770         |
| 3         | 714         |
| 5         | 616         |
| 4         | 665         |
| 2         | 735         |



3. How many customers are allocated to each region?

```sql
SELECT 
	region_id,
	COUNT (DISTINCT customer_id) AS customer_counts
FROM dbt.data_bank.customer_nodes
GROUP BY region_id;
```
There are duplicated customer_id for each region --> use COUNT DISTINCT
| region_id | customer_counts |
| :-------- | :-------------- |
| 1         | 110             |
| 2         | 105             |
| 3         | 102             |
| 4         | 95              |
| 5         | 88              |


4. How many days on average are customers reallocated to a different node?


```sql
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
```

end_date = '9999-12-31' indicates the current node_id so we will exclude this end_date to remove outliers

| reallocated_days_avg |
| :------------------- |
| 24                   |


5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?

```sql
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
```
| region_id | reallocated_days_mean | reallocated_days_80th | mean_reallocated_days_95th |
| :-------- | :-------------------- | :-------------------- | :------------------------- |
| 1         | 21                    | 34                    | 51                         |
| 2         | 22                    | 34                    | 53.69999999999999          |
| 3         | 22                    | 35                    | 54                         |
| 4         | 22                    | 34.60000000000002     | 52                         |
| 5         | 23                    | 34                    | 51.39999999999998          |


## B. Customer Transactions
1. What is the unique count and total amount for each transaction type?
```sql
SELECT
	txn_type As transaction_type,
	COUNT(txn_type) AS transaction_counts,
	SUM(txn_amount) AS transaction_amounts
FROM dbt.data_bank.customer_transactions
GROUP BY 1;
```

| transaction_type | transaction_counts | transaction_amounts |
| :--------------- | :----------------- | :------------------ |
| purchase         | 1617               | 806537              |
| withdrawal       | 1580               | 793003              |
| deposit          | 2671               | 1359168             |



2. What is the average total historical deposit counts and amounts for all customers?
```sql
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
```

| average_counts | average_amounts |
| :------------- | :-------------- |
| 5              | 2718            |
|                |                 |

3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

```sql
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
```
The condition "either 1 purchase or 1 withdrawal" is not clear for case when customer makes exactrly 1 purchase and 1 withdrawl. This case haven't been talked

| transaction_month      | customer_counts |
| :--------------------- | :-------------- |
| 2020-01-01 00:00:00+00 | 53              |
| 2020-02-01 00:00:00+00 | 36              |
| 2020-03-01 00:00:00+00 | 38              |
| 2020-04-01 00:00:00+00 | 22              |



4. What is the closing balance for each customer at the end of the month?


```sql
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
```

For balance, expenses will be in nagative while deposit is positive

Preview outputs:
| customer_id | end_of_month           | closing_balance |
| :---------- | :--------------------- | :-------------- |
| 1           | 2020-01-31 00:00:00+00 | 312             |
| 1           | 2020-03-31 00:00:00+00 | -640            |
| 2           | 2020-01-31 00:00:00+00 | 549             |
| 2           | 2020-03-31 00:00:00+00 | 610             |
| 3           | 2020-01-31 00:00:00+00 | 144             |
| 3           | 2020-02-29 00:00:00+00 | -821            |
| 3           | 2020-03-31 00:00:00+00 | -1222           |
| 3           | 2020-04-30 00:00:00+00 | -729            |
| 4           | 2020-01-31 00:00:00+00 | 848             |
| 4           | 2020-03-31 00:00:00+00 | 655             |


5. What is the percentage of customers who increase their closing balance by more than 5%?
```sql
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
		cb1.customer_id,
		cb1.end_of_month,
		cb1.closing_balance,	
		cb2.closing_balance AS future_closing_balance,
		cb2.closing_balance/cb1.closing_balance -1 AS percentage_increase,
		-- cb2.closing_balance > cb1.closing_balance to remove records with bigger negative in future closing balance
		CASE 
			WHEN (cb2.closing_balance/cb1.closing_balance -1 >= 0.05 
				AND cb2.closing_balance > cb1.closing_balance ) THEN 1 ELSE 0 
		END AS percentage_increase_flag
	FROM closing_balance cb1
	JOIN closing_balance cb2
	ON cb1.customer_id = cb2.customer_id AND cb1.end_of_month = cb2.previous_end_of_month
	WHERE cb1.closing_balance != 0
)
SELECT
	SUM(percentage_increase_flag) * 1.0 / COUNT(percentage_increase_flag) AS percentage_customer_increase_closing_balance
FROM percentage_increase
```

This question will be interpreted as "What is the percentage of customers who increase their closing balance by more than 5% at the end of the month"


| percentage_customer_increase_closing_balance |
| :------------------------------------------- |
| 0.20966350301984469370                       |
|                                              |