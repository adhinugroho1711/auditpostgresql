#!/bin/bash

# Fungsi untuk mengatur akses remote
setup_remote_access() {
    echo "Mengatur akses remote untuk PostgreSQL..."

    PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/$PG_VERSION/main/pg_hba.conf

    # Buka port PostgreSQL di firewall
    sudo ufw allow 5432/tcp

    restart_postgresql

    echo "Pengaturan akses remote selesai. PostgreSQL sekarang dapat diakses dari alamat IP eksternal."
    echo "PERINGATAN: Pastikan untuk mengamankan server Anda dan hanya mengizinkan koneksi dari alamat IP yang dipercaya."
}