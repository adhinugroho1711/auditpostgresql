#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Fungsi untuk menangani kesalahan
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Fungsi untuk memeriksa apakah PostgreSQL sudah terinstal
check_postgresql_installed() {
    if command -v psql &> /dev/null && sudo systemctl is-active --quiet postgresql; then
        echo "PostgreSQL is already installed and running."
        return 0
    else
        echo "PostgreSQL is not installed or not running."
        return 1
    fi
}

# Fungsi untuk mendapatkan versi PostgreSQL
get_postgresql_version() {
    local version=$(sudo -u postgres psql -t -c "SHOW server_version_num;" | tr -d ' \n' | cut -c1-2)
    echo "$version"
}

# Fungsi untuk menginstal PostgreSQL
install_postgresql() {
    echo "Installing PostgreSQL..."
    sudo apt-get update || handle_error "Failed to update package list"
    sudo apt-get install -y postgresql postgresql-contrib || handle_error "Failed to install PostgreSQL"
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
}

# Fungsi untuk membuat database dan user
create_db_and_user() {
    echo "Creating database mydb and user..."
    sudo -u postgres psql << EOF
CREATE DATABASE mydb;
CREATE USER myuser WITH ENCRYPTED PASSWORD 'mypassword';
GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;
EOF
}

# Fungsi untuk mengkonfigurasi PostgreSQL untuk remote access
configure_postgresql() {
    local pg_version=$1
    echo "Configuring PostgreSQL version $pg_version for remote access..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$pg_version/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$pg_version/main/pg_hba.conf
    sudo systemctl restart postgresql || handle_error "Failed to restart PostgreSQL"
}

# Fungsi untuk setup Foreign Data Wrapper
setup_fdw() {
    echo "Setting up Foreign Data Wrapper..."
    read -p "Enter audit server IP: " audit_server_ip
    read -p "Enter audit server port (default 5432): " audit_server_port
    audit_server_port=${audit_server_port:-5432}
    
    sudo -u postgres psql -d mydb << EOF
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER IF NOT EXISTS audit_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '$audit_server_ip', port '$audit_server_port', dbname 'audit_db');
CREATE USER MAPPING IF NOT EXISTS FOR myuser
    SERVER audit_server
    OPTIONS (user 'audit_user', password 'audit_password');
CREATE FOREIGN TABLE IF NOT EXISTS audit_log (
    id INTEGER,
    table_name TEXT,
    user_name TEXT,
    action TEXT,
    old_data JSONB,
    new_data JSONB,
    query TEXT,
    timestamp TIMESTAMP
) SERVER audit_server OPTIONS (schema_name 'public', table_name 'audit_log');
EOF
}

# Fungsi untuk membuat tabel sampel
create_sample_tables() {
    echo "Creating sample tables..."
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
    echo "Sample tables created successfully."
}

# Fungsi untuk membuat trigger audit
create_audit_trigger() {
    echo "Creating audit trigger..."
    sudo -u postgres psql -d mydb << EOF
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS \$\$
DECLARE
    old_row JSONB = NULL;
    new_row JSONB = NULL;
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        old_row = to_jsonb(OLD);
        new_row = to_jsonb(NEW);
    ELSIF (TG_OP = 'DELETE') THEN
        old_row = to_jsonb(OLD);
    ELSIF (TG_OP = 'INSERT') THEN
        new_row = to_jsonb(NEW);
    END IF;

    INSERT INTO audit_log (table_name, user_name, action, old_data, new_data, query)
    VALUES (TG_TABLE_NAME::TEXT, session_user::TEXT, TG_OP, old_row, new_row, current_query());
    
    RETURN NULL;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER products_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();

CREATE TRIGGER orders_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON orders
FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();
EOF
    echo "Audit trigger created successfully."
}

# Fungsi untuk melakukan operasi CRUD sampel
perform_sample_crud() {
    echo "Performing sample CRUD operations..."
    sudo -u postgres psql -d mydb << EOF
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
    echo "Sample CRUD operations completed."
}

# Main function
main_server_setup() {
    if check_postgresql_installed; then
        echo "PostgreSQL is already installed. Proceeding with configuration..."
        local pg_version=$(get_postgresql_version)
        configure_postgresql "$pg_version"
    else
        echo "PostgreSQL is not installed. Installing now..."
        install_postgresql
        local pg_version=$(get_postgresql_version)
        configure_postgresql "$pg_version"
    fi

    create_db_and_user
    setup_fdw
    create_sample_tables
    create_audit_trigger
    perform_sample_crud
    
    echo "Main server setup completed successfully!"
    echo "You can now connect to this PostgreSQL server remotely using:"
    echo "psql -h <this_server_ip> -p 5432 -U myuser -d mydb"
}

# Run the main function
main_server_setup