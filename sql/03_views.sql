-- =====================================================================
-- 03_views.sql
-- Reusable views that the analysis queries build on.
-- =====================================================================


-- One review per order: keep the most recent review
-- (customers can update their review after the first one)
CREATE OR REPLACE VIEW reviews_clean AS
SELECT order_id, review_id, review_score, review_creation_date
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_creation_date DESC, review_answer_timestamp DESC
        ) AS rn
    FROM reviews
)
WHERE rn = 1;


-- One row per order with everything the analysis needs.
-- Items are aggregated BEFORE joining to prevent fan-out.
-- "Late" is defined once here so every query uses the same logic:
-- delivered on a calendar day after the estimated delivery date.
CREATE OR REPLACE VIEW order_summary AS
WITH items AS (
    SELECT
        order_id,
        COUNT(*)           AS n_items,
        SUM(price)         AS product_value,
        SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATE_DIFF('day', o.order_purchase_timestamp,
                     o.order_delivered_customer_date)      AS delivery_days,
    DATE_DIFF('day', o.order_estimated_delivery_date,
                     o.order_delivered_customer_date)      AS days_late,
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN NULL
        WHEN DATE_DIFF('day', o.order_estimated_delivery_date,
                              o.order_delivered_customer_date) > 0 THEN 1
        ELSE 0
    END                                                    AS is_late,
    i.n_items,
    i.product_value,
    i.freight_value,
    i.product_value + i.freight_value                      AS order_value,
    r.review_score
FROM orders o
JOIN customers c          ON o.customer_id = c.customer_id
LEFT JOIN items i         ON o.order_id = i.order_id
LEFT JOIN reviews_clean r ON o.order_id = r.order_id;
