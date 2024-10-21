#!/bin/bash

# Dapatkan direktori script saat ini
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Pindah ke direktori script
cd "$SCRIPT_DIR"

# Fungsi untuk memuat file
load_file() {
    if [ -f "$1" ]; then
        source "$1"
    else
        echo "Error: File $1 tidak ditemukan."
        exit 1
    fi
}

# Impor konfigurasi global dan modul-modul
load_file "./config.sh"
load_file "./utils.sh"
load_file "./installation.sh"
load_file "./audit.sh"
load_file "./database.sh"

# Fungsi untuk menampilkan banner
show_banner() {
    echo "================================================="
    echo "  PostgreSQL Setup dan Manajemen Database"
    echo "  Version: $PG_VERSION"
    echo "================================================="
}

# Fungsi untuk memeriksa apakah fungsi ada
function_exists() {
    declare -f -F $1 > /dev/null
    return $?
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
        1) 
            if function_exists install_postgresql_and_pgaudit; then
                install_postgresql_and_pgaudit
            else
                echo "Error: Fungsi install_postgresql_and_pgaudit tidak ditemukan."
            fi
            ;;
        2)
            if function_exists configure_remote_access; then
                configure_remote_access
            else
                echo "Error: Fungsi configure_remote_access tidak ditemukan."
            fi
            ;;
        3)
            if function_exists verify_postgres_connection; then
                verify_postgres_connection
            else
                echo "Error: Fungsi verify_postgres_connection tidak ditemukan."
            fi
            ;;
        4)
            if function_exists configure_detailed_audit; then
                configure_detailed_audit
            else
                echo "Error: Fungsi configure_detailed_audit tidak ditemukan."
            fi
            ;;
        5)
            if function_exists create_new_database; then
                create_new_database
            else
                echo "Error: Fungsi create_new_database tidak ditemukan."
            fi
            ;;
        6)
            if function_exists change_postgres_password; then
                change_postgres_password
            else
                echo "Error: Fungsi change_postgres_password tidak ditemukan."
            fi
            ;;
        7)
            if function_exists check_audit_logs; then
                check_audit_logs
            else
                echo "Error: Fungsi check_audit_logs tidak ditemukan."
            fi
            ;;
        8)
            if function_exists check_custom_audit_entries; then
                check_custom_audit_entries
            else
                echo "Error: Fungsi check_custom_audit_entries tidak ditemukan."
            fi
            ;;
        9)
            if function_exists backup_database; then
                backup_database
            else
                echo "Error: Fungsi backup_database tidak ditemukan."
            fi
            ;;
        10)
            if function_exists restore_database; then
                restore_database
            else
                echo "Error: Fungsi restore_database tidak ditemukan."
            fi
            ;;
        11)
            if function_exists manage_crud_operations; then
                manage_crud_operations
            else
                echo "Error: Fungsi manage_crud_operations tidak ditemukan."
            fi
            ;;
        12) echo "Terima kasih telah menggunakan script ini."; exit 0 ;;
        *) echo "Pilihan tidak valid. Silakan coba lagi." ;;
    esac

    read -p "Tekan Enter untuk melanjutkan..."
done