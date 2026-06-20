/*
=====================================================================
DAY 001: WHAT DOES “BEST CUSTOMER” ACTUALLY MEAN?
=====================================================================

Database:
PostgreSQL

Teaching framework:
Question → Grain → Query → Validation → Business Decision

Business request:
“Show me our best customers.”

Problem:
The word “best” is ambiguous. It could mean:

1. The customer who generated the most completed revenue
2. The customer who placed the most completed orders
3. The customer with the highest average order value
4. The customer who generated the most revenue recently

Each definition can produce a different answer.

Fixed analysis date:
22 June 2026

Why use a fixed date?
Using a fixed date ensures that anyone running this lesson receives
the same result. If we used CURRENT_DATE, the 90-day result would
change depending on the day the query was executed.

Eligible orders:
Only orders with the status 'completed' are included in revenue
and order-count metrics.

Cancelled orders remain in the dataset so that we can demonstrate
why filters and validation are important.
*/


/* ================================================================
   SET THE ACTIVE SCHEMA
   ================================================================ */

/*
Tell PostgreSQL to look inside the sql_authority schema first.

This allows us to write:

    FROM orders

instead of writing the fully qualified table name:

    FROM sql_authority.orders

The setting applies to the current database session or query
connection.
*/
SET search_path TO sql_authority;


/* ================================================================
   1. BUILD A TRUSTWORTHY ORDER-LEVEL DATASET
   ================================================================ */

/*
Before ranking customers, we first calculate the total revenue
for every completed order.

Why do this first?

The orders table has:
    One row per order

The order_items table has:
    One row per product line within an order

An order containing three different products therefore has:

    One row in orders
    Three rows in order_items

After joining orders to order_items, the result is at the
order-item grain. One order may appear multiple times.

We therefore group the product lines back together so that the
CTE named order_totals has:

    One row per completed order

CTE means Common Table Expression.

A CTE is a temporary named result that exists only while the
current SQL statement is running.

The syntax begins with:

    WITH cte_name AS (...)

The CTE does not permanently create a table in the database.
*/
WITH order_totals AS (

    SELECT

        /*
        The unique identifier for the order.

        We retain order_id because the intended grain of this CTE
        is one row per order.
        */
        o.order_id,

        /*
        The customer who placed the order.

        This will later allow us to combine all orders belonging
        to the same customer.
        */
        o.customer_id,

        /*
        The date the order was placed.

        This is required later when we calculate revenue within
        the last 90 days.
        */
        o.order_date,

        /*
        Calculate the revenue from every product line.

        For each line:

            quantity × unit_price

        SUM then adds all product-line amounts belonging to the
        same order.

        Example:

            Monitor: 1 × £220 = £220
            Webcam:  1 × £90  = £90

            Order revenue = £310

        The result is given the alias order_revenue.
        */
        SUM(oi.quantity * oi.unit_price) AS order_revenue

    /*
    Begin with the orders table.

    AS o gives the table a shorter alias.

    Instead of writing orders.order_id, we can write o.order_id.
    */
    FROM orders AS o

    /*
    Join every order to the product lines contained in that order.

    INNER JOIN keeps only rows that have a matching record in both
    tables.

    The join condition says:

        Match an order in orders
        to an order item with the same order_id.
    */
    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id

    /*
    Only completed orders are eligible.

    This prevents cancelled order revenue from being included in
    our customer metrics.
    */
    WHERE o.status = 'completed'

    /*
    GROUP BY combines all order-item rows belonging to the same
    order.

    Because order_revenue uses SUM(), every selected column that
    is not inside an aggregate function is included in GROUP BY.

    After grouping, the CTE contains one row per completed order.
    */
    GROUP BY
        o.order_id,
        o.customer_id,
        o.order_date
)

/*
Display the order-level result so that we can inspect it before
using it in customer calculations.
*/
SELECT
    *
FROM order_totals

/*
Sort the result by order number from the smallest to the largest.

This is mainly for readability and inspection.
*/
ORDER BY order_id;


/* ================================================================
   2. DEFINITION A:
   “BEST CUSTOMER” = HIGHEST LIFETIME COMPLETED REVENUE
   ================================================================ */

/*
Business question:
Which customers have generated the most revenue from all completed
orders in the dataset?

Final result grain:
One row per customer

Expected winner:
Ama Mensah — £700.00

Important:
A CTE exists only for the SQL statement in which it is defined.

The order_totals CTE from the previous query no longer exists,
so we define it again for this new statement.
*/
WITH order_totals AS (

    /*
    Recreate the trustworthy order-level dataset.

    One row in order_totals represents one completed order.
    */
    SELECT
        o.order_id,
        o.customer_id,
        o.order_date,

        /*
        Add the value of all items within each completed order.
        */
        SUM(oi.quantity * oi.unit_price) AS order_revenue

    FROM orders AS o

    INNER JOIN order_items AS oi
        ON o.order_id = oi.order_id

    /*
    Exclude cancelled orders.
    */
    WHERE o.status = 'completed'

    /*
    Return one row per completed order.
    */
    GROUP BY
        o.order_id,
        o.customer_id,
        o.order_date
)

