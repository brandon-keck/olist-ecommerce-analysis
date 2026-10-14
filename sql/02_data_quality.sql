-- =====================================================================
-- 02_data_quality.sql
-- Validate keys, nulls, and table relationships before any analysis.
-- =====================================================================


-- ---------------------------------------------------------------------
-- ORDERS
-- ---------------------------------------------------------------------

-- Order status breakdown (~97% delivered)
SELECT order_status, COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Is order_id unique? (Result: yes, 99,441 rows and 99,441 IDs)
SELECT
    COUNT(*)                 AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders
FROM orders;

-- Missing values per date column (COUNT(col) skips NULLs)
SELECT
    COUNT(*) - COUNT(order_approved_at)             AS missing_approved,
    COUNT(*) - COUNT(order_delivered_carrier_date)  AS missing_carrier,
    COUNT(*) - COUNT(order_delivered_customer_date) AS missing_delivered,
    COUNT(*) - COUNT(order_estimated_delivery_date) AS missing_estimate
FROM orders;

-- Delivery dates by status
-- (Result: 8 delivered orders lack a date, 6 canceled orders have one)
SELECT
    order_status,
    COUNT(*)                             AS orders,
    COUNT(order_delivered_customer_date) AS has_delivery_date
FROM orders
GROUP BY order_status
ORDER BY orders DESC;


-- ---------------------------------------------------------------------
-- REVIEWS
-- ---------------------------------------------------------------------

-- Reviews vs. orders (Result: some orders have multiple reviews,
-- some review IDs are reused, ~770 orders have no review)
SELECT
    COUNT(*)                  AS total_reviews,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT order_id)  AS orders_with_review
FROM reviews;

-- Review score distribution (polarized: 77% are 4-5 stars, 11.5% are 1 star)
SELECT
    review_score,
    COUNT(*) AS reviews,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM reviews
GROUP BY review_score
ORDER BY review_score;

-- How many reviews do orders have? (Result: 547 orders have 2-3)
SELECT n_reviews, COUNT(*) AS orders
FROM (
    SELECT order_id, COUNT(*) AS n_reviews
    FROM reviews
    GROUP BY order_id
)
GROUP BY n_reviews
ORDER BY n_reviews;


-- ---------------------------------------------------------------------
-- ORDER ITEMS & PAYMENTS
-- ---------------------------------------------------------------------

-- Items per order (avg ~1.14, max 21)
SELECT
    COUNT(*)                 AS total_rows,
    COUNT(DISTINCT order_id) AS orders_with_items,
    MAX(order_item_id)       AS max_items_in_one_order
FROM order_items;

-- Payment types (vouchers are often split across multiple rows)
SELECT
    payment_type,
    COUNT(*)                 AS payment_rows,
    COUNT(DISTINCT order_id) AS orders
FROM payments
GROUP BY payment_type
ORDER BY payment_rows DESC;

-- WRONG: joining items and payments at once causes fan-out
-- (payments overstated by ~28%)
SELECT
    SUM(oi.price + oi.freight_value) AS item_revenue,
    SUM(p.payment_value)             AS payment_total
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN payments p     ON o.order_id = p.order_id;

-- RIGHT: aggregate each table to the order level first
-- (item revenue and payments reconcile within 0.02%)
WITH items AS (
    SELECT order_id, SUM(price + freight_value) AS item_total
    FROM order_items
    GROUP BY order_id
),
pays AS (
    SELECT order_id, SUM(payment_value) AS payment_total
    FROM payments
    GROUP BY order_id
)
SELECT
    SUM(i.item_total)    AS item_revenue,
    SUM(p.payment_total) AS payment_total
FROM items i
JOIN pays p ON i.order_id = p.order_id;


-- ---------------------------------------------------------------------
-- CUSTOMERS
-- ---------------------------------------------------------------------

-- customer_id is unique per ORDER, customer_unique_id identifies people
SELECT
    COUNT(*)                           AS total_rows,
    COUNT(DISTINCT customer_id)        AS distinct_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS distinct_people
FROM customers;

-- Orders per real customer (96.9% ordered only once)
WITH orders_per_person AS (
    SELECT c.customer_unique_id, COUNT(*) AS n_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    n_orders,
    COUNT(*) AS people,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders_per_person
GROUP BY n_orders
ORDER BY n_orders;
