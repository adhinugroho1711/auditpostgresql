#!/bin/bash

# Import dependencies
source ./config.sh
source ./logger.sh

# Fungsi untuk melakukan operasi CRUD sampel
perform_sample_crud() {
    log_info "Performing sample CRUD operations..."
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME << EOF
-- Hapus data yang ada (jika ada)
DELETE FROM items;

-- Reset sequence untuk id
ALTER SEQUENCE items_id_seq RESTART WITH 1;

-- Insert sample items
INSERT INTO items (name, description, price, quantity) VALUES 
('Smartphone', 'High-end smartphone with advanced features', 699.99, 50),
('Laptop', 'Powerful laptop for work and gaming', 1299.99, 30),
('Wireless Earbuds', 'True wireless earbuds with noise cancellation', 149.99, 100),
('Smart Watch', 'Fitness tracker and smartwatch', 199.99, 75),
('Tablet', '10-inch tablet with high-resolution display', 349.99, 40);

-- Read inserted items
SELECT * FROM items;

-- Update some items
UPDATE items SET price = 679.99, quantity = quantity - 5 WHERE name = 'Smartphone';
UPDATE items SET description = 'Ultra-thin laptop for work and entertainment' WHERE name = 'Laptop';

-- Delete an item
DELETE FROM items WHERE name = 'Tablet';

-- Final read to show results
SELECT * FROM items ORDER BY id;

-- Display audit logs
SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 10;
EOF
    log_info "Sample CRUD operations completed."
}

# Fungsi untuk menampilkan hasil operasi CRUD
display_crud_results() {
    log_info "Displaying CRUD results..."
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME << EOF
\echo 'Current items in the database:'
SELECT * FROM items ORDER BY id;

\echo '\nRecent audit log entries:'
SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 5;
EOF
    log_info "CRUD results displayed."
}