SELECT

    /*
    Return the customer’s unique identifier.
    */
    c.customer_id,

    /*
    Return the customer’s readable name.
    */
    c.customer_name,

    /*
    Each customer may have several completed orders.

    SUM adds the revenue from all completed orders belonging
    to the customer.

    The result is named lifetime_revenue.
    */
    SUM(ot.order_revenue) AS lifetime_revenue

/*
Start with the customers table.

AS c is a short alias for customers.
*/
FROM customers AS c

/*
Join customers to their completed order totals.

The relationship is:

    customers.customer_id = order_totals.customer_id

INNER JOIN means customers with no completed orders will not appear
in this result.

That is appropriate here because we are ranking customers based on
completed revenue.
*/
INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id

/*
Combine every completed order belonging to the same customer.

After grouping, the final result has one row per customer.
*/
GROUP BY
    c.customer_id,
    c.customer_name

/*
Sort customers from highest lifetime revenue to lowest.

DESC means descending order.

The second sorting rule, c.customer_id, is a tie-breaker.

If two customers have exactly the same revenue, the customer with
the smaller customer_id appears first. This makes the output
deterministic and reproducible.
*/
ORDER BY
    lifetime_revenue DESC,
    c.customer_id

/*
Return only the top five customers.

LIMIT controls the maximum number of rows displayed.
*/
LIMIT 5;


/* ================================================================
   3. DEFINITION B:
   “BEST CUSTOMER” = MOST COMPLETED ORDERS
   ================================================================ */

/*
Business question:
Which customers placed the greatest number of completed orders?

Final result grain:
One row per customer

Expected winner:
Ama Mensah — 3 completed orders

Why COUNT(*) is safe here:

The order_totals CTE has already been grouped to one row per order.

Therefore, after joining customers to order_totals:

    One row = one completed order

COUNT(*) now counts orders, not product lines.

If we counted rows immediately after joining orders to order_items,
COUNT(*) would count order-item rows and could overstate the number
of orders.
*/
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

SELECT
    c.customer_id,
    c.customer_name,

    /*
    Because order_totals contains one row per completed order,
    COUNT(*) returns the number of completed orders for each
    customer.
    */
    COUNT(*) AS completed_orders

FROM customers AS c

INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id

/*
Create one output row per customer.
*/
GROUP BY
    c.customer_id,
    c.customer_name

/*
Rank customers from the largest number of completed orders
to the smallest.

customer_id provides a consistent tie-breaker.
*/
ORDER BY
    completed_orders DESC,
    c.customer_id

/*
Show the top five customers.
*/
LIMIT 5;


/* ================================================================
   4. DEFINITION C:
   “BEST CUSTOMER” = HIGHEST AVERAGE ORDER VALUE
   ================================================================ */

/*
Business question:
Which repeat customer spends the most money on an average order?

Average order value formula:

    Total revenue ÷ Number of orders

We use AVG(order_revenue) because order_totals already contains
one row per completed order.

Eligibility rule:
Only customers with at least two completed orders are included.

Why require at least two orders?

A customer with only one very large order could appear to have the
highest average, but one order does not demonstrate repeat customer
behaviour.

This business rule makes the comparison more meaningful for
customer relationship or premium-product decisions.

Final result grain:
One row per qualifying customer

Expected winner:
Grace Boateng — £240.00 average order value
*/
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

SELECT
    c.customer_id,
    c.customer_name,

    /*
    Show the number of completed orders for transparency.

    This helps us confirm that every included customer meets the
    minimum requirement of two completed orders.
    */
    COUNT(*) AS completed_orders,

    /*
    AVG calculates the average revenue per completed order.

    ROUND(..., 2) displays the result to two decimal places,
    which is appropriate for currency.
    */
    ROUND(
        AVG(ot.order_revenue),
        2
    ) AS average_order_value

FROM customers AS c

INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id

/*
Create one result row per customer.
*/
GROUP BY
    c.customer_id,
    c.customer_name

/*
HAVING filters groups after aggregation.

WHERE filters individual rows before grouping.

HAVING is required here because COUNT(*) is an aggregate result
that does not exist until the rows have been grouped.

This condition keeps only customers with two or more completed
orders.
*/
HAVING COUNT(*) >= 2

/*
Place the customer with the highest average order value first.

customer_id is used as a tie-breaker.
*/
ORDER BY
    average_order_value DESC,
    c.customer_id;


/* ================================================================
   5. DEFINITION D:
   “BEST CUSTOMER” = HIGHEST REVENUE IN THE LAST 90 DAYS
   ================================================================ */

/*
Business question:
Which customer generated the most completed revenue during the
90-day period ending on 22 June 2026?

Analysis date:
22 June 2026

90-day cut-off:
24 March 2026

Why use a parameters CTE?

It stores the analysis date in one place.

If the analysis date needs to change, we can update it once instead
of changing multiple parts of the query.

Why not use CURRENT_DATE?

CURRENT_DATE would produce a different 90-day period depending on
when a learner runs the query.

A fixed date makes the exercise reproducible.

Final result grain:
One row per customer

Expected winner:
Grace Boateng — £480.00
*/
WITH parameters AS (

    /*
    Create one temporary row containing the fixed analysis date.

    DATE '2026-06-22' is PostgreSQL’s explicit date literal syntax.

    The column is named as_of_date.
    */
    SELECT
        DATE '2026-06-22' AS as_of_date
),

