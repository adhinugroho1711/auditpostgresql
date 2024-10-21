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

# Fungsi untuk mengatur password default PostgreSQL
set_default_postgres_password() {
    echo "Mengatur password default untuk user PostgreSQL..."
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';"
    echo "Password default telah diatur untuk user postgres."
    echo "PERINGATAN: Pastikan untuk mengubah password ini segera setelah instalasi."
}

install_postgresql_and_pgaudit() {
    echo "Memeriksa instalasi PostgreSQL..."
    
    if command -v psql &> /dev/null; then
        echo "PostgreSQL sudah terinstal."
        read -p "Apakah Anda ingin menginstal ulang? (y/n): " reinstall
        if [[ $reinstall =~ ^[Yy]$ ]]; then
            sudo apt-get remove --purge postgresql*
        else
            return
        fi
    fi

    echo "Menginstal PostgreSQL $PG_VERSION dan pgaudit..."
    
    sudo apt-get update
    sudo apt-get install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION

    if [ $? -ne 0 ]; then
        echo "Gagal menginstal PostgreSQL. Silakan periksa koneksi internet Anda dan coba lagi."
        return 1
    fi

    echo "PostgreSQL $PG_VERSION berhasil diinstal."

    # Install pgAudit
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

    ensure_pgaudit_loaded

    # Atur password default
    set_default_postgres_password

    echo "Instalasi PostgreSQL $PG_VERSION dan pgaudit selesai."
    echo "PERINGATAN: Password default telah diatur. Pastikan untuk mengubahnya segera."
}


configure_remote_access() {
    echo "Mengonfigurasi akses remote untuk PostgreSQL..."

    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONFIG_DIR/postgresql.conf"
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a "$PG_CONFIG_DIR/pg_hba.conf"
    sudo ufw allow $PG_PORT/tcp

    restart_postgresql

    echo "Akses remote telah dikonfigurasi."
}