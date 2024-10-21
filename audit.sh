#!/bin/bash

# Fungsi untuk mengkonfigurasi pgAudit
configure_pgaudit() {
    echo "Mengkonfigurasi pgAudit..."

    # Pastikan pgAudit sudah diinstal
    if ! psql -U postgres -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'pgaudit';" | grep -q 1; then
        error_exit "pgAudit extension tidak ditemukan. Pastikan sudah diinstal."
    fi

    # Aktifkan pgAudit extension
    run_psql "CREATE EXTENSION IF NOT EXISTS pgaudit;"

    # Konfigurasi pgAudit
    run_psql "ALTER SYSTEM SET pgaudit.log = 'write, function, role, ddl';"
    run_psql "ALTER SYSTEM SET pgaudit.log_catalog = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_parameter = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_statement_once = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_level = log;"

    # Konfigurasi tambahan untuk logging
    run_psql "ALTER SYSTEM SET log_connections = on;"
    run_psql "ALTER SYSTEM SET log_disconnections = on;"
    run_psql "ALTER SYSTEM SET log_duration = on;"
    run_psql "ALTER SYSTEM SET log_line_prefix = '%m [%p] %q%u@%d ';"

    restart_postgresql

    echo "Konfigurasi pgAudit selesai."
}

# Fungsi untuk mengaktifkan audit pada tabel tertentu
enable_table_audit() {
    local table_name=$1
    local schema_name=${2:-public}

    echo "Mengaktifkan audit pada tabel $schema_name.$table_name..."

    run_psql "
    CREATE TRIGGER ${table_name}_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON ${schema_name}.${table_name}
    FOR EACH ROW EXECUTE FUNCTION pgaudit.fn_audit_event();
    "

    echo "Audit telah diaktifkan pada tabel $schema_name.$table_name."
}

# Fungsi untuk memeriksa log audit
check_audit_logs() {
    echo "Memeriksa log audit..."

    # Ambil 10 entri terakhir dari log PostgreSQL
    sudo tail -n 10 /var/log/postgresql/postgresql-*.log

    echo "Selesai memeriksa log audit."
}

# Fungsi utama untuk mengelola audit
manage_audit() {
    while true; do
        echo "
Manajemen Audit PostgreSQL
==========================
1. Konfigurasi pgAudit
2. Aktifkan audit pada tabel
3. Periksa log audit
4. Kembali ke menu utama
"
        read -p "Pilih opsi (1-4): " audit_choice

        case $audit_choice in
            1) configure_pgaudit ;;
            2)
                read -p "Masukkan nama tabel: " table_name
                read -p "Masukkan nama schema (default: public): " schema_name
                schema_name=${schema_name:-public}
                enable_table_audit "$table_name" "$schema_name"
                ;;
            3) check_audit_logs ;;
            4) break ;;
            *) echo "Pilihan tidak valid. Silakan coba lagi." ;;
        esac

        read -p "Tekan Enter untuk melanjutkan..."
    done
}