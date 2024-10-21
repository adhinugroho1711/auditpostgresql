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

# Fungsi untuk menyiapkan direktori temporer
setup_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    log_info "Temporary directory created: $TEMP_DIR"
}

# Fungsi untuk membersihkan direktori temporer
cleanup_temp_dir() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log_info "Temporary directory removed: $TEMP_DIR"
    fi
}

# Pastikan direktori temporer dibersihkan saat script berakhir
trap cleanup_temp_dir EXIT

# Fungsi untuk memeriksa apakah PostgreSQL sudah terinstal
check_postgresql_installed() {
    log_info "Checking if PostgreSQL $PG_VERSION is installed..."
    if dpkg -s postgresql-$PG_VERSION &> /dev/null; then
        log_info "PostgreSQL $PG_VERSION is installed."
        return 0
    else
        log_info "PostgreSQL $PG_VERSION is not installed."
        return 1
    fi
}

# Fungsi untuk memeriksa status PostgreSQL
check_postgresql_status() {
    log_info "Checking PostgreSQL status..."
    if sudo systemctl is-active --quiet postgresql; then
        log_info "PostgreSQL is running."
        return 0
    else
        log_error "PostgreSQL is not running. Attempting to start..."
        sudo systemctl start postgresql
        if sudo systemctl is-active --quiet postgresql; then
            log_info "PostgreSQL started successfully."
            return 0
        else
            log_error "Failed to start PostgreSQL. Check system logs for more information."
            return 1
        fi
    fi
}

# Fungsi untuk menginstal PostgreSQL
install_postgresql() {
    log_info "Installing PostgreSQL $PG_VERSION..."
    sudo apt-get update || handle_error "Failed to update package list"
    sudo apt-get install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION || handle_error "Failed to install PostgreSQL $PG_VERSION"
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    log_info "PostgreSQL $PG_VERSION installed successfully."
    
    # Tambahkan pengecekan status setelah instalasi
    if ! check_postgresql_status; then
        handle_error "PostgreSQL installation completed, but the service is not running."
    fi
}

# Fungsi untuk membuat database dan user
create_db_and_user() {
    log_info "Creating database $AUDIT_DB_NAME and user $AUDIT_DB_USER..."
    sudo -u postgres psql << EOF
CREATE DATABASE $AUDIT_DB_NAME;
CREATE USER $AUDIT_DB_USER WITH ENCRYPTED PASSWORD '$AUDIT_DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $AUDIT_DB_NAME TO $AUDIT_DB_USER;
EOF
    if [ $? -ne 0 ]; then
        handle_error "Failed to create database and user"
    fi
    
    # Tambahkan izin tambahan
    sudo -u postgres psql -d $AUDIT_DB_NAME << EOF
GRANT ALL PRIVILEGES ON SCHEMA public TO $AUDIT_DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $AUDIT_DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $AUDIT_DB_USER;
EOF
    if [ $? -ne 0 ]; then
        handle_error "Failed to grant additional permissions"
    fi
    
    log_info "Database, user, and permissions created successfully."
}

# Fungsi untuk mengkonfigurasi PostgreSQL untuk remote access
configure_postgresql() {
    log_info "Configuring PostgreSQL $PG_VERSION for remote access..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$PG_VERSION/main/pg_hba.conf
    sudo systemctl restart postgresql || handle_error "Failed to restart PostgreSQL"
    log_info "PostgreSQL configured for remote access."
}

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

-- Berikan akses ke sequence audit_log_id_seq untuk user utama
GRANT USAGE, SELECT ON SEQUENCE audit_log_id_seq TO $DB_USER;
EOF
    if [ $? -ne 0 ]; then
        log_error "Failed to create audit table"
        return 1
    fi
    log_info "Audit table created successfully."
}

# Main function
audit_server_setup() {
    log_info "Starting audit server setup..."
    setup_temp_dir

    if check_postgresql_installed; then
        log_info "PostgreSQL $PG_VERSION is already installed. Proceeding with configuration..."
    else
        log_info "PostgreSQL $PG_VERSION is not installed. Installing now..."
        install_postgresql
    fi
    
    # Pastikan PostgreSQL berjalan
    if ! check_postgresql_status; then
        handle_error "PostgreSQL is not running. Cannot proceed with setup."
    fi

    configure_postgresql
    create_db_and_user
    create_audit_table
    
    log_info "Audit server setup completed successfully!"
    log_info "You can now connect to this PostgreSQL server remotely using:"
    log_info "psql -h <this_server_ip> -p 5432 -U $AUDIT_DB_USER -d $AUDIT_DB_NAME"
}

# Run the main function
audit_server_setup