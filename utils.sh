#!/bin/bash

# Fungsi untuk menampilkan pesan error dan keluar
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Fungsi untuk menjalankan perintah SQL
run_psql() {
    sudo -u postgres psql -c "$1"
}

# Fungsi untuk restart PostgreSQL
restart_postgresql() {
    echo "Merestart PostgreSQL..."
    sudo systemctl restart postgresql || error_exit "Gagal merestart PostgreSQL service"
    echo "PostgreSQL telah direstart."
}

# Fungsi untuk memverifikasi koneksi PostgreSQL
verify_postgres_connection() {
    echo "Memverifikasi koneksi PostgreSQL..."
    if PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -c '\q' 2>/dev/null; then
        echo "Koneksi berhasil."
        return 0
    else
        echo "Koneksi gagal. Mohon periksa kredensial Anda."
        return 1
    fi
}