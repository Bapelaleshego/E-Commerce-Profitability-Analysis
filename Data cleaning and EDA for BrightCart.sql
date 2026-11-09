/* ============================================================
   ORDERS DATA CLEANING PROJECT
   Dataset: orders
   Purpose: Clean and prepare an orders dataset for analysis
   ============================================================ */
   
   /* ============================================================
      UNDERSTAND THE DATA
   ============================================================ */
   
USE brightcart;
   
SELECT *
FROM orders;
   
-- Check number of records

SELECT COUNT(*) AS total_records
FROM orders;

-- Check the columns and data types

DESCRIBE orders;

-- Create another orders table for the cleaning purposes

DROP TABLE IF EXISTS orders_cleaned;

CREATE TABLE orders_cleaned AS
SELECT *
FROM orders;

/* ============================================================
    CHECK  AND REMOVE DUPLICATES
   ============================================================ */

-- Identify duplicate Order IDs

SELECT 
    order_id,
    COUNT(order_id) AS duplicate_count
FROM orders
WHERE order_id IS NOT NULL
GROUP BY order_id
HAVING COUNT(order_id) > 1
ORDER BY duplicate_count DESC;

-- Check for completely duplicated rows

SELECT 
    order_id,
    customer_id,
    order_date,
    channel,
    payment_method,
    region,
    items_ordered,
    primary_category,
    COUNT(*) AS duplicate_count
FROM orders
GROUP BY 
    order_id,
    customer_id,
    order_date,
    channel,
    payment_method,
    region,
    items_ordered,
    primary_category
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Add a unique row number so duplicate records can be identified

ALTER TABLE orders_cleaned
ADD COLUMN row_id INT AUTO_INCREMENT PRIMARY KEY;

SELECT * 
FROM orders_cleaned;

-- Find exact duplicate records

SELECT 
    order_id,
    customer_id,
    order_date,
    channel,
    payment_method,
    region,
    items_ordered,
    primary_category,
    gross_revenue,
    discount_pct,
    discount_amount,
    shipping_cost,
    product_cost,
    platform_fee,
    transaction_fee,
    returned,
    refund_amount,
    net_revenue,
    total_costs,
    profit,
    COUNT(*) AS duplicate_count
FROM orders_cleaned
GROUP BY
    order_id,
    customer_id,
    order_date,
    channel,
    payment_method,
    region,
    items_ordered,
    primary_category,
    gross_revenue,
    discount_pct,
    discount_amount,
    shipping_cost,
    product_cost,
    platform_fee,
    transaction_fee,
    returned,
    refund_amount,
    net_revenue,
    total_costs,
    profit
HAVING COUNT(*) > 1;

-- Delete exact duplicate rows

DELETE FROM orders_cleaned
WHERE row_id IN (
    SELECT row_id
    FROM (
        SELECT 
            row_id,
            ROW_NUMBER() OVER (
                PARTITION BY 
                    order_id,
                    order_date,
                    customer_id,
                    channel,
                    payment_method,
                    region,
                    items_ordered,
                    primary_category,
                    gross_revenue,
                    discount_pct,
                    discount_amount,
                    shipping_cost,
                    product_cost,
                    platform_fee,
                    transaction_fee,
                    returned,
                    refund_amount,
                    net_revenue,
                    total_costs,
                    profit
                ORDER BY row_id
            ) AS duplicate_number
        FROM orders_cleaned
    ) AS duplicates
    WHERE duplicate_number > 1
);

-- Verifying if the duplicated rows are deleted

SELECT 
    order_id,
    COUNT(order_id) AS duplicate_count
FROM orders_cleaned
WHERE order_id IS NOT NULL
GROUP BY order_id
HAVING COUNT(order_id) > 1
ORDER BY duplicate_count DESC;

/* ============================================================
    CHECK MISSING VALUES
   ============================================================ */

SELECT
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(order_date IS NULL) AS missing_order_date,
    SUM(channel IS NULL) AS missing_channel,
    SUM(payment_method IS NULL) AS missing_payment_method,
    SUM(region IS NULL) AS missing_region,
    SUM(primary_category IS NULL) AS missing_category,
    SUM(discount_pct IS NULL) AS missing_discount,
    SUM(shipping_cost IS NULL) AS missing_shipping_cost,
    SUM(returned IS NULL) AS missing_return_status
