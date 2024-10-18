#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Import dependencies
source ./config.sh
source ./logger.sh
source ./create_tables.sh
source ./crud_operations.sh

# Fungsi untuk menangani kesalahan
handle_error() {
    log_error "$1"
    exit 1
}

# Fungsi untuk menyiapkan direktori temporer
setup_temp_dir() {
    TEMP_DIR=$(sudo mktemp -d)
    sudo chown postgres:postgres "$TEMP_DIR"
    log_info "Temporary directory created: $TEMP_DIR"
}

# Fungsi untuk membersihkan direktori temporer
cleanup_temp_dir() {
    if [ -d "$TEMP_DIR" ]; then
        sudo rm -rf "$TEMP_DIR"
        log_info "Temporary directory removed: $TEMP_DIR"
    fi
}

# Pastikan direktori temporer dibersihkan saat script berakhir
trap cleanup_temp_dir EXIT

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
    local version
    version=$(sudo -u postgres bash -c 'PGDATA=/var/lib/postgresql/*/main/ psql --no-align --tuples-only -c "SHOW server_version_num;"' 2>/dev/null | sed 's/^.//')
    if [ $? -ne 0 ] || [ -z "$version" ]; then
        log_error "Failed to get PostgreSQL version. Please check if PostgreSQL is installed and running."
        return 1
    fi
    log_debug "Full PostgreSQL version number: $version"
    echo "${version:0:2}"
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
    log_info "Creating database $DB_NAME and user $DB_USER..."
    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF
    if [ $? -ne 0 ]; then
        handle_error "Failed to create database and user"
    fi
    log_info "Database and user created successfully."
}

# Fungsi untuk mengkonfigurasi PostgreSQL untuk remote access
configure_postgresql() {
    local pg_version=$1
    log_info "Configuring PostgreSQL version $pg_version for remote access..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$pg_version/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$pg_version/main/pg_hba.conf
    sudo systemctl restart postgresql || handle_error "Failed to restart PostgreSQL"
    log_info "PostgreSQL configured for remote access."
}

# Fungsi untuk setup Foreign Data Wrapper
setup_fdw() {
    log_info "Setting up Foreign Data Wrapper..."
    read -p "Enter audit server IP: " audit_server_ip
    read -p "Enter audit server port (default 5432): " audit_server_port
    audit_server_port=${audit_server_port:-5432}
    
    sudo -u postgres psql -d $DB_NAME << EOF
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER IF NOT EXISTS audit_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '$audit_server_ip', port '$audit_server_port', dbname '$AUDIT_DB_NAME');
CREATE USER MAPPING IF NOT EXISTS FOR $DB_USER
    SERVER audit_server
    OPTIONS (user '$AUDIT_DB_USER', password '$AUDIT_DB_PASSWORD');
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
    if [ $? -ne 0 ]; then
        handle_error "Failed to setup Foreign Data Wrapper"
    fi
    log_info "Foreign Data Wrapper setup completed."
}

# Fungsi untuk menghapus fungsi dan tabel audit
drop_audit_objects() {
    log_info "Dropping audit-related objects..."
    sudo -u postgres psql -d $DB_NAME << EOF
-- Drop triggers
DROP TRIGGER IF EXISTS products_audit_trigger ON products;
DROP TRIGGER IF EXISTS orders_audit_trigger ON orders;

-- Drop function
DROP FUNCTION IF EXISTS audit_trigger_func();

-- Drop foreign table
DROP FOREIGN TABLE IF EXISTS audit_log;

-- Drop foreign data wrapper objects
DROP USER MAPPING IF EXISTS FOR $DB_USER SERVER audit_server;
DROP SERVER IF EXISTS audit_server CASCADE;
DROP EXTENSION IF EXISTS postgres_fdw;
EOF
    if [ $? -ne 0 ]; then
        handle_error "Failed to drop audit objects"
    fi
    log_info "Audit-related objects dropped successfully."
}

# Fungsi untuk membuat trigger audit
create_audit_trigger() {
    log_info "Creating audit trigger..."
    sudo -u postgres psql -d $DB_NAME << EOF
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
    if [ $? -ne 0 ]; then
        handle_error "Failed to create audit trigger"
    fi
    log_info "Audit trigger created successfully."
}

# Main function
main_server_setup() {
    log_info "Starting main server setup..."
    setup_temp_dir

    if check_postgresql_installed; then
        log_info "PostgreSQL is already installed. Proceeding with configuration..."
        local pg_version
        if ! pg_version=$(get_postgresql_version); then
            log_error "Failed to get PostgreSQL version. Exiting setup."
            exit 1
        fi
        configure_postgresql "$pg_version"
    else
        log_info "PostgreSQL is not installed. Installing now..."
        install_postgresql
        local pg_version
        if ! pg_version=$(get_postgresql_version); then
            log_error "Failed to get PostgreSQL version after installation. Exiting setup."
            exit 1
        fi
        configure_postgresql "$pg_version"
    fi

    create_db_and_user
    
    # Option to drop existing audit objects
    read -p "Do you want to drop existing audit objects? (y/n): " drop_choice
    if [[ $drop_choice == "y" || $drop_choice == "Y" ]]; then
        drop_audit_objects
    fi
    
    setup_fdw
    create_sample_tables
    create_audit_trigger
    perform_sample_crud
    display_crud_results
    
    log_info "Main server setup completed successfully!"
    log_info "You can now connect to this PostgreSQL server remotely using:"
    log_info "psql -h <this_server_ip> -p 5432 -U $DB_USER -d $DB_NAME"
}

# Run the main function
main_server_setup