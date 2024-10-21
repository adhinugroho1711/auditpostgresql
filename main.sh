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
1. Instal PostgreSQL dan pgAudit
2. Konfigurasi Akses Remote PostgreSQL
3. Verifikasi Koneksi PostgreSQL
4. Konfigurasi Audit Detail
5. Buat Database Baru
6. Ubah Password PostgreSQL
7. Periksa Log Audit
8. Periksa Entri Audit Custom
9. Backup Database
10. Restore Database
11. Operasi CRUD
12. Keluar
"
    read -p "Pilih opsi (1-12): " choice

    case $choice in
        1) install_postgresql_and_pgaudit ;;
        2) configure_remote_access ;;
        3) verify_postgres_connection ;;
        4) configure_detailed_audit ;;
        5) create_new_database ;;
        6) change_postgres_password ;;
        7) check_audit_logs ;;
        8) check_custom_audit_entries ;;
        9) backup_database ;;
        10) restore_database ;;
        11) manage_crud_operations ;;
        12) echo "Terima kasih telah menggunakan script ini."; exit 0 ;;
        *) echo "Pilihan tidak valid. Silakan coba lagi." ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done