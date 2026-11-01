/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from the source
    database Olist_Retail_DB. It performs the following actions:
    - Truncates the bronze tables before loading data (full load).
    - Copies every row from Olist_Retail_DB.dbo.<table> into bronze.olist_<table>
      with INSERT INTO ... SELECT (no transformations).
    - Prints the duration and row count of each table load.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC bronze.load_bronze;
===============================================================================
*/

USE OlistDataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,
            @batch_start_time DATETIME, @batch_end_time DATETIME,
            @row_count INT;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        PRINT '------------------------------------------------';
        PRINT 'Loading Master Data Tables';
        PRINT '------------------------------------------------';

        -- bronze.olist_customers
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_customers';
        TRUNCATE TABLE bronze.olist_customers;
        PRINT '>> Inserting Data Into: bronze.olist_customers';
        INSERT INTO bronze.olist_customers (
            customer_id, customer_unique_id, customer_zip_code_prefix,
            customer_city, customer_state
        )
        SELECT
            customer_id, customer_unique_id, customer_zip_code_prefix,
            customer_city, customer_state
        FROM Olist_Retail_DB.dbo.customers;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.olist_sellers
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_sellers';
        TRUNCATE TABLE bronze.olist_sellers;
        PRINT '>> Inserting Data Into: bronze.olist_sellers';
        INSERT INTO bronze.olist_sellers (
            seller_id, seller_zip_code_prefix, seller_city, seller_state
        )
        SELECT
            seller_id, seller_zip_code_prefix, seller_city, seller_state
        FROM Olist_Retail_DB.dbo.sellers;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.olist_products
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_products';
        TRUNCATE TABLE bronze.olist_products;
        PRINT '>> Inserting Data Into: bronze.olist_products';
        INSERT INTO bronze.olist_products (
            product_id, product_category_name, product_name_lenght,
            product_description_lenght, product_photos_qty, product_weight_g,
            product_length_cm, product_height_cm, product_width_cm
        )
        SELECT
            product_id, product_category_name, product_name_lenght,
            product_description_lenght, product_photos_qty, product_weight_g,
            product_length_cm, product_height_cm, product_width_cm
        FROM Olist_Retail_DB.dbo.products;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.olist_category_translation
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_category_translation';
        TRUNCATE TABLE bronze.olist_category_translation;
        PRINT '>> Inserting Data Into: bronze.olist_category_translation';
        INSERT INTO bronze.olist_category_translation (
            product_category_name, english_name
        )
        SELECT
            product_category_name, english_name
        FROM Olist_Retail_DB.dbo.category_translation;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        PRINT '------------------------------------------------';
        PRINT 'Loading Transaction Tables';
        PRINT '------------------------------------------------';

        -- bronze.olist_orders
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_orders';
        TRUNCATE TABLE bronze.olist_orders;
        PRINT '>> Inserting Data Into: bronze.olist_orders';
        INSERT INTO bronze.olist_orders (
            order_id, customer_id, order_status, order_purchase_timestamp,
            order_approved_at, order_delivered_carrier_date,
            order_delivered_customer_date, order_estimated_delivery_date
        )
        SELECT
            order_id, customer_id, order_status, order_purchase_timestamp,
            order_approved_at, order_delivered_carrier_date,
            order_delivered_customer_date, order_estimated_delivery_date
        FROM Olist_Retail_DB.dbo.orders;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.olist_order_items
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_order_items';
        TRUNCATE TABLE bronze.olist_order_items;
        PRINT '>> Inserting Data Into: bronze.olist_order_items';
        INSERT INTO bronze.olist_order_items (
            order_id, order_item_id, product_id, seller_id,
            shipping_limit_date, price, freight_value
        )
        SELECT
            order_id, order_item_id, product_id, seller_id,
            shipping_limit_date, price, freight_value
        FROM Olist_Retail_DB.dbo.order_items;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.olist_order_payments
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_order_payments';
        TRUNCATE TABLE bronze.olist_order_payments;
        PRINT '>> Inserting Data Into: bronze.olist_order_payments';
        INSERT INTO bronze.olist_order_payments (
            order_id, payment_sequential, payment_type,
            payment_installments, payment_value
        )
        SELECT
            order_id, payment_sequential, payment_type,
            payment_installments, payment_value
        FROM Olist_Retail_DB.dbo.order_payments;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.olist_order_reviews
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.olist_order_reviews';
        TRUNCATE TABLE bronze.olist_order_reviews;
        PRINT '>> Inserting Data Into: bronze.olist_order_reviews';
        INSERT INTO bronze.olist_order_reviews (
            review_id, order_id, review_score,
            review_creation_date, review_answer_timestamp
        )
        SELECT
            review_id, order_id, review_score,
            review_creation_date, review_answer_timestamp
        FROM Olist_Retail_DB.dbo.order_reviews;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
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
EXEC bronze.load_bronze;

-- Row counts should match the source (Olist_Retail_DB)
SELECT 'olist_customers' AS table_name, COUNT(*) AS total_rows FROM bronze.olist_customers
UNION ALL SELECT 'olist_sellers',              COUNT(*) FROM bronze.olist_sellers
UNION ALL SELECT 'olist_products',             COUNT(*) FROM bronze.olist_products
UNION ALL SELECT 'olist_category_translation', COUNT(*) FROM bronze.olist_category_translation
UNION ALL SELECT 'olist_orders',               COUNT(*) FROM bronze.olist_orders
UNION ALL SELECT 'olist_order_items',          COUNT(*) FROM bronze.olist_order_items
UNION ALL SELECT 'olist_order_payments',       COUNT(*) FROM bronze.olist_order_payments
UNION ALL SELECT 'olist_order_reviews',        COUNT(*) FROM bronze.olist_order_reviews;

-- Expected: customers 99,441 | sellers 3,095 | products 32,951
--           category_translation 74 (71 from the CSV + 2 rows added in DQ-05
--                                       + 1 CSV header row loaded as data, DQ-14;
--                                       silver removes the header row)
--           orders 99,441 | order_items 112,650 | order_payments 103,886
--           order_reviews 99,224
===============================================================================
*/
