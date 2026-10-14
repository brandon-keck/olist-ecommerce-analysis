-- =====================================================================
-- 04_business_overview.sql
-- Growth trends. Analysis window: Jan 2017 - Aug 2018
-- (2016 is sparse launch data, Sep 2018 is incomplete).
-- =====================================================================


-- Monthly orders, revenue, and average order value
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS month,
    COUNT(*)         AS orders,
    SUM(order_value) AS revenue,
    AVG(order_value) AS avg_order_value
FROM order_summary
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY month
ORDER BY month;


-- Year-over-year comparison, Jan-Aug of each year (apples to apples)
-- Result: revenue +140%, driven by order volume, avg order value flat
WITH yearly AS (
    SELECT
        YEAR(order_purchase_timestamp) AS year,
        COUNT(*)                       AS orders,
        SUM(order_value)               AS revenue,
        AVG(order_value)               AS avg_order_value
    FROM order_summary
    WHERE order_status NOT IN ('canceled', 'unavailable')
      AND YEAR(order_purchase_timestamp) IN (2017, 2018)
      AND MONTH(order_purchase_timestamp) <= 8
    GROUP BY year
)
SELECT
    *,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year))
          / LAG(revenue) OVER (ORDER BY year), 1) AS revenue_growth_pct
FROM yearly
ORDER BY year;
