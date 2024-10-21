#!/bin/bash

# Konfigurasi
AUDIT_DB_NAME="audit_db"
AUDIT_USER="audit_user"
AUDIT_PASSWORD="audit_password" # Ganti dengan password yang kuat

# Fungsi untuk membuat database audit dan user
create_audit_database() {
    echo "Membuat database audit dan user..."
    
    # Buat user audit
    sudo -u postgres psql -c "CREATE USER $AUDIT_USER WITH PASSWORD '$AUDIT_PASSWORD';"
    
    # Buat database audit
    sudo -u postgres createdb $AUDIT_DB_NAME
    
    # Berikan hak akses ke user audit
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $AUDIT_DB_NAME TO $AUDIT_USER;"
    
    echo "Database audit dan user telah dibuat."
}

# Fungsi untuk membuat tabel audit
create_audit_tables() {
    echo "Membuat tabel-tabel audit..."
    
    sudo -u postgres psql -d $AUDIT_DB_NAME -c "
    CREATE TABLE IF NOT EXISTS audit_log (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        ip_address INET,
        username TEXT,
        database_name TEXT,
        schema_name TEXT,
        table_name TEXT,
        query_type TEXT,
        query_text TEXT,
        old_data JSONB,
        new_data JSONB
    );

    CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);
    CREATE INDEX idx_audit_log_username ON audit_log(username);
    CREATE INDEX idx_audit_log_database ON audit_log(database_name);
    "
    
    echo "Tabel-tabel audit telah dibuat."
}

# Fungsi untuk membuat fungsi audit
create_audit_function() {
    echo "Membuat fungsi audit..."
    
    sudo -u postgres psql -d $AUDIT_DB_NAME -c "
    CREATE OR REPLACE FUNCTION public.audit_trigger_func()
    RETURNS trigger AS \$\$
    DECLARE
        audit_row audit_log;
        include_values boolean;
        log_old_data boolean;
        log_new_data boolean;
    BEGIN
        IF TG_WHEN != 'AFTER' THEN
            RAISE EXCEPTION 'audit_trigger_func() may only run as an AFTER trigger';
        END IF;

        audit_row = ROW(
            nextval('audit_log_id_seq'),  -- id
            current_timestamp,            -- timestamp
            inet_client_addr(),           -- ip_address
            session_user::text,           -- username
            current_database()::text,     -- database_name
            TG_TABLE_SCHEMA::text,        -- schema_name
            TG_TABLE_NAME::text,          -- table_name
            TG_OP,                        -- query_type
            current_query(),              -- query_text
            NULL, NULL                    -- old_data and new_data, we'll fill these below
        );

        IF TG_ARGV[0] IS NOT NULL THEN
            include_values = TG_ARGV[0];
        ELSE
            include_values = true;
        END IF;

        IF (TG_OP = 'UPDATE' AND include_values) THEN
            audit_row.old_data = row_to_json(OLD)::JSONB;
            audit_row.new_data = row_to_json(NEW)::JSONB;
        ELSIF (TG_OP = 'DELETE' AND include_values) THEN
            audit_row.old_data = row_to_json(OLD)::JSONB;
        ELSIF (TG_OP = 'INSERT' AND include_values) THEN
            audit_row.new_data = row_to_json(NEW)::JSONB;
        END IF;

        INSERT INTO audit_log VALUES (audit_row.*);
        RETURN NULL;
    END;
    \$\$ LANGUAGE plpgsql SECURITY DEFINER;
    "
    
    echo "Fungsi audit telah dibuat."
}

# Fungsi untuk menambahkan trigger audit ke semua tabel
add_audit_triggers() {
    echo "Menambahkan trigger audit ke semua tabel..."
    
    sudo -u postgres psql -c "
    CREATE OR REPLACE FUNCTION public.add_audit_trigger_to_table(target_table regclass)
    RETURNS void AS \$\$
    DECLARE
        trigger_name text;
    BEGIN
        trigger_name := target_table::text || '_audit_trigger';
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON %s', trigger_name, target_table);
        EXECUTE format('CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON %s FOR EACH ROW EXECUTE FUNCTION public.audit_trigger_func()', trigger_name, target_table);
    END;
    \$\$ LANGUAGE plpgsql;

    CREATE OR REPLACE FUNCTION public.add_audit_triggers_to_all_tables()
    RETURNS void AS \$\$
    DECLARE
        target_table regclass;
    BEGIN
        FOR target_table IN (SELECT quote_ident(schemaname) || '.' || quote_ident(tablename) FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema'))
        LOOP
            PERFORM public.add_audit_trigger_to_table(target_table);
        END LOOP;
    END;
    \$\$ LANGUAGE plpgsql;

    SELECT public.add_audit_triggers_to_all_tables();
    "
    
    echo "Trigger audit telah ditambahkan ke semua tabel."
}

# Fungsi untuk mengkonfigurasi pgAudit
configure_pgaudit() {
    echo "Mengkonfigurasi pgAudit..."
    
    sudo -u postgres psql -c "
    ALTER SYSTEM SET pgaudit.log = 'write, function, role, ddl';
    ALTER SYSTEM SET pgaudit.log_catalog = on;
    ALTER SYSTEM SET pgaudit.log_parameter = on;
    ALTER SYSTEM SET pgaudit.log_statement_once = off;
    ALTER SYSTEM SET pgaudit.log_level = log;
    "
    
    echo "pgAudit telah dikonfigurasi."
}

# Fungsi utama untuk setup audit
setup_audit() {
    create_audit_database
    create_audit_tables
    create_audit_function
    add_audit_triggers
    configure_pgaudit
    
    echo "Restart PostgreSQL untuk menerapkan perubahan..."
    sudo systemctl restart postgresql
    
    echo "Setup audit selesai."
}

# Fungsi untuk memeriksa log audit
check_audit_logs() {
    echo "Memeriksa log audit..."
    sudo -u postgres psql -d $AUDIT_DB_NAME -c "SELECT * FROM audit_log ORDER BY timestamp DESC LIMIT 10;"
    echo "Selesai memeriksa log audit."
}

# Menu utama
while true; do
    clear
    echo "==== PostgreSQL Audit Database Management ===="
    echo "1. Setup Audit Database"
    echo "2. Periksa Log Audit"
    echo "3. Keluar"
    read -p "Pilih opsi (1-3): " choice

    case $choice in
        1)
            setup_audit
            ;;
        2)
            check_audit_logs
            ;;
        3)
            echo "Terima kasih telah menggunakan script ini."
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid. Silakan coba lagi."
            ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done