FROM orders_cleaned;
    
SELECT * 
FROM orders_cleaned;

-- Due to the fact that we got all zeros from the above query we are going to set all the blank values to null

UPDATE orders_cleaned
SET
    order_id = NULLIF(TRIM(order_id), ''),
    customer_id = NULLIF(TRIM(customer_id), ''),
    order_date = NULLIF(TRIM(order_date), ''),
    channel = NULLIF(TRIM(channel), ''),
    payment_method = NULLIF(TRIM(payment_method), ''),
    region = NULLIF(TRIM(region), ''),
    primary_category = NULLIF(TRIM(primary_category), ''),
    discount_pct = NULLIF(TRIM(discount_pct), ''),
    shipping_cost = NULLIF(TRIM(shipping_cost), ''),
    returned = NULLIF(TRIM(returned), '');
    
-- Now lets check for null values

SELECT
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(order_date IS NULL) AS missing_order_date,
    SUM(channel IS NULL) AS missing_channel,
    SUM(payment_method IS NULL) AS missing_payment_method,
    SUM(region IS NULL) AS missing_region,
    SUM(primary_category IS NULL) AS missing_category,
    SUM(discount_pct IS NULL) AS missing_discount,
    SUM(shipping_cost IS NULL) AS missing_shipping_cost,
    SUM(returned IS NULL) AS missing_return_status
FROM orders_cleaned;

/* ============================================================
    HANDLE MISSING VALUES
   ============================================================ */

-- Missing Order IDs cannot safely be reconstructed.
-- Therefore, remove records where Order ID is missing.

DELETE FROM orders_cleaned
WHERE order_id IS NULL;

-- Replace missing categorical values with 'Unknown'

UPDATE orders_cleaned
SET customer_id = 'Unknown'
WHERE customer_id IS NULL;

UPDATE orders_cleaned
SET channel = 'Unknown'
WHERE channel IS NULL;

UPDATE orders_cleaned
SET payment_method = 'Unknown'
WHERE payment_method IS NULL;

UPDATE orders_cleaned
SET region = 'Unknown'
WHERE region IS NULL;

UPDATE orders_cleaned
SET primary_category = 'Unknown'
WHERE primary_category IS NULL;

UPDATE orders_cleaned
SET returned = 'Unknown'
WHERE returned IS NULL;

/* ============================================================
    STANDARDIZE TEXT COLUMNS
   ============================================================ */

-- I started with text columns

SELECT DISTINCT(channel)
FROM orders_cleaned;

SELECT DISTINCT(payment_method)
FROM orders_cleaned;

-- Standardize payment methods

UPDATE orders_cleaned
SET payment_method =
  CASE
        WHEN LOWER(REPLACE(TRIM(payment_method), ' ', '')) = 'creditcard'
            THEN 'Credit Card'

        WHEN LOWER(REPLACE(TRIM(payment_method), ' ', '')) = 'debitcard'
            THEN 'Debit Card'

        ELSE TRIM(payment_method)
    END; 
    
SELECT DISTINCT(payment_method)
FROM orders_cleaned;

SELECT DISTINCT(primary_category)
FROM orders_cleaned;

-- Correcting primary category spelling errors

UPDATE orders_cleaned
SET primary_category =
    CASE

        WHEN LOWER(TRIM(primary_category)) = 'beauti'
            THEN 'Beauty'

        WHEN LOWER(TRIM(primary_category)) = 'cloting'
            THEN 'Clothing'

        WHEN LOWER(TRIM(primary_category)) = 'eletronics'
            THEN 'Electronics'

        ELSE TRIM(primary_category)

    END;

SELECT DISTINCT(primary_category)
FROM orders_cleaned;

SELECT DISTINCT(returned)
FROM orders_cleaned;

-- Standardize return status

UPDATE orders_cleaned
SET returned =
    CASE
        WHEN LOWER(TRIM(returned)) IN ('yes', 'y')
            THEN 'Yes'

        WHEN LOWER(TRIM(returned)) IN ('no', 'n')
            THEN 'No'

        ELSE 'Unknown'
    END;

