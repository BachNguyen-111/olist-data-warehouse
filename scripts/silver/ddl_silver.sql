/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
    Run this script to re-define the DDL structure of 'silver' tables.

Notes:
    - Same tables and columns as bronze (bronze.olist_<table> -> silver.olist_<table>).
    - New metadata column on every table:
        dwh_create_date : when the row was loaded into the warehouse
                          (filled automatically by DEFAULT GETDATE()).
    - Indexes on the join columns are created at the end of the script
      to speed up the Gold load.
===============================================================================
*/

USE OlistDataWarehouse;
GO

IF OBJECT_ID('silver.olist_customers', 'U') IS NOT NULL
    DROP TABLE silver.olist_customers;
GO

CREATE TABLE silver.olist_customers (
    customer_id              NVARCHAR(50),
    customer_unique_id       NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(10),
    customer_city            NVARCHAR(100),
    customer_state           NVARCHAR(2),
    dwh_create_date          DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.olist_sellers', 'U') IS NOT NULL
    DROP TABLE silver.olist_sellers;
GO

CREATE TABLE silver.olist_sellers (
    seller_id              NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(10),
    seller_city            NVARCHAR(100),
    seller_state           NVARCHAR(2),
    dwh_create_date        DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.olist_products', 'U') IS NOT NULL
    DROP TABLE silver.olist_products;
GO

CREATE TABLE silver.olist_products (
    product_id                 NVARCHAR(50),
    product_category_name      NVARCHAR(100),
    product_name_lenght        INT,
    product_description_lenght INT,
    product_photos_qty         INT,
    product_weight_g           INT,
    product_length_cm          INT,
    product_height_cm          INT,
    product_width_cm           INT,
    dwh_create_date            DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.olist_category_translation', 'U') IS NOT NULL
    DROP TABLE silver.olist_category_translation;
GO

CREATE TABLE silver.olist_category_translation (
    product_category_name NVARCHAR(100),
    english_name          NVARCHAR(100),
    dwh_create_date       DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.olist_orders', 'U') IS NOT NULL
    DROP TABLE silver.olist_orders;
GO

CREATE TABLE silver.olist_orders (
    order_id                      NVARCHAR(50),
    customer_id                   NVARCHAR(50),
    order_status                  NVARCHAR(20),
    order_purchase_timestamp      DATETIME2,
    order_approved_at             DATETIME2,
    order_delivered_carrier_date  DATETIME2,
    order_delivered_customer_date DATETIME2,
    order_estimated_delivery_date DATETIME2,
    dwh_create_date               DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.olist_order_items', 'U') IS NOT NULL
    DROP TABLE silver.olist_order_items;
GO

CREATE TABLE silver.olist_order_items (
    order_id            NVARCHAR(50),
    order_item_id       INT,
    product_id          NVARCHAR(50),
    seller_id           NVARCHAR(50),
    shipping_limit_date DATETIME2,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2),
    dwh_create_date     DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.olist_order_payments', 'U') IS NOT NULL
    DROP TABLE silver.olist_order_payments;
GO

CREATE TABLE silver.olist_order_payments (
    order_id             NVARCHAR(50),
    payment_sequential   INT,
    payment_type         NVARCHAR(20),
    payment_installments INT,
    payment_value        DECIMAL(10,2),
    dwh_create_date      DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.olist_order_reviews', 'U') IS NOT NULL
    DROP TABLE silver.olist_order_reviews;
GO

CREATE TABLE silver.olist_order_reviews (
    review_id               NVARCHAR(50),
    order_id                NVARCHAR(50),
    review_score            INT,
    review_creation_date    DATETIME2,
    review_answer_timestamp DATETIME2,
    dwh_create_date         DATETIME2 DEFAULT GETDATE()
);
GO

-- =============================================================================
-- Indexes
-- =============================================================================
-- Indexes on the columns used to join tables when Gold is loaded.
-- Without them, SQL Server has to scan the whole table for every lookup.
-- TRUNCATE keeps indexes, so they only need to be created once (here).
-- =============================================================================
CREATE INDEX ix_olist_customers_customer_id
    ON silver.olist_customers (customer_id);
GO

CREATE INDEX ix_olist_sellers_seller_id
    ON silver.olist_sellers (seller_id);
GO

CREATE INDEX ix_olist_products_product_id
    ON silver.olist_products (product_id);
GO

CREATE INDEX ix_olist_category_translation_category_name
    ON silver.olist_category_translation (product_category_name);
GO

CREATE INDEX ix_olist_orders_order_id
    ON silver.olist_orders (order_id);
GO

CREATE INDEX ix_olist_order_items_order_id
    ON silver.olist_order_items (order_id);
GO

CREATE INDEX ix_olist_order_reviews_order_id
    ON silver.olist_order_reviews (order_id);
GO
