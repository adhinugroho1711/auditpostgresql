#!/bin/bash

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

    echo "Instalasi PostgreSQL $PG_VERSION dan pgaudit selesai."
    echo "PERINGATAN: Akses remote telah diaktifkan. Pastikan untuk mengamankan server Anda dan hanya mengizinkan koneksi dari alamat IP yang dipercaya."
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