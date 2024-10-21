#!/bin/bash

# Fungsi untuk memastikan pgAudit dimuat
ensure_pgaudit_loaded() {
    echo "Memastikan pgAudit dimuat..."
    
    # Periksa apakah pgAudit sudah dimuat
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'pgaudit' AND installed_version IS NOT NULL;" | grep -q 1; then
        echo "pgAudit belum dimuat. Mencoba memuat pgAudit..."
        
        PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
        if ! sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
            echo "Menambahkan pgaudit ke shared_preload_libraries..."
            if sudo grep -q "shared_preload_libraries" "$PGCONF"; then
                sudo sed -i "s/shared_preload_libraries = '/shared_preload_libraries = 'pgaudit,/" "$PGCONF"
            else
                echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
            fi
        fi
        
        echo "Me-restart PostgreSQL untuk menerapkan perubahan..."
        sudo systemctl restart postgresql
        
        # Tunggu sebentar agar PostgreSQL memiliki waktu untuk restart
        sleep 5
        
        # Periksa lagi apakah pgAudit sudah dimuat
        if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'pgaudit' AND installed_version IS NOT NULL;" | grep -q 1; then
            echo "Gagal memuat pgAudit. Silakan periksa konfigurasi PostgreSQL Anda."
            return 1
        fi
    fi
    
    echo "pgAudit berhasil dimuat."
    return 0
}

configure_detailed_pgaudit() {
    echo "Mengkonfigurasi pgAudit dengan detail yang lebih lengkap..."

    if ! ensure_pgaudit_loaded; then
        echo "Gagal memuat pgAudit. Konfigurasi audit tidak dapat dilanjutkan."
        return 1
    fi

    # Konfigurasi global
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log = 'all';"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_catalog = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_parameter = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_statement_once = off;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_level = log;"
    
    # Konfigurasi untuk merekam detail tambahan
    sudo -u postgres psql -c "ALTER SYSTEM SET log_connections = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_disconnections = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_duration = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_line_prefix = '%m [%p] [%r] %q%u@%d from %h ';"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_statement = 'all';"
    
    # Konfigurasi untuk merekam query sebelum dan sesudah
    sudo -u postgres psql -c "ALTER SYSTEM SET track_activities = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET track_activity_query_size = 2048;"  # Increase if needed

    echo "Menerapkan perubahan konfigurasi..."
    sudo systemctl restart postgresql

    # Aktifkan pgAudit untuk setiap database
    databases=$(sudo -u postgres psql -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")
    for db in $databases; do
        echo "Mengaktifkan pgAudit untuk database: $db"
        sudo -u postgres psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS pgaudit;"
    done

    echo "Konfigurasi pgAudit dengan detail lengkap selesai."
}

# Fungsi untuk membuat tabel audit custom
create_custom_audit_table() {
    echo "Membuat tabel audit custom..."
    
    sudo -u postgres psql -c "
    CREATE TABLE IF NOT EXISTS public.custom_audit_log (
        id SERIAL PRIMARY KEY,
        timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        ip_address TEXT,
        username TEXT,
        database_name TEXT,
        query_before TEXT,
        query_after TEXT,
        query_type TEXT
    );
    "
    
    echo "Tabel audit custom telah dibuat."
}

# Fungsi untuk membuat trigger audit custom
create_custom_audit_trigger() {
    echo "Membuat trigger audit custom..."
    
    sudo -u postgres psql -c "
    CREATE OR REPLACE FUNCTION public.custom_audit_trigger_func()
    RETURNS trigger AS \$\$
    DECLARE
        old_row TEXT;
        new_row TEXT;
    BEGIN
        IF TG_OP = 'DELETE' THEN
            old_row = row_to_json(OLD)::TEXT;
            new_row = NULL;
        ELSIF TG_OP = 'UPDATE' THEN
            old_row = row_to_json(OLD)::TEXT;
            new_row = row_to_json(NEW)::TEXT;
        ELSIF TG_OP = 'INSERT' THEN
            old_row = NULL;
            new_row = row_to_json(NEW)::TEXT;
        END IF;

        INSERT INTO public.custom_audit_log (
            ip_address,
            username,
            database_name,
            query_before,
            query_after,
            query_type
        ) VALUES (
            inet_client_addr()::TEXT,
            current_user,
            current_database(),
            old_row,
            new_row,
            TG_OP
        );
        RETURN NULL;
    END;
    \$\$ LANGUAGE plpgsql;

    CREATE OR REPLACE FUNCTION public.add_custom_audit_trigger()
    RETURNS event_trigger AS \$\$
    DECLARE
        obj record;
    BEGIN
        FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE command_tag = 'CREATE TABLE'
        LOOP
            EXECUTE format(
                'CREATE TRIGGER %I_custom_audit_trigger
                AFTER INSERT OR UPDATE OR DELETE ON %I.%I
                FOR EACH ROW EXECUTE FUNCTION public.custom_audit_trigger_func()',
                obj.object_identity,
                obj.schema_name,
                obj.object_identity
            );
        END LOOP;
    END;
    \$\$ LANGUAGE plpgsql;

    CREATE EVENT TRIGGER add_custom_audit_trigger_event ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE')
    EXECUTE FUNCTION public.add_custom_audit_trigger();
    "
    
    echo "Trigger audit custom telah dibuat."
}

# Fungsi utama untuk mengkonfigurasi audit detail
configure_detailed_audit() {
    configure_detailed_pgaudit
    create_custom_audit_table
    create_custom_audit_trigger
    echo "Konfigurasi audit detail telah selesai."
}

# Fungsi untuk memeriksa log audit
check_audit_logs() {
    echo "Memeriksa log audit..."
    sudo tail -n 50 /var/log/postgresql/postgresql-$PG_VERSION-main.log
    echo "Selesai memeriksa log audit."
}

# Fungsi untuk memeriksa entri audit custom
check_custom_audit_entries() {
    echo "Memeriksa entri audit custom..."
    sudo -u postgres psql -c "SELECT * FROM public.custom_audit_log ORDER BY timestamp DESC LIMIT 10;"
    echo "Selesai memeriksa entri audit custom."
}

# Fungsi untuk mengkonfigurasi pgAudit untuk semua database
configure_pgaudit_all_databases() {
    echo "Mengkonfigurasi pgAudit untuk semua database..."

    # Pastikan pgAudit dimuat
    if ! ensure_pgaudit_loaded; then
        echo "Gagal memuat pgAudit. Konfigurasi audit tidak dapat dilanjutkan."
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
    sudo systemctl restart postgresql

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