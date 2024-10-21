#!/bin/bash

# Impor modul-modul
source ./utils.sh
source ./user_management.sh
source ./installation.sh
source ./monitoring.sh
source ./library_database.sh
source ./audit.sh

# Konfigurasi default
PG_USER="postgres"
PG_PASSWORD=""
PG_DB="postgres"
PG_HOST="localhost"
PG_PORT="5432"

# Fungsi untuk menampilkan banner
show_banner() {
    echo "================================================="
    echo "  PostgreSQL Setup dan Manajemen Database"
    echo "================================================="
}

# Menu utama
while true; do
    clear
    show_banner
    echo "
1. Instal dan Konfigurasi PostgreSQL
2. Manajemen Pengguna dan Kredensial
3. Konfigurasi Monitoring dan Audit
4. Setup Database Perpustakaan
5. Periksa Status PostgreSQL
6. Keluar
"
    read -p "Pilih opsi (1-6): " choice

    case $choice in
        1)
            install_postgresql_and_pgaudit
            configure_monitoring
            ;;
        2)
            set_credentials
            ;;
        3)
            configure_monitoring
            manage_audit
            ;;
        4)
            setup_library_database
            ;;
        5)
            check_postgresql_status  # Fungsi ini perlu ditambahkan di utils.sh
            ;;
        6)
            echo "Terima kasih telah menggunakan script ini."
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid. Silakan coba lagi."
            ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done