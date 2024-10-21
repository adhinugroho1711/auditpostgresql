#!/bin/bash

# Dapatkan direktori script saat ini
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Pindah ke direktori script
cd "$SCRIPT_DIR"

# Impor konfigurasi global
source ./config.sh

# Impor modul-modul menggunakan path relatif
source ./utils.sh
source ./installation.sh
source ./audit.sh
source ./database.sh

# Fungsi untuk menampilkan banner
show_banner() {
    echo "================================================="
    echo "  PostgreSQL Setup dan Manajemen Database"
    echo "  Version: $PG_VERSION"
    echo "================================================="
}

# Menu utama
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
7. Backup Database
8. Restore Database
9. Keluar
"
    read -p "Pilih opsi (1-9): " choice

    case $choice in
        1) install_postgresql_and_pgaudit && configure_remote_access ;;
        2) configure_detailed_audit ;;
        3) create_new_database ;;
        4) change_postgres_password ;;
        5) check_audit_logs ;;
        6) check_custom_audit_entries ;;
        7) backup_database ;;
        8) restore_database ;;
        9) echo "Terima kasih telah menggunakan script ini."; exit 0 ;;
        *) echo "Pilihan tidak valid. Silakan coba lagi." ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done