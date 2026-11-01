/*
===============================================================================
Stored Procedure: Load Gold Layer (Silver -> Gold)
===============================================================================
Script Purpose:
    This stored procedure loads the Gold star schema from the Silver layer.
    It performs the following actions:
    - Truncates the gold tables (full load, same as Bronze and Silver).
    - Inserts the dimensions first, then the facts, which look up the
      surrogate keys (customer_key, product_key, seller_key) from the dimensions.

    Surrogate keys are IDENTITY columns: TRUNCATE resets them, so every load
    numbers the rows again from 1. The facts are reloaded in the same run,
    so facts and dimensions always match.

Business rules (DQ IDs refer to docs/04_issue_log.md in the Olist analysis project):
    - All order statuses are kept. Filter order_status = 'delivered' in reports (DQ-01).
    - Late = delivered (date) after the estimated delivery date.
    - Delivery and lateness columns are NULL without a delivery date (DQ-03).
    - Review score is averaged per order (DQ-06).
    - Revenue = price + freight_value (DQ-11).

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC gold.load_gold;
===============================================================================
*/

USE OlistDataWarehouse;
GO

CREATE OR ALTER PROCEDURE gold.load_gold AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,
            @batch_start_time DATETIME, @batch_end_time DATETIME,
            @row_count INT;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Gold Layer';
        PRINT '================================================';

        PRINT '------------------------------------------------';
        PRINT 'Loading Dimension Tables';
        PRINT '------------------------------------------------';

        -- gold.dim_customers
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: gold.dim_customers';
        TRUNCATE TABLE gold.dim_customers;
        PRINT '>> Inserting Data Into: gold.dim_customers';
        INSERT INTO gold.dim_customers (
            customer_id,
            customer_unique_id,
            zip_code_prefix,
            city,
            state
        )
        SELECT
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state
        FROM silver.olist_customers
        ORDER BY customer_id;                -- keys are assigned in this order
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- gold.dim_sellers
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: gold.dim_sellers';
        TRUNCATE TABLE gold.dim_sellers;
        PRINT '>> Inserting Data Into: gold.dim_sellers';
        INSERT INTO gold.dim_sellers (
            seller_id,
            zip_code_prefix,
            city,
            state
        )
        SELECT
            seller_id,
            seller_zip_code_prefix,
            seller_city,
            seller_state
        FROM silver.olist_sellers
        ORDER BY seller_id;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- gold.dim_products
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: gold.dim_products';
        TRUNCATE TABLE gold.dim_products;
        PRINT '>> Inserting Data Into: gold.dim_products';
        INSERT INTO gold.dim_products (
            product_id,
            category_portuguese,
            category,
            name_length,
            description_length,
            photos_qty,
            weight_g,
            length_cm,
            height_cm,
            width_cm
        )
        SELECT
            p.product_id,
            p.product_category_name,
            COALESCE(t.english_name, p.product_category_name),   -- falls back to Portuguese / 'uncategorized'
            p.product_name_lenght,
            p.product_description_lenght,
            p.product_photos_qty,
            p.product_weight_g,
            p.product_length_cm,
            p.product_height_cm,
            p.product_width_cm
        FROM silver.olist_products p
        LEFT JOIN silver.olist_category_translation t
            ON p.product_category_name = t.product_category_name
        ORDER BY p.product_id;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        PRINT '------------------------------------------------';
        PRINT 'Loading Fact Tables';
        PRINT '------------------------------------------------';

        -- gold.fact_orders
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: gold.fact_orders';
        TRUNCATE TABLE gold.fact_orders;
        PRINT '>> Inserting Data Into: gold.fact_orders';
        WITH review_per_order AS (           -- DQ-06: average reviews per order first
            SELECT
                order_id,
                COUNT(*)                                                      AS review_count,
                CAST(AVG(CAST(review_score AS DECIMAL(4,2))) AS DECIMAL(3,2)) AS avg_review_score
            FROM silver.olist_order_reviews
            GROUP BY order_id
        ),
        orders AS (
            SELECT
                o.*,
                DATEDIFF(DAY, o.order_estimated_delivery_date,
                              o.order_delivered_customer_date) AS days_late_raw  -- NULL without delivery date
            FROM silver.olist_orders o
        )
        INSERT INTO gold.fact_orders (
            order_id,
            customer_key,
            order_status,
            purchase_date,
            approved_date,
            carrier_date,
            delivered_date,
            estimated_delivery_date,
            delivery_days,
            days_late,
            is_late,
            delay_bucket,
            review_count,
            avg_review_score
        )
        SELECT
            o.order_id,
            cu.customer_key,
            o.order_status,
            o.order_purchase_timestamp,
            o.order_approved_at,
            o.order_delivered_carrier_date,      -- DQ-12: out-of-order dates kept as-is
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date,
            DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date),
            CASE WHEN o.days_late_raw > 0 THEN o.days_late_raw
                 WHEN o.days_late_raw IS NOT NULL THEN 0
            END,
            CASE WHEN o.days_late_raw > 0 THEN 1
                 WHEN o.days_late_raw IS NOT NULL THEN 0
            END,
            CASE WHEN o.days_late_raw IS NULL THEN NULL
                 WHEN o.days_late_raw <= 0  THEN 'On time'
                 WHEN o.days_late_raw <= 3  THEN '1-3 days late'
                 WHEN o.days_late_raw <= 7  THEN '4-7 days late'
                 WHEN o.days_late_raw <= 14 THEN '8-14 days late'
                 ELSE '15+ days late'
            END,
            r.review_count,
            r.avg_review_score
        FROM orders o
        LEFT JOIN gold.dim_customers cu
            ON o.customer_id = cu.customer_id
        LEFT JOIN review_per_order r
            ON o.order_id = r.order_id;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- gold.fact_sales
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: gold.fact_sales';
        TRUNCATE TABLE gold.fact_sales;
        PRINT '>> Inserting Data Into: gold.fact_sales';
        INSERT INTO gold.fact_sales (
            order_id,
            order_item_id,
            customer_key,
            product_key,
            seller_key,
            order_status,
            purchase_date,
            shipping_limit_date,
            price,
            freight_value,
            revenue
        )
        SELECT
            oi.order_id,
            oi.order_item_id,
            cu.customer_key,
            pr.product_key,
            se.seller_key,
            o.order_status,
            o.order_purchase_timestamp,
            oi.shipping_limit_date,
            oi.price,
            oi.freight_value,                    -- DQ-13: freight of 0 is valid (free shipping)
            oi.price + oi.freight_value          -- DQ-11: revenue = price + freight
        FROM silver.olist_order_items oi
        LEFT JOIN silver.olist_orders o
            ON oi.order_id = o.order_id
        LEFT JOIN gold.dim_customers cu
            ON o.customer_id = cu.customer_id
        LEFT JOIN gold.dim_products pr
            ON oi.product_id = pr.product_id
        LEFT JOIN gold.dim_sellers se
            ON oi.seller_id = se.seller_id;
        SET @row_count = @@ROWCOUNT;
        SET @end_time = GETDATE();
        PRINT '>> Rows Inserted: ' + CAST(@row_count AS NVARCHAR);
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT 'Loading Gold Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING GOLD LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END
GO
