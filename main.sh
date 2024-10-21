#!/bin/bash

# Dapatkan direktori script saat ini
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Impor modul-modul menggunakan path absolut
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/installation.sh"
source "$SCRIPT_DIR/audit.sh"
source "$SCRIPT_DIR/database.sh"

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

# Menu utama
while true; do
    clear
    show_banner
    echo "
1. Instal dan Konfigurasi PostgreSQL
2. Konfigurasi Audit
3. Buat Database Baru
4. Ubah Password PostgreSQL
5. Keluar
"
    read -p "Pilih opsi (1-5): " choice

    case $choice in
        1)
            install_postgresql_and_pgaudit
            configure_remote_access
            ;;
        2)
            configure_pgaudit_all_databases
            create_audit_trigger_function
            ;;
        3)
            create_new_database
            ;;
        4)
            change_postgres_password
            ;;
        5)
            echo "Terima kasih telah menggunakan script ini."
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid. Silakan coba lagi."
            ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done