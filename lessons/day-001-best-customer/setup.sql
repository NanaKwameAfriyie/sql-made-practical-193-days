/*
Day 001 Setup
Database: PostgreSQL

Purpose:
Create a small, predictable e-commerce dataset for the first live lesson.

The dataset contains:
- Customers
- Products
- Orders
- Items within each order

Important:
Run this entire file first while connected to the
sql_authority_lab database.
*/


/* =========================================================
   1. CREATE A CLEAN WORKING AREA
   ========================================================= */

/*
Remove the existing sql_authority schema if it already exists.

CASCADE also removes tables and other objects stored inside
the schema. This allows us to run the setup file repeatedly
without receiving "table already exists" errors.

This is appropriate for our temporary teaching environment,
but should be used carefully in a production database.
*/

DROP SCHEMA IF EXISTS sql_authority CASCADE;


/*
Create a new schema named sql_authority.

A schema is like a folder inside a database. It helps us keep
the tables for this lesson organised separately from other
database objects.
*/

CREATE SCHEMA sql_authority;


/*
Tell PostgreSQL to look inside the sql_authority schema first.

This means we can write:

    SELECT * FROM customers;

instead of:

    SELECT * FROM sql_authority.customers;
*/

SET search_path TO sql_authority;


/* =========================================================
   2. CREATE THE CUSTOMERS TABLE
   ========================================================= */

/*
Grain:
One row in this table represents one customer.
*/

CREATE TABLE customers (

    /*
    A unique number used to identify each customer.

    PRIMARY KEY means:
    - The value must be unique.
    - The value cannot be NULL.
    */

    customer_id INTEGER PRIMARY KEY,

    /*
    The customer's name is required, so it cannot be NULL.
    */

    customer_name TEXT NOT NULL,

    /*
    The date the customer registered with the business.
    */

    signup_date DATE NOT NULL
);


/* =========================================================
   3. CREATE THE PRODUCTS TABLE
   ========================================================= */

/*
Grain:
One row in this table represents one product.
*/

CREATE TABLE products (

    /*
    A unique number used to identify each product.
    */

    product_id INTEGER PRIMARY KEY,

    /*
    The name of the product.
    */

    product_name TEXT NOT NULL,

    /*
    NUMERIC(10, 2) stores a number with up to two decimal places.

    The CHECK constraint prevents a negative product price.
    */

    unit_price NUMERIC(10, 2) NOT NULL
        CHECK (unit_price >= 0)
);


/* =========================================================
   4. CREATE THE ORDERS TABLE
   ========================================================= */

/*

Grain:
One row in this table represents one customer order.

An order can contain one product or several products.
The individual products are stored later in order_items.
*/

CREATE TABLE orders (

    /*
    A unique number used to identify each order.
    */
    
    order_id INTEGER PRIMARY KEY,

    /*
    Identifies the customer who placed the order.

    REFERENCES creates a foreign key relationship.
    It prevents us from creating an order for a customer
    who does not exist in the customers table.
    */
    customer_id INTEGER NOT NULL
        REFERENCES customers(customer_id),

    /*
    The date on which the order was placed.
    */
    order_date DATE NOT NULL,

    /*
    The order can only have one of two permitted statuses:
    completed or cancelled.

    The CHECK constraint prevents unexpected values such as
    'complete', 'pending' or spelling mistakes.
    */
    status TEXT NOT NULL
        CHECK (status IN ('completed', 'cancelled'))
);


/* =========================================================
   5. CREATE THE ORDER ITEMS TABLE
   ========================================================= */

/*
Grain:
One row in this table represents one product line inside
one order.

Example:
If order 101 contains a monitor and a webcam, order 101 will
have two rows in this table.
*/
CREATE TABLE order_items (

    /*
    Identifies the order to which this product line belongs.

    The referenced order must already exist in the orders table.
    */
    order_id INTEGER NOT NULL
        REFERENCES orders(order_id),

    /*
    Identifies the product included in the order.

    The referenced product must already exist in the
    products table.
    */
    product_id INTEGER NOT NULL
        REFERENCES products(product_id),

    /*
    Records how many units of the product were purchased.

    The quantity must be greater than zero.
    */
    quantity INTEGER NOT NULL
        CHECK (quantity > 0),

    /*
    Stores the price charged when the order was placed.

    We keep this value in order_items because product prices
    may change over time. Historical orders should retain the
    price that the customer actually paid.
    */
    unit_price NUMERIC(10, 2) NOT NULL
        CHECK (unit_price >= 0),

    /*
    This is a composite primary key made from two columns.

    It means that the same product can appear only once within
    a particular order. If a customer buys several units of the
    same product, the quantity column records the number.
    */
    PRIMARY KEY (order_id, product_id)
);


/* =========================================================
   6. INSERT SAMPLE CUSTOMERS
   ========================================================= */

