-- =====================================================================
-- 07_retention.sql
-- Repeat purchase behavior.
-- A customer "returned" if they ordered again on a LATER calendar day
-- (same-day orders are multi-seller checkouts split into separate orders).
-- First orders are limited to Jan 2017 - Feb 2018 so every customer had
-- 6+ months to return (avoids censoring).
-- =====================================================================


-- Time between first and second order
-- Result: ~30% of apparent repeat customers ordered again the same day
WITH ranked AS (
    SELECT
        customer_unique_id,
        order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS order_num,
        LEAD(order_purchase_timestamp) OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS next_order_ts
    FROM order_summary
),
gaps AS (
    SELECT DATE_DIFF('day', order_purchase_timestamp, next_order_ts) AS gap_days
    FROM ranked
    WHERE order_num = 1
      AND next_order_ts IS NOT NULL
)
SELECT
    CASE
        WHEN gap_days = 0    THEN '1. Same day'
        WHEN gap_days <= 7   THEN '2. 1-7 days'
        WHEN gap_days <= 30  THEN '3. 8-30 days'
        WHEN gap_days <= 90  THEN '4. 31-90 days'
        WHEN gap_days <= 180 THEN '5. 91-180 days'
        ELSE                      '6. 180+ days'
    END AS time_to_second_order,
    COUNT(*) AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM gaps
GROUP BY time_to_second_order
ORDER BY time_to_second_order;


-- Return rate by first-order review score
-- Result: essentially flat, first-order experience doesn't predict returning
WITH ranked AS (
    SELECT
        customer_unique_id,
        order_status,
        order_purchase_timestamp,
        review_score,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS order_num,
        MAX(CAST(order_purchase_timestamp AS DATE)) OVER (
            PARTITION BY customer_unique_id
        ) AS last_order_date
    FROM order_summary
),
first_orders AS (
    SELECT
        *,
        CASE WHEN last_order_date > CAST(order_purchase_timestamp AS DATE)
             THEN 1 ELSE 0 END AS returned
    FROM ranked
    WHERE order_num = 1
      AND order_status = 'delivered'
      AND review_score IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-03-01'
)
SELECT
    review_score                    AS first_order_review,
    COUNT(*)                        AS customers,
    ROUND(100.0 * AVG(returned), 2) AS pct_returned
FROM first_orders
GROUP BY review_score
ORDER BY review_score;


-- Return rate by category of first purchase
-- Result: fashion accessories, pet supplies, and home goods bring
-- customers back most, gifts, games, and office furniture least
WITH ranked AS (
    SELECT
        order_id,
        customer_unique_id,
        order_status,
        order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY order_purchase_timestamp
        ) AS order_num,
        MAX(CAST(order_purchase_timestamp AS DATE)) OVER (
            PARTITION BY customer_unique_id
        ) AS last_order_date
    FROM order_summary
),
first_orders AS (
    SELECT
        *,
        CASE WHEN last_order_date > CAST(order_purchase_timestamp AS DATE)
             THEN 1 ELSE 0 END AS returned
    FROM ranked
    WHERE order_num = 1
      AND order_status = 'delivered'
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-03-01'
),
first_category AS (
    SELECT
        f.returned,
        COALESCE(cn.product_category_name_english,
                 p.product_category_name, 'unknown') AS category
    FROM first_orders f
    JOIN order_items oi         ON f.order_id = oi.order_id AND oi.order_item_id = 1
    JOIN products p             ON oi.product_id = p.product_id
    LEFT JOIN category_names cn ON p.product_category_name = cn.product_category_name
)
SELECT
    category,
    COUNT(*)                        AS customers,
    ROUND(100.0 * AVG(returned), 2) AS pct_returned
FROM first_category
GROUP BY category
HAVING COUNT(*) >= 500
ORDER BY pct_returned DESC;
