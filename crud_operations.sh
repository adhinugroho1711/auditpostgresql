#!/bin/bash

# Import dependencies
source ./config.sh
source ./logger.sh

# Fungsi untuk melakukan operasi CRUD sampel
perform_sample_crud() {
    log_info "Performing sample CRUD operations..."
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME << EOF
-- Create (Insert) sample product
INSERT INTO products (name, price, stock) VALUES ('Laptop', 999.99, 50);
INSERT INTO products (name, price, stock) VALUES ('Smartphone', 499.99, 100);

-- Read (Select) products
SELECT * FROM products;

-- Update product
UPDATE products SET price = 1099.99 WHERE name = 'Laptop';

-- Create (Insert) sample order
INSERT INTO orders (product_id, quantity) VALUES (1, 2);

-- Read (Select) orders with product details
SELECT o.id, p.name, o.quantity, o.order_date 
FROM orders o 
JOIN products p ON o.product_id = p.id;

-- Delete order
DELETE FROM orders WHERE id = 1;

-- Final read to show results
SELECT * FROM products;
SELECT * FROM orders;
EOF
    log_info "Sample CRUD operations completed."
}

# Fungsi untuk menampilkan hasil operasi CRUD
display_crud_results() {
    log_info "Displaying CRUD results..."
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME << EOF
\echo 'Products table:'
SELECT * FROM products;
\echo 'Orders table:'
SELECT * FROM orders;
EOF
    log_info "CRUD results displayed."
}