-- Standardize date format
-- Convert the date column to a proper DATE data type.
-- STR_TO_DATE handles the inconsistent date formats.

ALTER TABLE orders_cleaned
ADD COLUMN cleaned_order_date DATE;


UPDATE orders_cleaned
SET cleaned_order_date =
  CASE
        WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(order_date), '%Y-%m-%d')

        WHEN order_date REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN STR_TO_DATE(TRIM(order_date), '%d/%m/%Y')

        WHEN order_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'
            THEN STR_TO_DATE(TRIM(order_date), '%m-%d-%Y')

        WHEN order_date REGEXP '^[0-9]{4}/[0-9]{2}/[0-9]{2}$'
            THEN STR_TO_DATE(TRIM(order_date), '%Y/%m/%d')

        WHEN order_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
            THEN STR_TO_DATE(TRIM(order_date), '%d-%b-%Y')

        WHEN order_date REGEXP '^[0-9]{2}\\.[0-9]{2}\\.[0-9]{4}$'
            THEN STR_TO_DATE(TRIM(order_date), '%d.%m.%Y')

        ELSE NULL

    END;

/* ============================================================
    CLEAN NUMERIC COLUMNS
   ============================================================ */

-- Convert text-based financial columns into numeric values.

ALTER TABLE orders_cleaned
ADD COLUMN cleaned_gross_revenue DECIMAL(12,2),
ADD COLUMN cleaned_discount_amount DECIMAL(12,2),
ADD COLUMN cleaned_shipping_cost DECIMAL(12,2),
ADD COLUMN cleaned_product_cost DECIMAL(12,2),
ADD COLUMN cleaned_platform_fee DECIMAL(12,2),
ADD COLUMN cleaned_transaction_fee DECIMAL(12,2),
ADD COLUMN cleaned_refund_amount DECIMAL(12,2),
ADD COLUMN cleaned_net_revenue DECIMAL(12,2),
ADD COLUMN cleaned_total_costs DECIMAL(12,2),
ADD COLUMN cleaned_profit DECIMAL(12,2);


