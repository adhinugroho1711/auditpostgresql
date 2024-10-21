#!/bin/bash

# Fungsi untuk menampilkan pesan error dan keluar
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Cek apakah script dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    error_exit "Script ini harus dijalankan sebagai root"
fi

# Install PostgreSQL jika belum terinstall
if ! command -v psql &> /dev/null; then
    echo "PostgreSQL belum terinstall. Menginstall PostgreSQL..."
    apt-get update || error_exit "Gagal mengupdate package list"
    apt-get install -y postgresql postgresql-contrib || error_exit "Gagal menginstall PostgreSQL"
fi

# Install pgaudit extension
echo "Menginstall pgaudit extension..."
apt-get install -y postgresql-13-pgaudit || error_exit "Gagal menginstall pgaudit extension"

# Restart PostgreSQL service
systemctl restart postgresql || error_exit "Gagal merestart PostgreSQL service"

echo "Instalasi selesai. Silakan jalankan script konfigurasi untuk mengatur monitoring."