/*
Add eight customers to the customers table.

The column list shows which values are being supplied and the
order in which PostgreSQL should place them.
*/
INSERT INTO customers (
    customer_id,
    customer_name,
    signup_date
)
VALUES
    (1, 'Ama Mensah',    DATE '2025-09-14'),
    (2, 'Daniel Owusu',  DATE '2025-10-03'),
    (3, 'Sarah Jones',   DATE '2025-11-19'),
    (4, 'Michael Brown', DATE '2025-08-27'),
    (5, 'Grace Boateng', DATE '2026-01-08'),
    (6, 'James Wilson',  DATE '2026-02-13'),
    (7, 'Fatima Khan',   DATE '2026-03-02'),
    (8, 'Olivia Smith',  DATE '2026-04-11');


/* =========================================================
   7. INSERT SAMPLE PRODUCTS
   ========================================================= */

/*
Add six products and their standard prices.

These prices describe the products themselves. The prices paid
on individual orders are also stored in order_items.
*/
INSERT INTO products (
    product_id,
    product_name,
    unit_price
)
VALUES
    (1, 'Laptop Stand',  45.00),
    (2, 'Keyboard',      80.00),
    (3, 'Monitor',      220.00),
    (4, 'Headphones',   120.00),
    (5, 'Webcam',        90.00),
    (6, 'Desk Lamp',     50.00);


/* =========================================================
   8. INSERT SAMPLE ORDERS
   ========================================================= */

/*
Add fourteen orders.

Notice that order 105 is cancelled. This will help demonstrate
why business rules and filters matter when calculating revenue.

Revenue calculations should normally include completed orders
and exclude cancelled orders.
*/
INSERT INTO orders (
    order_id,
    customer_id,
    order_date,
    status
)
VALUES
    (101, 1, DATE '2026-01-15', 'completed'),
    (102, 2, DATE '2026-02-10', 'completed'),
    (103, 1, DATE '2026-03-05', 'completed'),
    (104, 3, DATE '2026-03-22', 'completed'),
    (105, 4, DATE '2026-04-01', 'cancelled'),
    (106, 5, DATE '2026-04-18', 'completed'),
    (107, 2, DATE '2026-05-02', 'completed'),
    (108, 6, DATE '2026-05-15', 'completed'),
    (109, 3, DATE '2026-06-01', 'completed'),
    (110, 7, DATE '2026-06-10', 'completed'),
    (111, 1, DATE '2026-06-18', 'completed'),
    (112, 8, DATE '2026-06-20', 'completed'),
    (113, 5, DATE '2026-06-21', 'completed'),
    (114, 4, DATE '2025-12-15', 'completed');


/* =========================================================
   9. INSERT THE PRODUCTS WITHIN EACH ORDER
   ========================================================= */

/*
Add twenty-three order-item rows.

Revenue for each row can be calculated using:

    quantity * unit_price

Example:
Order 101 contains:
- One monitor costing £220
- One webcam costing £90

Therefore, order 101 contains two order-item rows and has a
total value of £310.
*/
INSERT INTO order_items (
    order_id,
    product_id,
    quantity,
    unit_price
)
VALUES
    -- Order 101: Monitor and webcam
    (101, 3, 1, 220.00),
    (101, 5, 1,  90.00),

    -- Order 102: Keyboard and headphones
    (102, 2, 1,  80.00),
    (102, 4, 1, 120.00),

    -- Order 103: Two laptop stands and one desk lamp
    (103, 1, 2,  45.00),
    (103, 6, 1,  50.00),

    -- Order 104: One monitor
    (104, 3, 1, 220.00),

    /*
    Order 105 was cancelled.

    Its items remain in the database, but its revenue should
    be excluded when we calculate completed revenue.
    */
    (105, 3, 2, 220.00),

    -- Order 106: Headphones and webcam
    (106, 4, 1, 120.00),
    (106, 5, 1,  90.00),

    -- Order 107: Laptop stand and keyboard
    (107, 1, 1,  45.00),
    (107, 2, 1,  80.00),

    -- Order 108: One webcam
    (108, 5, 1,  90.00),

    -- Order 109: Two desk lamps and one pair of headphones
    (109, 6, 2,  50.00),
    (109, 4, 1, 120.00),

    -- Order 110: Monitor and keyboard
    (110, 3, 1, 220.00),
    (110, 2, 1,  80.00),

    -- Order 111: Two keyboards and one webcam
    (111, 2, 2,  80.00),
    (111, 5, 1,  90.00),

    -- Order 112: Three laptop stands
    (112, 1, 3,  45.00),

    -- Order 113: Monitor and desk lamp
    (113, 3, 1, 220.00),
    (113, 6, 1,  50.00),

    -- Order 114: Two pairs of headphones
    (114, 4, 2, 120.00);


/* =========================================================
   10. RUN BASIC HEALTH CHECKS
   ========================================================= */

/*
These queries confirm that all expected rows were inserted.

Expected results:
- customers:   8 rows
- products:    6 rows
- orders:     14 rows
- order_items: 23 rows

If the counts do not match, something may have gone wrong
during the setup process.
*/
SELECT COUNT(*) AS customer_rows
FROM customers;

SELECT COUNT(*) AS product_rows
FROM products;

SELECT COUNT(*) AS order_rows
FROM orders;

SELECT COUNT(*) AS order_item_rows
FROM order_items;