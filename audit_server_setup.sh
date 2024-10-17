#!/bin/bash

# Fungsi untuk menangani kesalahan
handle_error() {
    echo "Error: $1"
    exit 1
}

# Fungsi untuk menginstal PostgreSQL
install_postgresql() {
    echo "Installing PostgreSQL..."
    sudo apt-get update || handle_error "Failed to update package list"
    sudo apt-get install -y postgresql postgresql-contrib || handle_error "Failed to install PostgreSQL"
}

# Fungsi untuk membuat database dan user
create_db_and_user() {
    echo "Creating database audit_db and user..."
    sudo -u postgres psql -c "CREATE DATABASE audit_db;" || handle_error "Failed to create database audit_db"
    sudo -u postgres psql -c "CREATE USER audit_user WITH ENCRYPTED PASSWORD 'audit_password';" || handle_error "Failed to create user audit_user"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE audit_db TO audit_user;" || handle_error "Failed to grant privileges to audit_user"
}

# Fungsi untuk mengkonfigurasi PostgreSQL
configure_postgresql() {
    echo "Configuring PostgreSQL..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf
    sudo systemctl restart postgresql || handle_error "Failed to restart PostgreSQL"
}

# Fungsi untuk membuat tabel audit
create_audit_table() {
    echo "Creating audit_log table..."
    sudo -u postgres psql -d audit_db -c "
    CREATE TABLE audit_log (
        id SERIAL PRIMARY KEY,
        table_name TEXT NOT NULL,
        user_name TEXT NOT NULL,
        action TEXT NOT NULL,
        old_data JSONB,
        new_data JSONB,
        query TEXT,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );" || handle_error "Failed to create audit_log table"
}

# Main function
audit_server_setup() {
    install_postgresql
    create_db_and_user
    configure_postgresql
    create_audit_table
    echo "Audit server setup completed successfully!"
}

# Run the main function
audit_server_setup
