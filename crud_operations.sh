#!/bin/bash

# Import dependencies
source ./config.sh
source ./logger.sh

# Fungsi untuk melakukan operasi CRUD sampel
perform_sample_crud() {
    log_info "Performing sample CRUD operations..."
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME << EOF
-- Hapus data yang ada (jika ada)
DELETE FROM orders;
DELETE FROM products;

-- Reset sequence untuk id
ALTER SEQUENCE products_id_seq RESTART WITH 1;
ALTER SEQUENCE orders_id_seq RESTART WITH 1;

-- Insert sample products
INSERT INTO products (name, price, stock) VALUES 
('Smartphone', 499.99, 100),
('Laptop', 999.99, 50),
('Tablet', 299.99, 75),
('Smartwatch', 199.99, 150),
('Wireless Earbuds', 129.99, 200),
('4K TV', 799.99, 30),
('Gaming Console', 399.99, 60),
('Digital Camera', 599.99, 40),
('Bluetooth Speaker', 79.99, 100),
('External Hard Drive', 89.99, 80);

-- Read inserted products
SELECT * FROM products;

-- Update some products
UPDATE products SET price = 449.99 WHERE name = 'Smartphone';
UPDATE products SET stock = stock - 5 WHERE name = 'Laptop';

-- Insert sample orders
INSERT INTO orders (product_id, quantity, order_date) VALUES 
(1, 2, CURRENT_TIMESTAMP - INTERVAL '3 days'),
(2, 1, CURRENT_TIMESTAMP - INTERVAL '2 days'),
(3, 3, CURRENT_TIMESTAMP - INTERVAL '1 day'),
(4, 1, CURRENT_TIMESTAMP),
(5, 2, CURRENT_TIMESTAMP),
(1, 1, CURRENT_TIMESTAMP + INTERVAL '1 day'),
(6, 1, CURRENT_TIMESTAMP + INTERVAL '2 days'),
(7, 1, CURRENT_TIMESTAMP + INTERVAL '3 days'),
(8, 1, CURRENT_TIMESTAMP + INTERVAL '4 days'),
(9, 3, CURRENT_TIMESTAMP + INTERVAL '5 days');

-- Read orders with product details
SELECT o.id, p.name, o.quantity, o.order_date 
FROM orders o 
JOIN products p ON o.product_id = p.id
ORDER BY o.order_date;

-- Delete an order
DELETE FROM orders WHERE id = 1;

-- Final read to show results
SELECT * FROM products ORDER BY id;
SELECT * FROM orders ORDER BY id;
EOF
    log_info "Sample CRUD operations completed."
}

# Fungsi untuk menampilkan hasil operasi CRUD
display_crud_results() {
    log_info "Displaying CRUD results..."
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME << EOF
\echo 'Products table:'
SELECT * FROM products ORDER BY id;
\echo '\nOrders table:'
SELECT o.id, p.name AS product_name, o.quantity, o.order_date 
FROM orders o 
JOIN products p ON o.product_id = p.id
ORDER BY o.id;
EOF
    log_info "CRUD results displayed."
}