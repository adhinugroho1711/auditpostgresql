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
    echo "Creating database mydb and user..."
    sudo -u postgres psql -c "CREATE DATABASE mydb;" || handle_error "Failed to create database mydb"
    sudo -u postgres psql -c "CREATE USER myuser WITH ENCRYPTED PASSWORD 'mypassword';" || handle_error "Failed to create user myuser"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;" || handle_error "Failed to grant privileges to myuser"
}

# Fungsi untuk mengkonfigurasi PostgreSQL
configure_postgresql() {
    echo "Configuring PostgreSQL..."
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/14/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf
    sudo systemctl restart postgresql || handle_error "Failed to restart PostgreSQL"
}

# Fungsi untuk setup Foreign Data Wrapper
setup_fdw() {
    echo "Setting up Foreign Data Wrapper..."
    sudo -u postgres psql -d mydb -c "CREATE EXTENSION postgres_fdw;" || handle_error "Failed to create postgres_fdw extension"
    sudo -u postgres psql -d mydb -c "CREATE SERVER audit_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'audit_server_ip', port '5432', dbname 'audit_db');" || handle_error "Failed to create foreign server"
    sudo -u postgres psql -d mydb -c "CREATE USER MAPPING FOR myuser SERVER audit_server OPTIONS (user 'audit_user', password 'audit_password');" || handle_error "Failed to create user mapping"
    sudo -u postgres psql -d mydb -c "CREATE FOREIGN TABLE audit_log (
        id INTEGER,
        table_name TEXT,
        user_name TEXT,
        action TEXT,
        old_data JSONB,
        new_data JSONB,
        query TEXT,
        timestamp TIMESTAMP
    ) SERVER audit_server OPTIONS (schema_name 'public', table_name 'audit_log');" || handle_error "Failed to create foreign table"
}

# Fungsi untuk membuat tabel dan trigger audit
create_audit_objects() {
    echo "Creating audit objects..."
    sudo -u postgres psql -d mydb -c "
    CREATE OR REPLACE FUNCTION audit_trigger_func()
    RETURNS TRIGGER AS \$\$
    DECLARE
        old_row JSONB;
        new_row JSONB;
    BEGIN
        IF (TG_OP = 'UPDATE') THEN
            old_row = row_to_json(OLD)::JSONB;
            new_row = row_to_json(NEW)::JSONB;
        ELSIF (TG_OP = 'DELETE') THEN
            old_row = row_to_json(OLD)::JSONB;
        ELSIF (TG_OP = 'INSERT') THEN
            new_row = row_to_json(NEW)::JSONB;
        END IF;

        INSERT INTO audit_log (
            table_name,
            user_name,
            action,
            old_data,
            new_data,
            query
        )
        VALUES (
            TG_TABLE_NAME::TEXT,
            session_user::TEXT,
            TG_OP,
            old_row,
            new_row,
            current_query()
        );
        RETURN NULL;
    END;
    \$\$ LANGUAGE plpgsql SECURITY DEFINER;" || handle_error "Failed to create audit trigger function"

    local tables=("products" "categories" "orders" "order_items")
    for table in "${tables[@]}"
    do
        sudo -u postgres psql -d mydb -c "
        CREATE TRIGGER ${table}_audit_trigger
        AFTER INSERT OR UPDATE OR DELETE ON $table
        FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();" || handle_error "Failed to create audit trigger for $table"
    done
}

# Main function
main_server_setup() {
    install_postgresql
    create_db_and_user
    configure_postgresql
    setup_fdw
    create_audit_objects
    echo "Main server setup completed successfully!"
}

# Run the main function
main_server_setup
