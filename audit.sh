#!/bin/bash

# Fungsi untuk mengkonfigurasi audit detail
configure_detailed_audit() {
    echo "Mengkonfigurasi audit detail..."

    if ! ensure_pgaudit_loaded; then
        echo "Gagal memuat pgAudit. Konfigurasi audit tidak dapat dilanjutkan."
        return 1
    fi

    # Konfigurasi pgAudit
    configure_pgaudit

    # Buat tabel dan trigger audit custom
    create_custom_audit_table
    create_custom_audit_trigger

    echo "Konfigurasi audit detail selesai."
}

# Fungsi untuk mengkonfigurasi pgAudit
configure_pgaudit() {
    echo "Mengkonfigurasi pgAudit..."

    # Konfigurasi global pgAudit
    run_psql "ALTER SYSTEM SET pgaudit.log = 'all';"
    run_psql "ALTER SYSTEM SET pgaudit.log_catalog = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_parameter = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_statement_once = off;"
    run_psql "ALTER SYSTEM SET pgaudit.log_level = log;"
    
    # Konfigurasi untuk merekam detail tambahan
    run_psql "ALTER SYSTEM SET log_connections = on;"
    run_psql "ALTER SYSTEM SET log_disconnections = on;"
    run_psql "ALTER SYSTEM SET log_duration = on;"
    run_psql "ALTER SYSTEM SET log_line_prefix = '%m [%p] [%r] %q%u@%d from %h ';"
    run_psql "ALTER SYSTEM SET log_statement = 'all';"
    
    # Konfigurasi untuk merekam query sebelum dan sesudah
    run_psql "ALTER SYSTEM SET track_activities = on;"
    run_psql "ALTER SYSTEM SET track_activity_query_size = 2048;"  # Increase if needed

    restart_postgresql

    echo "Konfigurasi pgAudit selesai."
}

# Fungsi untuk membuat tabel audit custom
create_custom_audit_table() {
    echo "Membuat tabel audit custom..."
    
    run_psql "
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
    
    run_psql "
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

# Fungsi untuk memeriksa log audit
check_audit_logs() {
    echo "Memeriksa log audit..."
    sudo tail -n 50 "$PG_LOG_DIR/postgresql-$PG_VERSION-main.log"
    echo "Selesai memeriksa log audit."
}

# Fungsi untuk memeriksa entri audit custom
check_custom_audit_entries() {
    echo "Memeriksa entri audit custom..."
    run_psql "SELECT * FROM public.custom_audit_log ORDER BY timestamp DESC LIMIT 10;"
    echo "Selesai memeriksa entri audit custom."
}

# Fungsi untuk mengaktifkan audit pada database tertentu
enable_database_audit() {
    echo "Mengaktifkan audit pada database tertentu..."
    read -p "Masukkan nama database: " db_name

    if run_psql "\l" | grep -qw $db_name; then
        PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $db_name -c "CREATE EXTENSION IF NOT EXISTS pgaudit;"
        echo "Audit telah diaktifkan untuk database '$db_name'."
    else
        echo "Database '$db_name' tidak ditemukan."
    fi
}

# Fungsi utama untuk setup audit
setup_audit() {
    configure_detailed_audit
    enable_database_audit
    
    echo "Setup audit selesai."
}