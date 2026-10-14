-- =====================================================================
-- 06_sellers_and_carriers.sql
-- Are late deliveries concentrated among certain sellers, and do
-- delays happen before or after the seller hands off the package?
-- =====================================================================


-- Concentration of late orders among sellers (Pareto-style)
-- Result: top 100 sellers = ~50% of late orders but also ~42% of all
-- orders, so lateness is mostly proportional to volume
WITH seller_orders AS (
    SELECT DISTINCT seller_id, order_id
    FROM order_items
),
seller_stats AS (
    SELECT
        so.seller_id,
        COUNT(*)        AS orders,
        SUM(os.is_late) AS late_orders
    FROM seller_orders so
    JOIN order_summary os ON so.order_id = os.order_id
    WHERE os.order_status = 'delivered'
      AND os.is_late IS NOT NULL
      AND os.order_purchase_timestamp >= '2017-01-01'
      AND os.order_purchase_timestamp <  '2018-09-01'
    GROUP BY so.seller_id
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY late_orders DESC, orders DESC) AS seller_rank,
        SUM(late_orders) OVER (ORDER BY late_orders DESC, orders DESC
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_late,
        SUM(orders)      OVER (ORDER BY late_orders DESC, orders DESC
                               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_orders,
        SUM(late_orders) OVER () AS total_late,
        SUM(orders)      OVER () AS total_orders,
        COUNT(*)         OVER () AS total_sellers
    FROM seller_stats
)
SELECT
    seller_rank                                   AS top_n_sellers,
    ROUND(100.0 * seller_rank / total_sellers, 1) AS pct_of_sellers,
    ROUND(100.0 * cum_late    / total_late, 1)    AS pct_of_late_orders,
    ROUND(100.0 * cum_orders  / total_orders, 1)  AS pct_of_all_orders
FROM ranked
WHERE seller_rank IN (10, 25, 50, 100, 250, 500)
ORDER BY seller_rank;


-- Highest late rates among sellers with 100+ orders
-- Result: worst run 12-19% (2-3x average), mostly in SP, the 15 worst
-- account for only ~7% of late orders
WITH seller_orders AS (
    SELECT DISTINCT seller_id, order_id
    FROM order_items
),
seller_stats AS (
    SELECT
        so.seller_id,
        COUNT(*)        AS orders,
        SUM(os.is_late) AS late_orders
    FROM seller_orders so
    JOIN order_summary os ON so.order_id = os.order_id
    WHERE os.order_status = 'delivered'
      AND os.is_late IS NOT NULL
      AND os.order_purchase_timestamp >= '2017-01-01'
      AND os.order_purchase_timestamp <  '2018-09-01'
    GROUP BY so.seller_id
)
SELECT
    ss.seller_id,
    s.seller_state,
    ss.orders,
    ss.late_orders,
    ROUND(100.0 * ss.late_orders / ss.orders, 1) AS pct_late
FROM seller_stats ss
JOIN sellers s ON ss.seller_id = s.seller_id
WHERE ss.orders >= 100
ORDER BY pct_late DESC
LIMIT 15;


-- Seller handoff vs. final delivery outcome
-- Result: 78% of late orders were handed to the carrier on time,
-- late handoffs are late 26.8% of the time vs. 5.6% (~5x the risk)
WITH limits AS (
    SELECT order_id, MAX(shipping_limit_date) AS shipping_limit
    FROM order_items
    GROUP BY order_id
),
classified AS (
    SELECT
        os.is_late,
        CASE
            WHEN DATE_DIFF('day', l.shipping_limit, o.order_delivered_carrier_date) > 0
            THEN 'Seller shipped late'
            ELSE 'Seller shipped on time'
        END AS seller_handoff
    FROM order_summary os
    JOIN orders o ON os.order_id = o.order_id
    JOIN limits l ON os.order_id = l.order_id
    WHERE os.order_status = 'delivered'
      AND os.is_late IS NOT NULL
      AND o.order_delivered_carrier_date IS NOT NULL
      AND os.order_purchase_timestamp >= '2017-01-01'
      AND os.order_purchase_timestamp <  '2018-09-01'
)
SELECT
    seller_handoff,
    COUNT(*)                                                   AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)         AS pct_of_orders,
    SUM(is_late)                                               AS late_orders,
    ROUND(100.0 * SUM(is_late) / SUM(SUM(is_late)) OVER (), 1) AS pct_of_late_orders,
    ROUND(100.0 * AVG(is_late), 1)                             AS late_rate
FROM classified
GROUP BY seller_handoff;
