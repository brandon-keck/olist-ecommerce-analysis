-- =====================================================================
-- 05_delivery_and_reviews.sql
-- How delivery performance relates to review scores, and where
-- late deliveries happen.
-- =====================================================================


-- Late vs. on-time orders
-- Result: late orders average 2.27 stars vs. 4.29, 53.8% are 1-star vs. 6.6%
SELECT
    CASE WHEN is_late = 1 THEN 'Late' ELSE 'On time or early' END AS delivery_status,
    COUNT(*)                                                       AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)             AS pct_of_orders,
    ROUND(AVG(review_score), 2)                                    AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN review_score = 1 THEN 1 ELSE 0 END), 1) AS pct_one_star
FROM order_summary
WHERE order_status = 'delivered'
  AND is_late IS NOT NULL
  AND review_score IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY delivery_status;


-- Review score by how early or late the order arrived
-- Result: early delivery earns little extra credit, reviews drop sharply
-- once the estimate is missed and bottom out after ~1 week late
SELECT
    CASE
        WHEN days_late <= -14 THEN '1. 14+ days early'
        WHEN days_late <= -7  THEN '2. 7-13 days early'
        WHEN days_late <= 0   THEN '3. 0-6 days early'
        WHEN days_late <= 3   THEN '4. 1-3 days late'
        WHEN days_late <= 7   THEN '5. 4-7 days late'
        WHEN days_late <= 14  THEN '6. 8-14 days late'
        ELSE                       '7. 15+ days late'
    END                                                            AS lateness,
    COUNT(*)                                                       AS orders,
    ROUND(AVG(review_score), 2)                                    AS avg_review,
    ROUND(100.0 * AVG(CASE WHEN review_score = 1 THEN 1 ELSE 0 END), 1) AS pct_one_star
FROM order_summary
WHERE order_status = 'delivered'
  AND is_late IS NOT NULL
  AND review_score IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY lateness
ORDER BY lateness;


-- Late rate and delivery time by customer state
-- Result: Northeast/North have the highest late rates, RJ combines
-- high volume with a high late rate
SELECT
    customer_state,
    COUNT(*)                       AS orders,
    ROUND(AVG(delivery_days), 1)   AS avg_delivery_days,
    ROUND(100.0 * AVG(is_late), 1) AS pct_late
FROM order_summary
WHERE order_status = 'delivered'
  AND is_late IS NOT NULL
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01'
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY pct_late DESC;
