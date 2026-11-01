/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables
    if they already exist.
    Run this script to re-define the DDL structure of 'bronze' tables.

Notes:
    - Source system : Olist_Retail_DB (SQL Server), schema dbo
    - Naming rule   : bronze.<sourcesystem>_<entity>  ->  bronze.olist_<source table>
    - Bronze = raw data as-is: same columns and names as the source
      (including the source typo 'lenght'), no primary keys, no NOT NULL,
      no foreign keys, no transformations.
===============================================================================
*/

USE OlistDataWarehouse;
GO

IF OBJECT_ID('bronze.olist_customers', 'U') IS NOT NULL
    DROP TABLE bronze.olist_customers;
GO

CREATE TABLE bronze.olist_customers (
    customer_id              NVARCHAR(50),
    customer_unique_id       NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(10),
    customer_city            NVARCHAR(100),
    customer_state           NVARCHAR(2)
);
GO

IF OBJECT_ID('bronze.olist_sellers', 'U') IS NOT NULL
    DROP TABLE bronze.olist_sellers;
GO

CREATE TABLE bronze.olist_sellers (
    seller_id              NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(10),
    seller_city            NVARCHAR(100),
    seller_state           NVARCHAR(2)
);
GO

IF OBJECT_ID('bronze.olist_products', 'U') IS NOT NULL
    DROP TABLE bronze.olist_products;
GO

CREATE TABLE bronze.olist_products (
    product_id                 NVARCHAR(50),
    product_category_name      NVARCHAR(100),
    product_name_lenght        INT,
    product_description_lenght INT,
    product_photos_qty         INT,
    product_weight_g           INT,
    product_length_cm          INT,
    product_height_cm          INT,
    product_width_cm           INT
);
GO

IF OBJECT_ID('bronze.olist_category_translation', 'U') IS NOT NULL
    DROP TABLE bronze.olist_category_translation;
GO

CREATE TABLE bronze.olist_category_translation (
    product_category_name NVARCHAR(100),
    english_name          NVARCHAR(100)
);
GO

IF OBJECT_ID('bronze.olist_orders', 'U') IS NOT NULL
    DROP TABLE bronze.olist_orders;
GO

CREATE TABLE bronze.olist_orders (
    order_id                      NVARCHAR(50),
    customer_id                   NVARCHAR(50),
    order_status                  NVARCHAR(20),
    order_purchase_timestamp      DATETIME2,
    order_approved_at             DATETIME2,
    order_delivered_carrier_date  DATETIME2,
    order_delivered_customer_date DATETIME2,
    order_estimated_delivery_date DATETIME2
);
GO

IF OBJECT_ID('bronze.olist_order_items', 'U') IS NOT NULL
    DROP TABLE bronze.olist_order_items;
GO

CREATE TABLE bronze.olist_order_items (
    order_id            NVARCHAR(50),
    order_item_id       INT,
    product_id          NVARCHAR(50),
    seller_id           NVARCHAR(50),
    shipping_limit_date DATETIME2,
    price               DECIMAL(10,2),
    freight_value       DECIMAL(10,2)
);
GO

IF OBJECT_ID('bronze.olist_order_payments', 'U') IS NOT NULL
    DROP TABLE bronze.olist_order_payments;
GO

CREATE TABLE bronze.olist_order_payments (
    order_id             NVARCHAR(50),
    payment_sequential   INT,
    payment_type         NVARCHAR(20),
    payment_installments INT,
    payment_value        DECIMAL(10,2)
);
GO

IF OBJECT_ID('bronze.olist_order_reviews', 'U') IS NOT NULL
    DROP TABLE bronze.olist_order_reviews;
GO

CREATE TABLE bronze.olist_order_reviews (
    review_id               NVARCHAR(50),
    order_id                NVARCHAR(50),
    review_score            INT,
    review_creation_date    DATETIME2,
    review_answer_timestamp DATETIME2
);
GO
