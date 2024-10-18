#!/bin/bash

# Import logger dan config
source ./logger.sh
source ./config.sh

# Fungsi untuk membuat tabel sampel
create_sample_tables() {
    log_info "Creating sample tables..."
    sudo -u postgres psql -d $DB_NAME << EOF
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

-- Berikan izin pada user utama
GRANT ALL PRIVILEGES ON TABLE products, orders TO $DB_USER;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;

-- Berikan izin pada skema public
GRANT USAGE ON SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
EOF
    if [ $? -ne 0 ]; then
        log_error "Failed to create sample tables"
        return 1
    fi
    log_info "Sample tables created successfully."
}

# Fungsi untuk membuat tabel audit
create_audit_table() {
    log_info "Creating audit_log table..."
    sudo -u postgres psql -d $AUDIT_DB_NAME << EOF
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

-- Berikan izin pada audit user
GRANT ALL PRIVILEGES ON TABLE audit_log TO $AUDIT_DB_USER;
GRANT USAGE, SELECT ON SEQUENCE audit_log_id_seq TO $AUDIT_DB_USER;

-- Berikan izin pada skema public
GRANT USAGE ON SCHEMA public TO $AUDIT_DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $AUDIT_DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $AUDIT_DB_USER;
EOF
    if [ $? -ne 0 ]; then
        log_error "Failed to create audit table"
        return 1
    fi
    log_info "Audit table created successfully."
}