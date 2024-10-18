#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Import dependencies
source ./config.sh
source ./logger.sh
source ./create_tables.sh

# Fungsi untuk menangani kesalahan
handle_error() {
    log_error "$1"
    exit 1
}

# Fungsi untuk memeriksa apakah PostgreSQL sudah terinstal
check_postgresql_installed() {
    if command -v psql &> /dev/null && sudo systemctl is-active --quiet postgresql; then
        log_info "PostgreSQL is already installed and running."
        return 0
    else
        log_info "PostgreSQL is not installed or not running."
        return 1
    fi
}

# Fungsi untuk mendapatkan versi utama PostgreSQL
get_postgresql_version() {
    local version=$(sudo -u postgres psql -t -c "SHOW server_version_num;" | tr -d ' \n' | cut -c1-2)
    log_debug "PostgreSQL version: $version"
    echo "$version"
}

# Fungsi untuk menginstal PostgreSQL
install_postgresql() {
    log_info "Installing PostgreSQL..."
    sudo apt-get update || handle_error "Failed to update package list"
    sudo apt-get install -y postgresql postgresql-contrib || handle_error "Failed to install PostgreSQL"
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    log_info "PostgreSQL installed successfully."
}

# Fungsi untuk membuat database dan user
create_db_and_user() {
    log_info "Creating database $AUDIT_DB_NAME and user $AUDIT_DB_USER..."
    sudo -u postgres psql << EOF
CREATE DATABASE $AUDIT_DB_NAME;
CREATE USER $AUDIT_DB_USER WITH ENCRYPTED PASSWORD '$AUDIT_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $AUDIT_DB_NAME TO $AUDIT_DB_USER;
EOF
    log_info "Database and user created successfully."
}

# Fungsi untuk mengkonfigurasi PostgreSQL untuk remote access
configure_postgresql() {
    local version=$(sudo -u postgres psql -t -c "SHOW server_version_num;" | tr -d ' \n' | cut -c1-2)
    log_info "Configuring PostgreSQL version $pg_version for remote access..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$pg_version/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$pg_version/main/pg_hba.conf
    sudo systemctl restart postgresql || handle_error "Failed to restart PostgreSQL"
    log_info "PostgreSQL configured for remote access."
}

# Fungsi untuk menghapus tabel audit
drop_audit_table() {
    log_info "Dropping audit_log table..."
    sudo -u postgres psql -d $AUDIT_DB_NAME << EOF
DROP TABLE IF EXISTS audit_log;
EOF
    log_info "Audit table dropped successfully."
}

# Main function
audit_server_setup() {
    log_info "Starting audit server setup..."
    if check_postgresql_installed; then
        log_info "PostgreSQL is already installed. Proceeding with configuration..."
        local pg_version=$(get_postgresql_version)
        configure_postgresql