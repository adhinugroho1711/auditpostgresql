#!/bin/bash

# Fungsi untuk memeriksa dan menginstal PostgreSQL
check_and_install_postgresql() {
    if ! command -v psql &> /dev/null; then
        echo "PostgreSQL tidak terinstal. Menginstal PostgreSQL $PG_VERSION..."
        sudo apt-get update
        sudo apt-get install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION
        if [ $? -ne 0 ]; then
            error_exit "Gagal menginstal PostgreSQL. Silakan instal secara manual dan jalankan script ini kembali."
        fi
        echo "PostgreSQL $PG_VERSION berhasil diinstal."
    else
        echo "PostgreSQL sudah terinstal."
    fi
}

# Fungsi untuk mengonfigurasi akses remote
configure_remote_access() {
    echo "Mengonfigurasi akses remote untuk PostgreSQL..."

    PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PGHBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PGCONF
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a $PGHBA
    sudo ufw allow 5432/tcp

    restart_postgresql

    echo "Akses remote telah dikonfigurasi."
}

# Fungsi untuk menginstal PostgreSQL dan pgaudit
install_postgresql_and_pgaudit() {
    echo "Menginstal PostgreSQL $PG_VERSION dan pgaudit..."
    
    check_and_install_postgresql

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

    PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    if sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
        echo "pgaudit sudah terdaftar di shared_preload_libraries"
    elif sudo grep -q "shared_preload_libraries" "$PGCONF"; then
        sudo sed -i "s/shared_preload_libraries = '/shared_preload_libraries = 'pgaudit,/" "$PGCONF"
    else
        echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
    fi

    restart_postgresql

    echo "Instalasi PostgreSQL $PG_VERSION dan pgaudit selesai."
    echo "PERINGATAN: Akses remote telah diaktifkan. Pastikan untuk mengamankan server Anda dan hanya mengizinkan koneksi dari alamat IP yang dipercaya."
}