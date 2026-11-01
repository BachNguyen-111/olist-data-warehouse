/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accuracy,
    and standardization across the 'silver' layer. It includes checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid values and date orders.
    - Data consistency between related tables.

Usage Notes:
    - Run these checks after data loading Silver Layer.
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

USE OlistDataWarehouse;
GO

-- ====================================================================
-- Checking 'silver.olist_customers'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    customer_id,
    COUNT(*)
FROM silver.olist_customers
GROUP BY customer_id
HAVING COUNT(*) > 1 OR customer_id IS NULL;

-- Check for Unwanted Spaces
-- Expectation: No Results
SELECT customer_city, customer_state
FROM silver.olist_customers
WHERE customer_city  != TRIM(customer_city)
   OR customer_state != TRIM(customer_state);

-- Check Zip Code Format (always 5 digits)
-- Expectation: No Results
SELECT customer_zip_code_prefix
FROM silver.olist_customers
WHERE LEN(customer_zip_code_prefix) <> 5;

-- Data Standardization & Consistency
-- Expectation: 27 uppercase state codes
SELECT DISTINCT
    customer_state
FROM silver.olist_customers
ORDER BY customer_state;

-- ====================================================================
-- Checking 'silver.olist_sellers'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    seller_id,
    COUNT(*)
FROM silver.olist_sellers
GROUP BY seller_id
HAVING COUNT(*) > 1 OR seller_id IS NULL;

-- Check Zip Code Format (always 5 digits)
-- Expectation: No Results
SELECT seller_zip_code_prefix
FROM silver.olist_sellers
WHERE LEN(seller_zip_code_prefix) <> 5;

-- Data Standardization & Consistency
SELECT DISTINCT
    seller_state
FROM silver.olist_sellers
ORDER BY seller_state;

-- ====================================================================
-- Checking 'silver.olist_products'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    product_id,
    COUNT(*)
FROM silver.olist_products
GROUP BY product_id
HAVING COUNT(*) > 1 OR product_id IS NULL;

-- Check for Missing Categories (DQ-04: replaced with 'uncategorized')
-- Expectation: No Results
SELECT product_id
FROM silver.olist_products
WHERE product_category_name IS NULL OR product_category_name = '';

-- Check for Negative Measurements
-- Expectation: No Results
SELECT *
FROM silver.olist_products
WHERE product_weight_g < 0 OR product_length_cm < 0
   OR product_height_cm < 0 OR product_width_cm < 0;

-- ====================================================================
-- Checking 'silver.olist_category_translation'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    product_category_name,
    COUNT(*)
FROM silver.olist_category_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1 OR product_category_name IS NULL;

-- Check that the CSV header row is gone (DQ-14)
-- Expectation: No Results
SELECT *
FROM silver.olist_category_translation
WHERE product_category_name = 'product_category_name';

-- Categories used by products but missing a translation
-- Expectation: only 'uncategorized' (handled in gold with a fallback)
SELECT DISTINCT p.product_category_name
FROM silver.olist_products p
LEFT JOIN silver.olist_category_translation t
    ON p.product_category_name = t.product_category_name
WHERE t.product_category_name IS NULL;

-- ====================================================================
-- Checking 'silver.olist_orders'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key
-- Expectation: No Results
SELECT
    order_id,
    COUNT(*)
FROM silver.olist_orders
GROUP BY order_id
HAVING COUNT(*) > 1 OR order_id IS NULL;

-- Data Standardization & Consistency
-- Expectation: lowercase statuses (delivered, shipped, canceled, ...)
SELECT
    order_status,
    COUNT(*) AS orders
FROM silver.olist_orders
GROUP BY order_status
ORDER BY orders DESC;

-- Check for Invalid Date Orders (DQ-12: known and kept as-is)
-- Expectation: about 189 orders (166 carrier before purchase, 23 delivered before carrier)
SELECT COUNT(*) AS out_of_order_dates
FROM silver.olist_orders
WHERE order_delivered_carrier_date  < order_purchase_timestamp
   OR order_delivered_customer_date < order_delivered_carrier_date;

-- Delivered orders without a delivery date (DQ-03)
-- Expectation: 8 orders
SELECT COUNT(*) AS delivered_without_date
FROM silver.olist_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- ====================================================================
-- Checking 'silver.olist_order_items'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key (order_id + order_item_id)
-- Expectation: No Results
SELECT
    order_id,
    order_item_id,
    COUNT(*)
FROM silver.olist_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1 OR order_id IS NULL OR order_item_id IS NULL;

-- Check for Invalid Prices
-- Expectation: No Results
SELECT *
FROM silver.olist_order_items
WHERE price IS NULL OR price <= 0
   OR freight_value IS NULL OR freight_value < 0;

-- Check for Orphan Rows (items without an order, product or seller)
-- Expectation: No Results
SELECT oi.*
FROM silver.olist_order_items oi
LEFT JOIN silver.olist_orders   o ON oi.order_id   = o.order_id
LEFT JOIN silver.olist_products p ON oi.product_id = p.product_id
LEFT JOIN silver.olist_sellers  s ON oi.seller_id  = s.seller_id
WHERE o.order_id IS NULL OR p.product_id IS NULL OR s.seller_id IS NULL;

-- ====================================================================
-- Checking 'silver.olist_order_payments'
-- ====================================================================
-- Check for NULLs or Duplicates in Primary Key (order_id + payment_sequential)
-- Expectation: No Results
SELECT
    order_id,
    payment_sequential,
    COUNT(*)
FROM silver.olist_order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1 OR order_id IS NULL;

-- Data Standardization & Consistency
-- Expectation: lowercase payment types ('not_defined' is known, DQ-10)
SELECT DISTINCT
    payment_type
FROM silver.olist_order_payments;

-- ====================================================================
-- Checking 'silver.olist_order_reviews'
-- ====================================================================
-- Check for Duplicates in the Key (review_id + order_id, DQ-06)
-- Expectation: No Results
SELECT
    review_id,
    order_id,
    COUNT(*)
FROM silver.olist_order_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1;

-- Check for Invalid Scores
-- Expectation: No Results
SELECT *
FROM silver.olist_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5 OR review_score IS NULL;
