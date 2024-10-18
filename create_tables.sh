#!/bin/bash

# Import logger
source ./logger.sh

# Fungsi untuk membuat tabel sampel
create_sample_tables() {
    log_info "Creating sample tables..."
    sudo -u postgres psql -d mydb << EOF
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
    log_info "Sample tables created successfully."
}

# Fungsi untuk membuat tabel audit
create_audit_table() {
    log_info "Creating audit_log table..."
    sudo -u postgres psql -d audit_db << EOF
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    user_name TEXT NOT NULL,
    action TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    query TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
    log_info "Audit table created successfully."
}
