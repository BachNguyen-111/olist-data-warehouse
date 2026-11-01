/*
===============================================================================
DDL Script: Create Gold Tables
===============================================================================
Script Purpose:
    This script creates the tables of the Gold layer (Star Schema), dropping
    existing objects if they already exist.
        - gold.dim_customers
        - gold.dim_sellers
        - gold.dim_products
        - gold.fact_orders   (one row per order: delivery and review)
        - gold.fact_sales    (one row per order item: price and freight)

    Gold is stored as TABLES (not views): the star schema is calculated once
    by gold.load_gold, so reports read ready-made rows instead of re-running
    every join on each query. Primary keys add indexes for fast lookups.

    The tables are filled by the stored procedure gold.load_gold.
===============================================================================
*/

USE OlistDataWarehouse;
GO

-- =============================================================================
-- Drop old objects (Gold was views in an earlier version, so views are dropped too)
-- =============================================================================
IF OBJECT_ID('gold.fact_sales', 'V')    IS NOT NULL DROP VIEW gold.fact_sales;
IF OBJECT_ID('gold.fact_sales', 'U')    IS NOT NULL DROP TABLE gold.fact_sales;
IF OBJECT_ID('gold.fact_orders', 'V')   IS NOT NULL DROP VIEW gold.fact_orders;
IF OBJECT_ID('gold.fact_orders', 'U')   IS NOT NULL DROP TABLE gold.fact_orders;
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL DROP VIEW gold.dim_customers;
IF OBJECT_ID('gold.dim_customers', 'U') IS NOT NULL DROP TABLE gold.dim_customers;
IF OBJECT_ID('gold.dim_sellers', 'V')   IS NOT NULL DROP VIEW gold.dim_sellers;
IF OBJECT_ID('gold.dim_sellers', 'U')   IS NOT NULL DROP TABLE gold.dim_sellers;
IF OBJECT_ID('gold.dim_products', 'V')  IS NOT NULL DROP VIEW gold.dim_products;
IF OBJECT_ID('gold.dim_products', 'U')  IS NOT NULL DROP TABLE gold.dim_products;
IF OBJECT_ID('gold.dim_date', 'U')      IS NOT NULL DROP TABLE gold.dim_date;
GO

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
CREATE TABLE gold.dim_customers (
    customer_key        INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    customer_id         NVARCHAR(50)  NOT NULL,     -- Business key from Olist
    customer_unique_id  NVARCHAR(50),               -- Identifies the real person (DQ-07)
    zip_code_prefix     NVARCHAR(10),
    city                NVARCHAR(100),
    state               NVARCHAR(2),
    dwh_create_date     DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_dim_customers PRIMARY KEY (customer_key),
    CONSTRAINT uq_dim_customers_customer_id UNIQUE (customer_id) -- Also an index for the fact lookups
);
GO

-- =============================================================================
-- Create Dimension: gold.dim_sellers
-- =============================================================================
CREATE TABLE gold.dim_sellers (
    seller_key       INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    seller_id        NVARCHAR(50)  NOT NULL,     -- Business key from Olist
    zip_code_prefix  NVARCHAR(10),
    city             NVARCHAR(100),
    state            NVARCHAR(2),
    dwh_create_date  DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_dim_sellers PRIMARY KEY (seller_key),
    CONSTRAINT uq_dim_sellers_seller_id UNIQUE (seller_id)
);
GO

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
CREATE TABLE gold.dim_products (
    product_key          INT IDENTITY(1,1) NOT NULL, -- Surrogate key
    product_id           NVARCHAR(50)  NOT NULL,     -- Business key from Olist
    category_portuguese  NVARCHAR(100),
    category             NVARCHAR(100),              -- English name (falls back to Portuguese)
    name_length          INT,                        -- Source column 'product_name_lenght' (typo fixed)
    description_length   INT,                        -- Source column 'product_description_lenght'
    photos_qty           INT,
    weight_g             INT,
    length_cm            INT,
    height_cm            INT,
    width_cm             INT,
    dwh_create_date      DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_dim_products PRIMARY KEY (product_key),
    CONSTRAINT uq_dim_products_product_id UNIQUE (product_id)
);
GO

-- =============================================================================
-- Create Fact Table: gold.fact_orders
-- =============================================================================
CREATE TABLE gold.fact_orders (
    order_id                 NVARCHAR(50) NOT NULL,
    customer_key             INT,
    order_status             NVARCHAR(20),
    purchase_date            DATETIME2,
    approved_date            DATETIME2,
    carrier_date             DATETIME2,
    delivered_date           DATETIME2,
    estimated_delivery_date  DATETIME2,
    delivery_days            INT,           -- Purchase to customer delivery
    days_late                INT,           -- 0 when on time
    is_late                  INT,           -- 1 = delivered after the estimated date
    delay_bucket             NVARCHAR(20),  -- 'On time', '1-3 days late', ...
    review_count             INT,
    avg_review_score         DECIMAL(3,2),  -- Averaged per order first (DQ-06)
    dwh_create_date          DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_fact_orders PRIMARY KEY (order_id)
);
GO

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
CREATE TABLE gold.fact_sales (
    order_id             NVARCHAR(50) NOT NULL,
    order_item_id        INT          NOT NULL,
    customer_key         INT,
    product_key          INT,
    seller_key           INT,
    order_status         NVARCHAR(20),
    purchase_date        DATETIME2,
    shipping_limit_date  DATETIME2,
    price                DECIMAL(10,2),
    freight_value        DECIMAL(10,2),
    revenue              DECIMAL(10,2),     -- price + freight_value (DQ-11)
    dwh_create_date      DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT pk_fact_sales PRIMARY KEY (order_id, order_item_id)
);
GO
