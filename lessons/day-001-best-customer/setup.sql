/*
Day 001 setup
Database: PostgreSQL
Purpose: Create a small, deterministic e-commerce dataset for the first live.

Run this entire file first while connected to the sql_authority_lab database.
*/

DROP SCHEMA IF EXISTS sql_authority CASCADE;
CREATE SCHEMA sql_authority;
SET search_path TO sql_authority;

CREATE TABLE customers (
    customer_id   INTEGER PRIMARY KEY,
    customer_name TEXT NOT NULL,
    signup_date   DATE NOT NULL
);

CREATE TABLE products (
    product_id   INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    unit_price   NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date  DATE NOT NULL,
    status      TEXT NOT NULL CHECK (status IN ('completed', 'cancelled'))
);

CREATE TABLE order_items (
    order_id   INTEGER NOT NULL REFERENCES orders(order_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, product_id)
);

INSERT INTO customers (customer_id, customer_name, signup_date) VALUES
    (1, 'Ama Mensah',     DATE '2025-09-14'),
    (2, 'Daniel Owusu',   DATE '2025-10-03'),
    (3, 'Sarah Jones',    DATE '2025-11-19'),
    (4, 'Michael Brown',  DATE '2025-08-27'),
    (5, 'Grace Boateng',  DATE '2026-01-08'),
    (6, 'James Wilson',   DATE '2026-02-13'),
    (7, 'Fatima Khan',    DATE '2026-03-02'),
    (8, 'Olivia Smith',   DATE '2026-04-11');

INSERT INTO products (product_id, product_name, unit_price) VALUES
    (1, 'Laptop Stand', 45.00),
    (2, 'Keyboard',     80.00),
    (3, 'Monitor',     220.00),
    (4, 'Headphones',  120.00),
    (5, 'Webcam',       90.00),
    (6, 'Desk Lamp',    50.00);

INSERT INTO orders (order_id, customer_id, order_date, status) VALUES
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

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (101, 3, 1, 220.00),
    (101, 5, 1,  90.00),
    (102, 2, 1,  80.00),
    (102, 4, 1, 120.00),
    (103, 1, 2,  45.00),
    (103, 6, 1,  50.00),
    (104, 3, 1, 220.00),
    (105, 3, 2, 220.00),
    (106, 4, 1, 120.00),
    (106, 5, 1,  90.00),
    (107, 1, 1,  45.00),
    (107, 2, 1,  80.00),
    (108, 5, 1,  90.00),
    (109, 6, 2,  50.00),
    (109, 4, 1, 120.00),
    (110, 3, 1, 220.00),
    (110, 2, 1,  80.00),
    (111, 2, 2,  80.00),
    (111, 5, 1,  90.00),
    (112, 1, 3,  45.00),
    (113, 3, 1, 220.00),
    (113, 6, 1,  50.00),
    (114, 4, 2, 120.00);

-- Health checks: expected counts are 8, 6, 14 and 23.
SELECT COUNT(*) AS customer_rows FROM customers;
SELECT COUNT(*) AS product_rows FROM products;
SELECT COUNT(*) AS order_rows FROM orders;
SELECT COUNT(*) AS order_item_rows FROM order_items;