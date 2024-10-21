#!/bin/bash

# Fungsi untuk memastikan pgAudit terinstal dan dimuat
ensure_pgaudit_loaded() {
    echo "Memastikan pgAudit terinstal dan dimuat..."
    
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'pgaudit';" | grep -q 1; then
        echo "pgAudit belum terinstal. Menginstal pgAudit..."
        sudo apt-get update
        sudo apt-get install -y postgresql-$PG_VERSION-pgaudit
    fi

    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_extension WHERE extname = 'pgaudit';" | grep -q 1; then
        echo "Memuat ekstensi pgAudit..."
        sudo -u postgres psql -c "CREATE EXTENSION pgaudit;"
    fi

    PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    if ! sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
        echo "Menambahkan pgaudit ke shared_preload_libraries..."
        if sudo grep -q "shared_preload_libraries" "$PGCONF"; then
            sudo sed -i "s/shared_preload_libraries = '/shared_preload_libraries = 'pgaudit,/" "$PGCONF"
        else
            echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
        fi
        echo "PostgreSQL perlu di-restart untuk memuat pgaudit. Me-restart PostgreSQL..."
        restart_postgresql
    fi

    echo "pgAudit telah terinstal dan dimuat."
}


# Fungsi untuk mengkonfigurasi pgAudit untuk semua database
configure_pgaudit_all_databases() {
    echo "Mengkonfigurasi pgAudit untuk semua database..."

    if ! ensure_pgaudit_loaded; then
        echo "Gagal memuat PgAudit. Konfigurasi audit tidak dapat dilanjutkan."
        return 1
    fi

    # Konfigurasi global
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log = 'write, function, role, ddl';"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_catalog = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_parameter = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_statement_once = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_level = log;"

    sudo -u postgres psql -c "ALTER SYSTEM SET log_connections = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_disconnections = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_duration = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_line_prefix = '%m [%p] %q%u@%d ';"

    # Dapatkan daftar semua database
    databases=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

    # Aktifkan pgAudit untuk setiap database
    for db in $databases; do
        echo "Mengaktifkan pgAudit untuk database: $db"
        sudo -u postgres psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS pgaudit;"
    done

    echo "Menerapkan perubahan konfigurasi..."
    restart_postgresql

    echo "Konfigurasi pgAudit untuk semua database selesai."
}


# Fungsi untuk membuat trigger yang akan mengaktifkan audit pada tabel baru
create_audit_trigger_function() {
    echo "Membuat fungsi trigger untuk mengaktifkan audit pada tabel baru..."
    
    sudo -u postgres psql -c "
    CREATE OR REPLACE FUNCTION public.enable_table_audit()
    RETURNS event_trigger AS \$\$
    DECLARE
        obj record;
    BEGIN
        FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE command_tag = 'CREATE TABLE'
        LOOP
            EXECUTE format('CREATE TRIGGER %I_audit_trigger
                            AFTER INSERT OR UPDATE OR DELETE ON %I.%I
                            FOR EACH ROW EXECUTE FUNCTION pgaudit.fn_audit_event()',
                           obj.object_identity,
                           obj.schema_name,
                           obj.object_identity);
        END LOOP;
    END;
    \$\$ LANGUAGE plpgsql;

    CREATE EVENT TRIGGER enable_table_audit_trigger ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE')
    EXECUTE FUNCTION public.enable_table_audit();
    "

    echo "Fungsi trigger untuk mengaktifkan audit pada tabel baru telah dibuat."
}

# Fungsi untuk memeriksa log audit
check_audit_logs() {
    echo "Memeriksa log audit..."
    sudo tail -n 50 /var/log/postgresql/postgresql-$PG_VERSION-main.log
    echo "Selesai memeriksa log audit."
}