/*
Day 001: What does “best customer” actually mean?

Teaching method:
Question → Grain → Query → Validation → Business Decision

Fixed analysis date: 22 June 2026
Eligible orders: completed only
*/

SET search_path TO sql_authority;

-- ------------------------------------------------------------
-- 1. First define the trustworthy order-level grain.
-- One row in this CTE represents one completed order.
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY
        o.order_id,
        o.customer_id,
        o.order_date
)
SELECT *
FROM order_totals
ORDER BY order_id;

-- ------------------------------------------------------------
-- 2. Definition A: “Best” = highest lifetime completed revenue.
-- One output row represents one customer.
-- Expected winner: Ama Mensah, £700.00.
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.customer_id, o.order_date
)
SELECT
    c.customer_id,
    c.customer_name,
    SUM(ot.order_revenue) AS lifetime_revenue
FROM customers AS c
INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY lifetime_revenue DESC, c.customer_id
LIMIT 5;

-- ------------------------------------------------------------
-- 3. Definition B: “Best” = most completed orders.
-- Expected winner: Ama Mensah, 3 orders.
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.customer_id, o.order_date
)
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(*) AS completed_orders
FROM customers AS c
INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY completed_orders DESC, c.customer_id
LIMIT 5;

-- ------------------------------------------------------------
-- 4. Definition C: “Best” = highest average order value,
--    but only among customers with at least two completed orders.
-- Expected winner: Grace Boateng, £240.00 average order value.
-- ------------------------------------------------------------
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.customer_id, o.order_date
)
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(*) AS completed_orders,
    ROUND(AVG(ot.order_revenue), 2) AS average_order_value
FROM customers AS c
INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id
GROUP BY c.customer_id, c.customer_name
HAVING COUNT(*) >= 2
ORDER BY average_order_value DESC, c.customer_id;

-- ------------------------------------------------------------
-- 5. Definition D: “Best” = highest revenue in the last 90 days.
-- The fixed date makes the lesson reproducible.
-- Cut-off: 24 March 2026.
-- Expected winner: Grace Boateng, £480.00.
-- ------------------------------------------------------------
WITH parameters AS (
    SELECT DATE '2026-06-22' AS as_of_date
),
order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,
        SUM(oi.quantity * oi.unit_price) AS order_revenue
    FROM orders AS o
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY o.order_id, o.customer_id, o.order_date
)
SELECT
    c.customer_id,
    c.customer_name,
    SUM(ot.order_revenue) AS revenue_last_90_days
FROM customers AS c
INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id
CROSS JOIN parameters AS p
WHERE ot.order_date >= p.as_of_date - INTERVAL '90 days'
  AND ot.order_date <= p.as_of_date
GROUP BY c.customer_id, c.customer_name
ORDER BY revenue_last_90_days DESC, c.customer_id
LIMIT 5;

-- ------------------------------------------------------------
-- 6. Validation A: overall completed revenue must equal £2,710.00.
-- ------------------------------------------------------------
SELECT
    SUM(oi.quantity * oi.unit_price) AS total_completed_revenue
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'completed';

-- ------------------------------------------------------------
-- 7. Validation B: cancelled revenue must not enter the metric.
-- Expected cancelled revenue: £440.00.
-- ------------------------------------------------------------
SELECT
    SUM(oi.quantity * oi.unit_price) AS cancelled_revenue_excluded
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'cancelled';

-- ------------------------------------------------------------
-- 8. Validation C: demonstrate join-grain risk.
-- There are 13 completed orders but 22 completed order-item rows.
-- COUNT(*) after joining order_items counts lines, not orders.
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT o.order_id) AS distinct_completed_orders
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.status = 'completed';

-- ------------------------------------------------------------
-- Audience challenge:
-- Return the customer with the highest completed revenue between
-- 1 April and 31 May 2026. State the result grain and exclusions.
-- ------------------------------------------------------------