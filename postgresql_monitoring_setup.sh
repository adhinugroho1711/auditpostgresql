#!/bin/bash

# Fungsi untuk menampilkan pesan error dan keluar
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Cek apakah script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    error_exit "Script ini harus dijalankan sebagai root"
fi

# Baca file konfigurasi
CONFIG_FILE="./postgresql_monitoring.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    error_exit "File konfigurasi tidak ditemukan: $CONFIG_FILE"
fi
source "$CONFIG_FILE"

# Fungsi untuk menjalankan perintah SQL
run_psql() {
    su - postgres -c "psql -d $PG_DB -c \"$1\""
}

# Konfigurasi PostgreSQL
echo "Mengkonfigurasi PostgreSQL logging..."
run_psql "ALTER SYSTEM SET log_destination = 'csvlog';"
run_psql "ALTER SYSTEM SET logging_collector = on;"
run_psql "ALTER SYSTEM SET log_directory = '$LOG_DIRECTORY';"
run_psql "ALTER SYSTEM SET log_filename = '$LOG_FILENAME';"
run_psql "ALTER SYSTEM SET log_rotation_age = '$LOG_ROTATION_AGE';"
run_psql "ALTER SYSTEM SET log_rotation_size = $LOG_ROTATION_SIZE;"
run_psql "ALTER SYSTEM SET log_statement = 'all';"
run_psql "ALTER SYSTEM SET log_connections = on;"
run_psql "ALTER SYSTEM SET log_disconnections = on;"
run_psql "ALTER SYSTEM SET log_duration = on;"
run_psql "ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';"

# Konfigurasi pgaudit
echo "Mengkonfigurasi pgaudit..."
run_psql "CREATE EXTENSION IF NOT EXISTS pgaudit;"
run_psql "ALTER SYSTEM SET pgaudit.log = '$AUDIT_LOG';"
run_psql "ALTER SYSTEM SET pgaudit.log_catalog = $AUDIT_LOG_CATALOG;"
run_psql "ALTER SYSTEM SET pgaudit.log_parameter = $AUDIT_LOG_PARAMETER;"
run_psql "ALTER SYSTEM SET pgaudit.log_statement_once = $AUDIT_LOG_STATEMENT_ONCE;"
run_psql "ALTER SYSTEM SET pgaudit.log_level = $AUDIT_LOG_LEVEL;"

# Buat view untuk query log
echo "Membuat view untuk query log..."
run_psql "
CREATE OR REPLACE VIEW $MONITORING_VIEW_NAME AS
SELECT
    log_time,
    user_name,
    database_name,
    process_id,
    connection_from,
    session_id,
    session_line_num,
    command_tag,
    session_start_time,
    virtual_transaction_id,
    transaction_id,
    error_severity,
    sql_state_code,
    message,
    detail,
    hint,
    internal_query,
    internal_query_pos,
    context,
    query,
    query_pos,
    location,
    application_name
FROM pg_csvlog;
"

# Buat fungsi untuk query log terbaru
echo "Membuat fungsi untuk query log terbaru..."
run_psql "
CREATE OR REPLACE FUNCTION $MONITORING_FUNCTION_NAME(
    minutes integer DEFAULT 5
) RETURNS TABLE (
    log_time timestamp with time zone,
    user_name text,
    database_name text,
    connection_from text,
    message text,
    query text
) AS \$\$
BEGIN
    RETURN QUERY
    SELECT
        l.log_time,
        l.user_name,
        l.database_name,
        l.connection_from,
        l.message,
        l.query
    FROM $MONITORING_VIEW_NAME l
    WHERE l.log_time > (current_timestamp - (minutes || ' minutes')::interval)
    ORDER BY l.log_time DESC;
END;
\$\$ LANGUAGE plpgsql;
"

# Konfigurasi untuk remote access
echo "Mengkonfigurasi PostgreSQL untuk remote access..."

# Ubah postgresql.conf untuk menerima koneksi dari semua alamat IP
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/13/main/postgresql.conf

# Tambahkan aturan ke pg_hba.conf untuk mengizinkan koneksi dari semua alamat IP
echo "host    all             all             0.0.0.0/0               md5" >> /etc/postgresql/13/main/pg_hba.conf

# Buka port PostgreSQL di firewall
echo "Membuka port PostgreSQL di firewall..."
ufw allow 5432/tcp

# Restart PostgreSQL untuk menerapkan perubahan
echo "Merestart PostgreSQL..."
systemctl restart postgresql || error_exit "Gagal merestart PostgreSQL service"

echo "Konfigurasi monitoring dan remote access PostgreSQL selesai."
echo "PostgreSQL sekarang dapat diakses dari jarak jauh menggunakan alamat IP server ini."
echo "Anda dapat menggunakan fungsi $MONITORING_FUNCTION_NAME() untuk melihat log terbaru."
echo "Contoh: SELECT * FROM $MONITORING_FUNCTION_NAME(10);"

# Peringatan keamanan
echo "PERINGATAN: Pastikan untuk mengamankan server Anda dan hanya mengizinkan koneksi dari alamat IP yang dipercaya."
echo "Pertimbangkan untuk menggunakan VPN atau SSH tunneling untuk koneksi jarak jauh yang lebih aman."