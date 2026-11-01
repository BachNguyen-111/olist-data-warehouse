/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency,
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - The Gold layer gives the same numbers as the Olist analysis project.

Usage Notes:
    - Run after: EXEC gold.load_gold;
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

USE OlistDataWarehouse;
GO

-- ====================================================================
-- Checking 'gold.dim_customers', 'gold.dim_sellers', 'gold.dim_products'
-- ====================================================================
-- Check for Uniqueness of Surrogate Keys
-- Expectation: No results
SELECT customer_key, COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

SELECT seller_key, COUNT(*) AS duplicate_count
FROM gold.dim_sellers
GROUP BY seller_key
HAVING COUNT(*) > 1;

SELECT product_key, COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Every dimension has one row per source row
-- Expectation: silver_rows = gold_rows on each line
SELECT 'customers' AS dimension,
       (SELECT COUNT(*) FROM silver.olist_customers) AS silver_rows,
       (SELECT COUNT(*) FROM gold.dim_customers)     AS gold_rows
UNION ALL
SELECT 'sellers',
       (SELECT COUNT(*) FROM silver.olist_sellers),
       (SELECT COUNT(*) FROM gold.dim_sellers)
UNION ALL
SELECT 'products',
       (SELECT COUNT(*) FROM silver.olist_products),
       (SELECT COUNT(*) FROM gold.dim_products);

-- Every product has a category name
-- Expectation: No results
SELECT product_id
FROM gold.dim_products
WHERE category IS NULL;

-- ====================================================================
-- Checking 'gold.fact_orders' and 'gold.fact_sales'
-- ====================================================================
-- No lost or duplicated rows
-- Expectation: both counts are equal on each line
SELECT 'orders' AS fact,
       (SELECT COUNT(*) FROM silver.olist_orders) AS silver_rows,
       (SELECT COUNT(*) FROM gold.fact_orders)    AS gold_rows
UNION ALL
SELECT 'order items',
       (SELECT COUNT(*) FROM silver.olist_order_items),
       (SELECT COUNT(*) FROM gold.fact_sales);

-- Check the data model connectivity between facts and dimensions
-- The facts look up their keys with LEFT JOINs during the load, so a fact
-- row that found no matching dimension row has a NULL key.
-- Expectation: 0 in every column
SELECT
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS missing_customer,
    SUM(CASE WHEN product_key  IS NULL THEN 1 ELSE 0 END) AS missing_product,
    SUM(CASE WHEN seller_key   IS NULL THEN 1 ELSE 0 END) AS missing_seller
FROM gold.fact_sales;

SELECT
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS missing_customer
FROM gold.fact_orders;

-- Lateness columns are filled exactly when there is a delivery date (DQ-03)
-- Expectation: No results
SELECT order_id, delivered_date, is_late, delay_bucket
FROM gold.fact_orders
WHERE (delivered_date IS NULL     AND (is_late IS NOT NULL OR delay_bucket IS NOT NULL))
   OR (delivered_date IS NOT NULL AND (is_late IS NULL     OR delay_bucket IS NULL));

-- ====================================================================
-- Reconciliation with the Olist analysis project
-- (sql/05_analysis.sql and docs/04_issue_log.md)
-- ====================================================================
-- Expectation: 96,478 delivered orders
SELECT COUNT(*) AS delivered_orders
FROM gold.fact_orders
WHERE order_status = 'delivered';

-- Expectation: R$15,419,773.75 revenue from delivered orders
SELECT SUM(revenue) AS delivered_revenue
FROM gold.fact_sales
WHERE order_status = 'delivered';

-- Expectation: On time 4.29 | 1-3 days late 3.29 | 4-7 days late 2.11
--              8-14 + 15+ days late together = 1.70 (Query 8 groups them as 8+)
SELECT
    delay_bucket,
    COUNT(*)                                       AS orders,
    CAST(AVG(avg_review_score) AS DECIMAL(3,2))    AS avg_review_score
FROM gold.fact_orders
WHERE order_status = 'delivered'
  AND delivered_date IS NOT NULL
GROUP BY delay_bucket
ORDER BY MIN(days_late);
