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
    local default_password="postgres123"  # Anda bisa mengubah ini sesuai kebutuhan
    echo "Mengatur password default untuk user PostgreSQL..."
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$default_password';"
    echo "Password default telah diatur untuk user postgres."
    echo "PERINGATAN: Pastikan untuk mengubah password ini segera setelah instalasi."
}

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
    if ! sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
        echo "Menambahkan pgaudit ke shared_preload_libraries..."
        if sudo grep -q "shared_preload_libraries" "$PGCONF"; then
            sudo sed -i "s/shared_preload_libraries = '/shared_preload_libraries = 'pgaudit,/" "$PGCONF"
        else
            echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
        fi
    else
        echo "pgaudit sudah terdaftar di shared_preload_libraries"
    fi

    echo "Me-restart PostgreSQL untuk menerapkan perubahan..."
    sudo systemctl restart postgresql

    # Atur password default
    set_default_postgres_password

    echo "Instalasi PostgreSQL $PG_VERSION dan pgaudit selesai."
    echo "PERINGATAN: Password default telah diatur. Pastikan untuk mengubahnya segera."
}

configure_remote_access() {
    echo "Mengonfigurasi akses remote untuk PostgreSQL..."

    PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    PGHBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PGCONF
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a $PGHBA
    sudo ufw allow 5432/tcp

    echo "Me-restart PostgreSQL untuk menerapkan perubahan..."
    sudo systemctl restart postgresql

    echo "Akses remote telah dikonfigurasi."
}