/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
    Actions performed:
    - Truncates the silver tables.
    - Inserts cleansed and standardized data from bronze into silver.

Transformations (DQ IDs refer to the issue log of the analysis project:
    https://github.com/BachNguyen-111/olist-ecommerce-analysis/blob/main/docs/04_issue_log.md):
    - olist_customers / olist_sellers:
        trim spaces, lowercase city, uppercase state,
        restore leading zeros in the zip code prefix (always 5 digits).
    - olist_products:
        missing category -> 'uncategorized' (DQ-04).
    - olist_category_translation:
        remove the CSV header row loaded as data (DQ-14), trim spaces.
    - olist_orders / olist_order_payments:
        trim and lowercase status / payment type values.
    - olist_order_items / olist_order_reviews:
        loaded as-is (no issues that need fixing at row level).

    Silver cleans data but does NOT apply business filters:
    all order statuses are kept (the 'delivered only' rule, DQ-01, belongs in gold).

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/

USE OlistDataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,
            @batch_start_time DATETIME, @batch_end_time DATETIME,
            @row_count INT;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        PRINT '------------------------------------------------';
        PRINT 'Loading Master Data Tables';
        PRINT '------------------------------------------------';

        -- silver.olist_customers
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_customers';
        TRUNCATE TABLE silver.olist_customers;
        PRINT '>> Inserting Data Into: silver.olist_customers';
        INSERT INTO silver.olist_customers (
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state
        )
        SELECT
            TRIM(customer_id),
            TRIM(customer_unique_id),
            RIGHT('00000' + TRIM(customer_zip_code_prefix), 5),  -- restore leading zeros
            LOWER(TRIM(customer_city)),
            UPPER(TRIM(customer_state))
        FROM bronze.olist_customers;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- silver.olist_sellers
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_sellers';
        TRUNCATE TABLE silver.olist_sellers;
        PRINT '>> Inserting Data Into: silver.olist_sellers';
        INSERT INTO silver.olist_sellers (
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state
        )
        SELECT
            TRIM(seller_id),
            RIGHT('00000' + TRIM(seller_zip_code_prefix), 5),    -- restore leading zeros
            LOWER(TRIM(seller_city)),
            UPPER(TRIM(seller_state))
        FROM bronze.olist_sellers;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- silver.olist_products
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_products';
        TRUNCATE TABLE silver.olist_products;
        PRINT '>> Inserting Data Into: silver.olist_products';
        INSERT INTO silver.olist_products (
            product_id,
            product_category_name,
            product_name_lenght,
            product_description_lenght,
            product_photos_qty,
            product_weight_g,
            product_length_cm,
            product_height_cm,
            product_width_cm
        )
        SELECT
            TRIM(product_id),
            CASE
                WHEN product_category_name IS NULL
                  OR TRIM(product_category_name) = '' THEN 'uncategorized'   -- DQ-04
                ELSE TRIM(product_category_name)
            END,
            product_name_lenght,
            product_description_lenght,
            product_photos_qty,
            product_weight_g,
            product_length_cm,
            product_height_cm,
            product_width_cm
        FROM bronze.olist_products;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- silver.olist_category_translation
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_category_translation';
        TRUNCATE TABLE silver.olist_category_translation;
        PRINT '>> Inserting Data Into: silver.olist_category_translation';
        INSERT INTO silver.olist_category_translation (
            product_category_name,
            english_name
        )
        SELECT
            TRIM(product_category_name),
            TRIM(english_name)
        FROM bronze.olist_category_translation
        WHERE product_category_name <> 'product_category_name';         -- DQ-14: drop header row
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        PRINT '------------------------------------------------';
        PRINT 'Loading Transaction Tables';
        PRINT '------------------------------------------------';

        -- silver.olist_orders
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_orders';
        TRUNCATE TABLE silver.olist_orders;
        PRINT '>> Inserting Data Into: silver.olist_orders';
        INSERT INTO silver.olist_orders (
            order_id,
            customer_id,
            order_status,
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,
            order_delivered_customer_date,
            order_estimated_delivery_date
        )
        SELECT
            TRIM(order_id),
            TRIM(customer_id),
            LOWER(TRIM(order_status)),
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,      -- DQ-12: out-of-order dates kept as-is
            order_delivered_customer_date,
            order_estimated_delivery_date
        FROM bronze.olist_orders;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- silver.olist_order_items
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_order_items';
        TRUNCATE TABLE silver.olist_order_items;
        PRINT '>> Inserting Data Into: silver.olist_order_items';
        INSERT INTO silver.olist_order_items (
            order_id,
            order_item_id,
            product_id,
            seller_id,
            shipping_limit_date,
            price,
            freight_value
        )
        SELECT
            TRIM(order_id),
            order_item_id,
            TRIM(product_id),
            TRIM(seller_id),
            shipping_limit_date,
            price,
            freight_value                      -- DQ-13: freight of 0 is valid (free shipping)
        FROM bronze.olist_order_items;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- silver.olist_order_payments
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_order_payments';
        TRUNCATE TABLE silver.olist_order_payments;
        PRINT '>> Inserting Data Into: silver.olist_order_payments';
        INSERT INTO silver.olist_order_payments (
            order_id,
            payment_sequential,
            payment_type,
            payment_installments,
            payment_value
        )
        SELECT
            TRIM(order_id),
            payment_sequential,
            LOWER(TRIM(payment_type)),         -- DQ-10: 'not_defined' kept as-is
            payment_installments,
            payment_value
        FROM bronze.olist_order_payments;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- silver.olist_order_reviews
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.olist_order_reviews';
        TRUNCATE TABLE silver.olist_order_reviews;
        PRINT '>> Inserting Data Into: silver.olist_order_reviews';
        INSERT INTO silver.olist_order_reviews (
            review_id,
            order_id,
            review_score,
            review_creation_date,
            review_answer_timestamp
        )
        SELECT
            TRIM(review_id),
            TRIM(order_id),
            review_score,                      -- DQ-06: per-order averaging happens in gold
            review_creation_date,
            review_answer_timestamp
        FROM bronze.olist_order_reviews;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END
GO

/*
===============================================================================
Run & Check (run these separately after creating the procedure)
===============================================================================
EXEC silver.load_silver;

-- Row counts: same as bronze, except category_translation (header row removed)
SELECT 'olist_customers' AS table_name, COUNT(*) AS total_rows FROM silver.olist_customers
UNION ALL SELECT 'olist_sellers',              COUNT(*) FROM silver.olist_sellers
UNION ALL SELECT 'olist_products',             COUNT(*) FROM silver.olist_products
UNION ALL SELECT 'olist_category_translation', COUNT(*) FROM silver.olist_category_translation
UNION ALL SELECT 'olist_orders',               COUNT(*) FROM silver.olist_orders
UNION ALL SELECT 'olist_order_items',          COUNT(*) FROM silver.olist_order_items
UNION ALL SELECT 'olist_order_payments',       COUNT(*) FROM silver.olist_order_payments
UNION ALL SELECT 'olist_order_reviews',        COUNT(*) FROM silver.olist_order_reviews;

-- Expected: customers 99,441 | sellers 3,095 | products 32,951
--           category_translation 73 (74 in bronze - 1 header row)
--           orders 99,441 | order_items 112,650 | order_payments 103,886
--           order_reviews 99,224
===============================================================================
*/
