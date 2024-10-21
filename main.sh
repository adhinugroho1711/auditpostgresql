#!/bin/bash

# Impor modul-modul
source ./utils.sh
source ./user_management.sh
source ./installation.sh
source ./monitoring.sh
source ./remote_access.sh
source ./library_database.sh

# Konfigurasi default
PG_USER="postgres"
PG_PASSWORD=""
PG_DB="postgres"
PG_HOST="localhost"
PG_PORT="5432"

# Menu utama
while true; do
    clear
    echo "
PostgreSQL Monitoring dan Database Perpustakaan Setup
=====================================================
1. Atur Kredensial PostgreSQL
2. Instal PostgreSQL dan pgaudit
3. Konfigurasi Monitoring
4. Setup Akses Remote
5. Buat Database Perpustakaan
6. Keluar
"
    read -p "Pilih opsi (1-6): " choice

    case $choice in
        1) set_credentials ;;
        2) install_postgresql_and_pgaudit ;;
        3) configure_monitoring ;;
        4) setup_remote_access ;;
        5) setup_library_database ;;
        6) echo "Terima kasih telah menggunakan script ini."; exit 0 ;;
        *) echo "Pilihan tidak valid. Silakan coba lagi." ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done