order_totals AS (

    /*
    Create one row per completed order.
    */
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

SELECT
    c.customer_id,
    c.customer_name,

    /*
    Add the revenue from all qualifying orders placed by each
    customer during the 90-day period.
    */
    SUM(ot.order_revenue) AS revenue_last_90_days

FROM customers AS c

INNER JOIN order_totals AS ot
    ON c.customer_id = ot.customer_id

/*
CROSS JOIN combines every row from one source with every row from
another source.

The parameters CTE contains only one row, so its as_of_date value
is attached to every order row.

This allows the fixed date to be used in the WHERE clause.
*/
CROSS JOIN parameters AS p

/*
Lower date boundary:

Keep orders placed on or after 90 days before the analysis date.

PostgreSQL subtracts the 90-day interval from 22 June 2026,
producing the cut-off date of 24 March 2026.
*/
WHERE ot.order_date >= p.as_of_date - INTERVAL '90 days'

  /*
  Upper date boundary:

  Prevent orders after the analysis date from entering the result.

  This is important because future-dated records could otherwise
  be included.
  */
  AND ot.order_date <= p.as_of_date

/*
Create one output row per customer.
*/
GROUP BY
    c.customer_id,
    c.customer_name

/*
Rank customers from highest recent revenue to lowest.

customer_id is the tie-breaker.
*/
ORDER BY
    revenue_last_90_days DESC,
    c.customer_id

/*
Return the top five customers.
*/
LIMIT 5;


/* ================================================================
   6. VALIDATION A:
   VERIFY TOTAL COMPLETED REVENUE
   ================================================================ */

/*
Expected result:
£2,710.00

Purpose:
This independently calculates total completed revenue across the
entire dataset.

Why validate?

A customer-ranking query can run successfully and still be wrong.

For example, it could:

- Include cancelled orders
- Multiply revenue because of an incorrect join
- Omit some orders
- Use the wrong price or quantity calculation

The total of all customer-level completed revenue should reconcile
to this overall value.

Revenue formula:

    quantity × unit_price

Only completed orders are included.
*/
SELECT

    /*
    Calculate the total revenue of all completed order-item rows.
    */
    SUM(oi.quantity * oi.unit_price) AS total_completed_revenue

FROM orders AS o

INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id

/*
Exclude cancelled orders.
*/
WHERE o.status = 'completed';


/* ================================================================
   7. VALIDATION B:
   VERIFY THE REVENUE THAT MUST BE EXCLUDED
   ================================================================ */

/*
Expected result:
£440.00

Purpose:
Calculate the value of cancelled orders separately.

This confirms that cancelled order data exists and shows exactly
how much revenue would be incorrectly added if the completed-order
filter were missing.

The column name cancelled_revenue_excluded communicates that this
amount must not be included in valid completed-revenue metrics.
*/
SELECT
    SUM(oi.quantity * oi.unit_price) AS cancelled_revenue_excluded

FROM orders AS o

INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id

/*
Select only cancelled orders for this validation check.
*/
WHERE o.status = 'cancelled';


/* ================================================================
   8. VALIDATION C:
   DEMONSTRATE THE RISK OF CHANGING GRAIN AFTER A JOIN
   ================================================================ */

/*
Expected results:

    joined_rows               = 22
    distinct_completed_orders = 13

Why are the values different?

There are 13 completed orders.

However, those 13 orders contain 22 separate product lines.

After joining orders to order_items:

    One row represents one product line within an order

Therefore:

    COUNT(*) counts product-line rows
    COUNT(DISTINCT order_id) counts actual orders

This validation demonstrates why analysts must understand the grain
before counting rows.
*/
SELECT

    /*
    Count every row produced by the join.

    Because the joined grain is one row per order item, this counts
    completed product lines, not completed orders.
    */
    COUNT(*) AS joined_rows,

    /*
    DISTINCT removes repeated order IDs before counting them.

    This returns the actual number of completed orders.
    */
    COUNT(DISTINCT o.order_id) AS distinct_completed_orders

FROM orders AS o

INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id

WHERE o.status = 'completed';


/* ================================================================
   AUDIENCE CHALLENGE
   ================================================================ */

/*
Business question:

Which customer generated the highest completed revenue between
1 April and 31 May 2026?

Requirements:

1. Include only completed orders.
2. Exclude cancelled orders.
3. Include orders dated from 1 April 2026 through 31 May 2026.
4. Calculate revenue as quantity multiplied by unit_price.
5. Return one row per customer.
6. Rank customers from highest revenue to lowest revenue.
7. State the grain of the final result.
8. Add at least one validation query.

Questions for learners:

- Which tables need to be joined?
- What does one row represent immediately after the join?
- What should one row represent in the final output?
- Should the date filter include both boundary dates?
- How can the total be validated?
- How can we prove cancelled revenue was excluded?

Write the challenge solution in exercises.sql.
*/