UPDATE orders_cleaned
SET
    cleaned_gross_revenue =
        CAST(
            REPLACE(
                REPLACE(TRIM(gross_revenue), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_discount_amount =
        CAST(
            REPLACE(
                REPLACE(TRIM(discount_amount), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_shipping_cost =
        CAST(
            REPLACE(
                REPLACE(TRIM(shipping_cost), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_product_cost =
        CAST(
            REPLACE(
                REPLACE(TRIM(product_cost), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_platform_fee =
        CAST(
            REPLACE(
                REPLACE(TRIM(platform_fee), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_transaction_fee =
        CAST(
            REPLACE(
                REPLACE(TRIM(transaction_fee), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_refund_amount =
        CAST(
            REPLACE(
                REPLACE(TRIM(refund_amount), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_net_revenue =
        CAST(
            REPLACE(
                REPLACE(TRIM(net_revenue), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_total_costs =
        CAST(
            REPLACE(
                REPLACE(TRIM(total_costs), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        ),

    cleaned_profit =
        CAST(
            REPLACE(
                REPLACE(TRIM(profit), 'R', ''),
                ',', ''
            ) AS DECIMAL(12,2)
        );

-- Check invalid quantities first

SELECT *
FROM orders_cleaned
WHERE items_ordered <= 0;

-- Remove records with impossible order quantities

DELETE FROM orders_cleaned
WHERE items_ordered <= 0;

-- Check invalid discount percentages

SELECT *
FROM orders_cleaned
WHERE discount_pct < 0
   OR discount_pct > 100;

-- Replace impossible discounts with NULL
-- rather than assuming what the correct value should be.

UPDATE orders_cleaned
SET discount_pct = NULL
WHERE discount_pct < 0
   OR discount_pct > 100;

-- Check whether Net Revenue is consistent with
-- Gross Revenue minus Discount Amount.

SELECT
    order_id,
    cleaned_gross_revenue,
    cleaned_discount_amount,
    cleaned_net_revenue
FROM orders_cleaned
WHERE ABS(
    cleaned_net_revenue -
    (cleaned_gross_revenue - cleaned_discount_amount)
) > 0.05;

-- Removing the uncleaned columns

ALTER TABLE orders_cleaned
DROP COLUMN order_date,
DROP COLUMN gross_revenue,
DROP COLUMN discount_amount,
DROP COLUMN shipping_cost,
DROP COLUMN product_cost,
DROP COLUMN platform_fee,
DROP COLUMN transaction_fee,
DROP COLUMN refund_amount,
DROP COLUMN net_revenue,
DROP COLUMN total_costs,
DROP COLUMN profit;

SELECT * 
FROM orders_cleaned; 

-- I forgot to remove the row_id column

ALTER TABLE orders_cleaned
DROP COLUMN row_id;

-- Renaming the column

ALTER TABLE orders_cleaned
CHANGE cleaned_order_date order_date DATE,

CHANGE cleaned_gross_revenue gross_revenue DECIMAL(12,2),

CHANGE cleaned_discount_amount discount_amount DECIMAL(12,2),

CHANGE cleaned_shipping_cost shipping_cost DECIMAL(12,2),

CHANGE cleaned_product_cost product_cost DECIMAL(12,2),

CHANGE cleaned_platform_fee platform_fee DECIMAL(12,2),

CHANGE cleaned_transaction_fee transaction_fee DECIMAL(12,2),

CHANGE cleaned_refund_amount refund_amount DECIMAL(12,2),

CHANGE cleaned_net_revenue net_revenue DECIMAL(12,2),

CHANGE cleaned_total_costs total_costs DECIMAL(12,2),

CHANGE cleaned_profit profit DECIMAL(12,2);

/* ============================================================
    FINAL DATA VALIDATION
   ============================================================ */
   
-- Number of records after cleaning

SELECT COUNT(*) AS cleaned_records
FROM orders_cleaned;

-- Number of records after cleaning

SELECT COUNT(*) AS cleaned_records
FROM orders_cleaned;


-- Check for duplicate Order IDs

SELECT
    order_id,
    COUNT(*) AS count
FROM orders_cleaned
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Check for missing Order IDs

SELECT COUNT(*) AS missing_order_ids
FROM orders_cleaned
WHERE order_id IS NULL;

-- Check invalid quantities

SELECT COUNT(*) AS invalid_quantities
FROM orders_cleaned
WHERE items_ordered <= 0;

-- Check invalid discounts

SELECT COUNT(*) AS invalid_discounts
FROM orders_cleaned
WHERE discount_pct < 0
   OR discount_pct > 100;

SELECT *
FROM orders_cleaned;

/* ============================================================
   MARKETING DATA CLEANING PROJECT
   Dataset: marketing_spend 
   Purpose: Clean and prepare an marketing_spend dataset for analysis
   ============================================================ */
   
SELECT *
FROM marketing_spend;

-- The dataset is clean, the only thing that must be corrected is the data type for date_month column

SELECT
    date_month,
    STR_TO_DATE(
        CONCAT('01-', TRIM(date_month)),
        '%d-%b-%y'
    ) AS converted_month
FROM marketing_spend;

-- I get null values for Sept, check what is causing the issue 

SELECT
    date_month,
    LENGTH(date_month) AS length,
    HEX(date_month) AS hex_value
FROM marketing_spend
WHERE LOWER(date_month) LIKE '%sep%';

-- Since all your dates follow a month-year pattern, I standardized the month abbreviation before conversion

SELECT
    date_month,
    STR_TO_DATE(
        CONCAT(
            '01-',
            REPLACE(TRIM(date_month), 'Sept-', 'Sep-')
        ),
        '%d-%b-%y'
    ) AS converted_month
FROM marketing_spend;

-- Create a new date column 

ALTER TABLE marketing_spend
ADD COLUMN month_date DATE;

UPDATE marketing_spend
SET month_date = STR_TO_DATE(
    CONCAT(
        '01-',
        REPLACE(TRIM(date_month), 'Sept-', 'Sep-')
    ),
    '%d-%b-%y'
);

SELECT *
FROM marketing_spend;

-- Remove the date_month column

ALTER TABLE marketing_spend
DROP COLUMN date_month;

ALTER TABLE marketing_spend
RENAME COLUMN month_date TO date_month;

/* ============================================================
   PERFORM DATA EXPLORITORY ANALYSIS TO BETTER UNDERSTAND THE DATA 
   ============================================================ */ 
   
-- I will start by understand the orders_cleaned dataset
-- The number of customers we have 

SELECT
    COUNT(DISTINCT customer_id) AS total_customers
FROM orders_cleaned;
-- We have 716 customers 

-- Check the date range 

SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM orders_cleaned;
-- The order date ranges from January 2024 to January 2026

-- Perfom the numerical statistics to better understand the dataset

SELECT
    COUNT(*) AS total_orders,
    ROUND(AVG(items_ordered), 2) AS avg_items_ordered,
    ROUND(AVG(gross_revenue), 2) AS avg_gross_revenue,
    ROUND(AVG(net_revenue), 2) AS avg_net_revenue,
    ROUND(AVG(profit), 2) AS avg_profit,
    ROUND(MIN(profit), 2) AS min_profit,
    ROUND(MAX(profit), 2) AS max_profit
FROM orders_cleaned;

-- Overall financial performance

SELECT
    ROUND(SUM(gross_revenue), 2) AS total_gross_revenue,
    ROUND(SUM(discount_amount), 2) AS total_discounts,
    ROUND(SUM(refund_amount), 2) AS total_refunds,
    ROUND(SUM(net_revenue), 2) AS total_net_revenue,
    ROUND(SUM(total_costs), 2) AS total_costs,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders_cleaned;
-- Total net revenue is approximately 216,058.21, while total profit is approximately 50,559.61

-- Orders, revenue and profit by sales channel

SELECT
    channel,
    COUNT(*) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders_cleaned
GROUP BY channel
ORDER BY total_orders DESC;

-- Which category has the highest orders, revenue and profit

SELECT
    primary_category,
    COUNT(*) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders_cleaned
GROUP BY primary_category
ORDER BY total_revenue DESC;

-- Let's invistigate the returns 

-- What is the distribution between the returns

SELECT
    returned,
    COUNT(*) AS total_orders
FROM orders_cleaned
GROUP BY returned;

-- What is the return rate 

SELECT
    COUNT(*) AS total_orders,
    SUM(returned = 'Yes') AS returned_orders,
    ROUND(
        100.0 * SUM(returned = 'Yes') / COUNT(*),
        2
    ) AS return_rate_pct
FROM orders_cleaned;
-- We have 8.6% of returns

-- Which category has the highest return rate

SELECT
    primary_category,
    COUNT(*) AS total_orders,
    SUM(returned = 'Yes') AS returned_orders,
    ROUND(
        100.0 * SUM(returned = 'Yes') / COUNT(*),
        2
    ) AS return_rate_pct
FROM orders_cleaned
GROUP BY primary_category
ORDER BY return_rate_pct DESC;
-- Beside the unknown, clothing has the highest return rate 

-- Look for loss-making orders

SELECT
    COUNT(*) AS loss_making_orders,
    ROUND(SUM(profit), 2) AS total_loss
FROM orders_cleaned
WHERE profit < 0;
-- We have 527 orders that made a 17 158, 81 total loss

-- What are the actual orders that return a loss

SELECT
    order_id,
    primary_category,
    gross_revenue,
    discount_pct,
    refund_amount,
    total_costs,
    profit
FROM orders_cleaned
WHERE profit < 0
ORDER BY profit ASC;
-- Electronics has highest return rate

-- Monthly sales trends

SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit
FROM orders_cleaned
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

-- Marketing EDA

-- Get to understand the dataset 

SELECT
    MIN(date_month) AS first_month,
    MAX(date_month) AS last_month,
    COUNT(DISTINCT platform) AS total_platforms,
    SUM(spend) AS total_marketing_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(conversions) AS total_conversions,
    SUM(revenue_attributed) AS attributed_revenue
FROM marketing_spend;

-- Which platform performs better in terms of markerting

SELECT
    platform,
    ROUND(SUM(spend), 2) AS total_spend,
    SUM(impressions) AS total_impressions,
    SUM(clicks) AS total_clicks,
    SUM(conversions) AS total_conversions,
    ROUND(SUM(revenue_attributed), 2) AS attributed_revenue
FROM marketing_spend
GROUP BY platform
ORDER BY attributed_revenue DESC;
-- Influencer and Google Ads are major attributed-revenue channels

-- Marketing efficiency

SELECT
    platform,
    ROUND(SUM(spend), 2) AS total_spend,
    SUM(conversions) AS total_conversions,
    ROUND(SUM(revenue_attributed), 2) AS revenue_attributed,

    ROUND(
        SUM(revenue_attributed) / SUM(spend),
        2
    ) AS overall_roas,

    ROUND(
        SUM(spend) / SUM(conversions),
        2
    ) AS overall_cpa

FROM marketing_spend
GROUP BY platform
ORDER BY overall_roas DESC;
-- TikTok Ads has the highest ROAS AND Email Marketing has the highest CPA with the lowest ROAS, which is expensive and we should visit the pricing 

-- Marketing performance over time

SELECT
    date_month,
    ROUND(SUM(spend), 2) AS marketing_spend,
    SUM(conversions) AS conversions,
    ROUND(SUM(revenue_attributed), 2) AS attributed_revenue,
    ROUND(
        SUM(revenue_attributed) / SUM(spend),
        2
    ) AS roas
FROM marketing_spend
GROUP BY date_month
ORDER BY date_month;

-- Products EDA

-- Start by understanding the product catalogue
SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT category) AS total_categories,
    COUNT(DISTINCT sub_category) AS total_subcategories,
    COUNT(DISTINCT supplier) AS total_suppliers
FROM products;

-- Explore potential product margins

SELECT
    product_id,
    product_name,
    category,
    unit_cost,
    selling_price,
    ROUND(selling_price - unit_cost, 2) AS potential_margin
FROM products
ORDER BY potential_margin DESC;
-- Electronics has the highest profit margins

-- Validate order_items before joining, due to the fact that the orders table was cleaned 

SELECT
    COUNT(DISTINCT oi.order_id) AS unmatched_orders
FROM order_items oi
LEFT JOIN orders_cleaned o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Deleting the unmatched orders due to the fact that the orders table was cleaned 

DELETE oi
FROM order_items oi
LEFT JOIN orders_cleaned o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

/* ============================================================
   Now I want to do advanced analysis to answer some of the 
   business questions
   ============================================================ */
   
   -- Which sales channel generates the most revenue and profit
   
   WITH channel_performance AS (
    SELECT
        channel,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(net_revenue) AS total_revenue,
        SUM(profit) AS total_profit
    FROM orders_cleaned
    GROUP BY channel
)

SELECT
    channel,
    total_orders,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_profit, 2) AS total_profit
FROM channel_performance
ORDER BY total_revenue DESC;
-- Website and Mobile App are the strongest channels. Together, they account for the large proportion of both revenue and profit.

-- Which product categories generate the highest revenue and profit

WITH category_performance AS (
    SELECT
        primary_category,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(net_revenue) AS total_revenue,
        SUM(profit) AS total_profit
    FROM orders_cleaned
    WHERE primary_category <> 'Unknown'
    GROUP BY primary_category
)

SELECT
    primary_category,
    total_orders,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(
        total_profit / NULLIF(total_revenue, 0) * 100,
        2
    ) AS profit_margin_pct,

    CASE
        WHEN total_profit / NULLIF(total_revenue, 0) >= 0.25
            THEN 'High Profitability'
        WHEN total_profit / NULLIF(total_revenue, 0) >= 0.15
            THEN 'Medium Profitability'
        ELSE 'Low Profitability'
    END AS profitability_level

FROM category_performance
ORDER BY total_revenue DESC;
-- Electronics leads both revenue and profit and has a strong 30.51% profit margin

-- Which products sell the highest number of units

WITH product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.quantity) AS units_sold
    FROM order_items oi

    INNER JOIN products p
        ON oi.product_id = p.product_id

    INNER JOIN orders_cleaned o
        ON oi.order_id = o.order_id

    GROUP BY
        p.product_id,
        p.product_name,
        p.category
)

SELECT
    product_id,
    product_name,
    category,
    units_sold
FROM product_sales
ORDER BY units_sold DESC
LIMIT 10;
-- High unit sales are spread across multiple categories rather than being concentrated in only one category

-- How do discounts affect profitability

WITH discount_analysis AS (
    SELECT
        CASE
            WHEN discount_pct = 0 THEN 'No Discount'
            WHEN discount_pct <= 10 THEN 'Low (0-10%)'
            WHEN discount_pct <= 20 THEN 'Medium (10-20%)'
            ELSE 'High (>20%)'
        END AS discount_group,

        net_revenue,
        profit

    FROM orders_cleaned
    WHERE discount_pct IS NOT NULL
)

SELECT
    discount_group,
    COUNT(*) AS total_orders,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        SUM(profit) / NULLIF(SUM(net_revenue), 0) * 100,
        2
    ) AS profit_margin_pct

FROM discount_analysis
GROUP BY discount_group
ORDER BY profit_margin_pct DESC;
-- As the discount level increases, the observed profit margin decreases, orders without discounts produced approximately a 29.6% margin, compared with only 10.2% for orders discounted above 20%.

-- Which categories have the highest return rates

WITH return_analysis AS (
    SELECT
        primary_category,

        COUNT(*) AS total_orders,

        SUM(
            CASE
                WHEN LOWER(TRIM(returned)) IN ('yes', 'y')
                THEN 1
                ELSE 0
            END
        ) AS returned_orders

    FROM orders_cleaned
    WHERE primary_category <> 'Unknown'

    GROUP BY primary_category
)

SELECT
    primary_category,
    total_orders,
    returned_orders,

    ROUND(
        returned_orders / total_orders * 100,
        2
    ) AS return_rate_pct

FROM return_analysis
ORDER BY return_rate_pct DESC;
-- Clothing has the highest observed return rate at approximately 10.34%

-- Which regions perform best

WITH regional_performance AS (
    SELECT
        region,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(net_revenue) AS total_revenue,
        SUM(profit) AS total_profit
    FROM orders_cleaned
    WHERE region <> 'Unknown'
    GROUP BY region
)

SELECT
    region,
    total_orders,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_profit, 2) AS total_profit,

    CASE
        WHEN total_revenue >= 45000 THEN 'High Revenue'
        WHEN total_revenue >= 40000 THEN 'Medium Revenue'
        ELSE 'Lower Revenue'
    END AS performance_group

FROM regional_performance
ORDER BY total_revenue DESC;
-- Southwest generates the most revenue, while Northeast generates the most profit

-- Which marketing platform performs best

WITH marketing_performance AS (
    SELECT
        platform,
        SUM(spend) AS total_spend,
        SUM(conversions) AS total_conversions,
        SUM(revenue_attributed) AS attributed_revenue,

        SUM(revenue_attributed) /
        NULLIF(SUM(spend), 0) AS calculated_roas,

        SUM(spend) /
        NULLIF(SUM(conversions), 0) AS calculated_cpa

    FROM marketing_spend
    GROUP BY platform
)

SELECT
    platform,
    ROUND(total_spend, 2) AS total_spend,
    total_conversions,
    ROUND(attributed_revenue, 2) AS attributed_revenue,
    ROUND(calculated_roas, 2) AS roas,
    ROUND(calculated_cpa, 2) AS cpa,

    CASE
        WHEN calculated_roas >= 20 THEN 'Excellent'
        WHEN calculated_roas >= 10 THEN 'Strong'
        WHEN calculated_roas >= 5 THEN 'Moderate'
        ELSE 'Weak'
    END AS performance_level

FROM marketing_performance
ORDER BY calculated_roas DESC;
-- TikTok Ads has the highest overall ROAS and lowest CPA, making it the most efficient marketing platform in this dataset
-- Influencer marketing also performs strongly
-- Email Marketing has the lowest ROAS and the highest CPA, indicating comparatively weak efficiency
