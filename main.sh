#!/bin/bash

# Dapatkan direktori script saat ini
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Pindah ke direktori script
cd "$SCRIPT_DIR"

# Impor modul-modul menggunakan path relatif
source ./utils.sh
source ./installation.sh
source ./audit.sh
source ./database.sh

# Konfigurasi default
PG_VERSION="14"
PG_USER="postgres"
PG_PASSWORD="postgres123"  # Password default
PG_DB="postgres"
PG_HOST="localhost"
PG_PORT="5432"


# Fungsi untuk menampilkan banner
show_banner() {
    echo "================================================="
    echo "  PostgreSQL Setup dan Manajemen Database"
    echo "================================================="
}

while true; do
    clear
    show_banner
    echo "
1. Instal dan Konfigurasi PostgreSQL
2. Konfigurasi Audit Detail
3. Buat Database Baru
4. Ubah Password PostgreSQL
5. Periksa Log Audit
6. Periksa Entri Audit Custom
7. Keluar
"
    read -p "Pilih opsi (1-7): " choice

    case $choice in
        1)
            install_postgresql_and_pgaudit
            configure_remote_access
            ;;
        2)
            configure_detailed_audit
            ;;
        3)
            create_new_database
            ;;
        4)
            change_postgres_password
            ;;
        5)
            check_audit_logs
            ;;
        6)
            check_custom_audit_entries
            ;;
        7)
            echo "Terima kasih telah menggunakan script ini."
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid. Silakan coba lagi."
            ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done