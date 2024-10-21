#!/bin/bash

# Fungsi untuk mengatur password PostgreSQL
set_postgres_password() {
    echo "Mengatur password untuk user PostgreSQL..."
    read -s -p "Masukkan password baru untuk user '$PG_USER': " new_password
    echo
    if [ "$PG_USER" = "postgres" ]; then
        sudo -u postgres psql -c "ALTER USER $PG_USER WITH PASSWORD '$new_password';"
    else
        sudo -u postgres psql -c "ALTER USER $PG_USER WITH PASSWORD '$new_password';"
    fi
    PG_PASSWORD=$new_password
    echo "Password telah diubah."
}

# Fungsi untuk membuat user baru
create_new_user() {
    echo "Membuat user PostgreSQL baru..."
    read -p "Masukkan nama user baru: " new_user
    read -s -p "Masukkan password untuk user baru: " new_password
    echo

    if [ "$new_user" = "postgres" ]; then
        echo "User 'postgres' sudah ada. Mengubah password untuk user 'postgres'..."
        sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$new_password';"
    else
        sudo -u postgres psql -c "CREATE USER $new_user WITH PASSWORD '$new_password';"
    fi

    if [ $? -eq 0 ]; then
        echo "User '$new_user' telah dibuat atau diperbarui."
        PG_USER=$new_user
        PG_PASSWORD=$new_password
    else
        error_exit "Gagal membuat atau memperbarui user. Mohon periksa kredensial dan hak akses Anda."
    fi
}

# Fungsi untuk mengatur kredensial
set_credentials() {
    echo "Mengatur kredensial PostgreSQL..."
    
    check_and_install_postgresql

    read -p "Apakah Anda ingin membuat user baru? (y/n): " create_new
    if [[ $create_new =~ ^[Yy]$ ]]; then
        create_new_user
    else
        read -p "Masukkan username PostgreSQL (default: postgres): " input_user
        PG_USER=${input_user:-$PG_USER}
        read -s -p "Masukkan password PostgreSQL: " input_password
        echo
        PG_PASSWORD=$input_password
    fi
    
    read -p "Masukkan nama database (default: postgres): " input_db
    PG_DB=${input_db:-$PG_DB}
    read -p "Masukkan host PostgreSQL (default: localhost): " input_host
    PG_HOST=${input_host:-$PG_HOST}
    read -p "Masukkan port PostgreSQL (default: 5432): " input_port
    PG_PORT=${input_port:-$PG_PORT}

    echo "Kredensial telah diatur."
    if ! verify_postgres_connection; then
        echo "Koneksi gagal. Mencoba mengatur ulang password..."
        set_postgres_password
        if ! verify_postgres_connection; then
            error_exit "Gagal terkoneksi ke PostgreSQL setelah mengatur ulang password. Mohon periksa konfigurasi Anda."
        fi
    fi
}