# Data Catalog for Gold Layer

## Overview
The Gold Layer is the business-level data representation, structured to support analytical and reporting use cases. It consists of **dimension tables** and **fact tables** built from the Olist e-commerce data.

All Gold objects are **tables**, loaded by the stored procedure `gold.load_gold` (`scripts/gold/proc_load_gold.sql`) with a full load (truncate and insert), like Bronze and Silver. The star schema is calculated once per load, so reports read ready-made rows instead of re-running every join on each query.

Surrogate keys (`*_key`) are `IDENTITY` columns. Every load numbers them again from 1, and the facts are reloaded in the same run, so facts and dimensions always match.

Every table also has the technical column `dwh_create_date` (when the row was loaded).

**Business rules used in Gold** (DQ IDs refer to the data quality issue log of the Olist analysis project):
- All order statuses are kept. Filter `order_status = 'delivered'` for delivered KPIs (DQ-01).
- **Late** = delivered (date) after the estimated delivery date.
- Delivery and lateness columns are NULL when the order has no customer delivery date (DQ-03).
- Review scores are averaged per order before they reach the fact (DQ-06).
- **Revenue** = `price + freight_value` (DQ-11).

---

### 1. **gold.dim_customers**
- **Purpose:** Stores customer location details.
- **Grain:** One row per `customer_id`. Olist creates a new `customer_id` for every order, so use `customer_unique_id` to count real people (DQ-07).
- **Columns:**

| Column Name        | Data Type      | Description                                                                         |
|--------------------|----------------|-------------------------------------------------------------------------------------|
| customer_key       | INT            | Surrogate key uniquely identifying each customer record in the dimension table.     |
| customer_id        | NVARCHAR(50)   | Business key from Olist; a new value is created for every order.                    |
| customer_unique_id | NVARCHAR(50)   | Identifies the real person across orders; use it for customer counts and repeat rate. |
| zip_code_prefix    | NVARCHAR(10)   | First 5 digits of the customer's zip code, stored as text to keep leading zeros (e.g., '01037'). |
| city               | NVARCHAR(100)  | Customer city in lowercase (e.g., 'sao paulo').                                     |
| state              | NVARCHAR(2)    | Two-letter Brazilian state code (e.g., 'SP', 'RJ').                                 |

---

### 2. **gold.dim_sellers**
- **Purpose:** Stores seller location details.
- **Grain:** One row per seller.
- **Columns:**

| Column Name     | Data Type      | Description                                                    |
|-----------------|----------------|----------------------------------------------------------------|
| seller_key      | INT            | Surrogate key uniquely identifying each seller.                |
| seller_id       | NVARCHAR(50)   | Business key from Olist.                                       |
| zip_code_prefix | NVARCHAR(10)   | First 5 digits of the seller's zip code, stored as text.       |
| city            | NVARCHAR(100)  | Seller city in lowercase.                                      |
| state           | NVARCHAR(2)    | Two-letter Brazilian state code.                               |

---

### 3. **gold.dim_products**
- **Purpose:** Provides product attributes and the English category name.
- **Grain:** One row per product.
- **Columns:**

| Column Name         | Data Type      | Description                                                                                   |
|---------------------|----------------|-----------------------------------------------------------------------------------------------|
| product_key         | INT            | Surrogate key uniquely identifying each product.                                              |
| product_id          | NVARCHAR(50)   | Business key from Olist.                                                                      |
| category_portuguese | NVARCHAR(100)  | Category name as stored in the source (e.g., 'beleza_saude'); 'uncategorized' when missing (DQ-04). |
| category            | NVARCHAR(100)  | English category name (e.g., 'health_beauty'). Falls back to the Portuguese name when no translation exists. |
| name_length         | INT            | Number of characters in the product name (source column `product_name_lenght`).             |
| description_length  | INT            | Number of characters in the product description (source column `product_description_lenght`). |
| photos_qty          | INT            | Number of product photos.                                                                     |
| weight_g            | INT            | Product weight in grams.                                                                      |
| length_cm           | INT            | Product length in centimeters.                                                                |
| height_cm           | INT            | Product height in centimeters.                                                                |
| width_cm            | INT            | Product width in centimeters.                                                                 |

---

### 4. **gold.fact_orders**
- **Purpose:** Order-level facts for delivery performance and customer satisfaction.
- **Grain:** One row per order (all statuses).
- **Columns:**

| Column Name                 | Data Type     | Description                                                                          |
|-----------------------------|---------------|--------------------------------------------------------------------------------------|
| order_id                    | NVARCHAR(50)  | Unique identifier of the order.                                                      |
| customer_key                | INT           | Surrogate key linking the order to `dim_customers`.                                  |
| order_status                | NVARCHAR(20)  | Order status in lowercase (e.g., 'delivered', 'shipped', 'canceled').                |
| purchase_date               | DATETIME2     | When the customer placed the order.                                                  |
| approved_date               | DATETIME2     | When the payment was approved.                                                       |
| carrier_date                | DATETIME2     | When the order was handed to the carrier.                                            |
| delivered_date              | DATETIME2     | When the order reached the customer.                                                 |
| estimated_delivery_date     | DATETIME2     | Delivery date promised to the customer at purchase.                                  |
| delivery_days               | INT           | Days from purchase to customer delivery.                                             |
| days_late                   | INT           | Days delivered after the estimated date; 0 when on time.                             |
| is_late                     | INT           | 1 = delivered after the estimated date, 0 = on time.                                 |
| delay_bucket                | NVARCHAR(20)  | 'On time', '1-3 days late', '4-7 days late', '8-14 days late', '15+ days late'.      |
| review_count                | INT           | Number of reviews for the order (some orders have more than one).                    |
| avg_review_score            | DECIMAL(3,2)  | Average review score of the order (1–5); NULL if the order has no review.            |

---

### 5. **gold.fact_sales**
- **Purpose:** Item-level sales facts for revenue analysis by product, category, seller and time.
- **Grain:** One row per order item.
- **Columns:**

| Column Name             | Data Type      | Description                                                          |
|-------------------------|----------------|----------------------------------------------------------------------|
| order_id                | NVARCHAR(50)   | Order the item belongs to (joins to `fact_orders`).                  |
| order_item_id           | INT            | Item number within the order (1, 2, 3, ...).                         |
| customer_key            | INT            | Surrogate key linking the item to `dim_customers`.                   |
| product_key             | INT            | Surrogate key linking the item to `dim_products`.                    |
| seller_key              | INT            | Surrogate key linking the item to `dim_sellers`.                     |
| order_status            | NVARCHAR(20)   | Status of the order the item belongs to.                             |
| purchase_date           | DATETIME2      | When the order was placed.                                           |
| shipping_limit_date     | DATETIME2      | Deadline for the seller to hand the item to the carrier.             |
| price                   | DECIMAL(10,2)  | Item price in Brazilian reais (R$).                                  |
| freight_value           | DECIMAL(10,2)  | Shipping cost charged for the item (0 = free shipping, DQ-13).       |
| revenue                 | DECIMAL(10,2)  | `price + freight_value`.                                             |
