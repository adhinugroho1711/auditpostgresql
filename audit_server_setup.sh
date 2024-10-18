#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Fungsi untuk menangani kesalahan
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Fungsi untuk memeriksa apakah PostgreSQL sudah terinstal
check_postgresql_installed() {
    if command -v psql &> /dev/null; then
        echo "PostgreSQL is already installed."
        return 0
    else
        return 1
    fi
}

# Fungsi untuk menginstal PostgreSQL
install_postgresql() {
    if check_postgresql_installed; then
        echo "Skipping PostgreSQL installation as it's already installed."
    else
        echo "Installing PostgreSQL..."
        sudo apt-get update || handle_error "Failed to update package list"
        sudo apt-get install -y postgresql postgresql-contrib || handle_error "Failed to install PostgreSQL"
    fi
}

# Fungsi untuk membuat database dan user
create_db_and_user() {
    echo "Creating database audit_db and user..."
    sudo -u postgres psql << EOF
CREATE DATABASE audit_db;
CREATE USER audit_user WITH ENCRYPTED PASSWORD 'audit_password';
GRANT ALL PRIVILEGES ON DATABASE audit_db TO audit_user;
EOF
}

# Fungsi untuk mendapatkan versi PostgreSQL
get_postgresql_version() {
    local version=$(psql --version | awk '{print $3}' | cut -d. -f1,2)
    echo "$version"
}

# Fungsi untuk mengkonfigurasi PostgreSQL untuk remote access
configure_postgresql() {
    echo "Configuring PostgreSQL for remote access..."
    local pg_version=$(get_postgresql_version)
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$pg_version/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$pg_version/main/pg_hba.conf
    sudo systemctl restart postgresql || handle_error "Failed to restart PostgreSQL"
}

# Fungsi untuk membuat tabel audit
create_audit_table() {
    echo "Creating audit_log table..."
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
    echo "Audit table created successfully."
}

# Main function
audit_server_setup() {
    install_postgresql
    create_db_and_user
    configure_postgresql
    create_audit_table
    echo "Audit server setup completed successfully!"
    echo "You can now connect to this PostgreSQL server remotely using:"
    echo "psql -h <this_server_ip> -p 5432 -U audit_user -d audit_db"
}

# Run the main function
audit_server_setup
