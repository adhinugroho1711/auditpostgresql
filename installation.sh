#!/bin/bash

# Fungsi untuk memeriksa dan menginstal PostgreSQL
check_and_install_postgresql() {
    if ! command -v psql &> /dev/null; then
        echo "PostgreSQL tidak terinstal. Menginstal PostgreSQL..."
        sudo apt-get update
        sudo apt-get install -y postgresql postgresql-contrib
        if [ $? -ne 0 ]; then
            error_exit "Gagal menginstal PostgreSQL. Silakan instal secara manual dan jalankan script ini kembali."
        fi
        echo "PostgreSQL berhasil diinstal."
    else
        echo "PostgreSQL sudah terinstal."
    fi
}

# Fungsi untuk menginstal PostgreSQL dan pgaudit
install_postgresql_and_pgaudit() {
    echo "Menginstal PostgreSQL dan pgaudit..."
    
    check_and_install_postgresql

    # Dapatkan versi PostgreSQL
    PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
    echo "Terdeteksi PostgreSQL versi $PG_VERSION"

    # Install pgaudit extension
    if apt-cache show postgresql-$PG_VERSION-pgaudit &> /dev/null; then
        sudo apt-get install -y postgresql-$PG_VERSION-pgaudit || error_exit "Gagal menginstal pgaudit extension"
    else
        echo "Paket postgresql-$PG_VERSION-pgaudit tidak ditemukan. Mencoba cara alternatif..."
        sudo apt-get install -y postgresql-server-dev-$PG_VERSION build-essential git
        git clone https://github.com/pgaudit/pgaudit.git
        cd pgaudit
        git checkout REL_${PG_VERSION}_STABLE
        make USE_PGXS=1
        sudo make USE_PGXS=1 install
        cd ..
        rm -rf pgaudit
    fi

    # Tambahkan konfigurasi pgaudit ke postgresql.conf
    PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    if sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
        echo "pgaudit sudah terdaftar di shared_preload_libraries"
    elif sudo grep -q "shared_preload_libraries" "$PGCONF"; then
        sudo sed -i "s/shared_preload_libraries = '/shared_preload_libraries = 'pgaudit,/" "$PGCONF"
    else
        echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
    fi

    restart_postgresql

    echo "Instalasi PostgreSQL dan pgaudit selesai."
}