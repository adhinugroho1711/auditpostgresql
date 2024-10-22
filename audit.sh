#!/bin/bash

# Fungsi untuk memeriksa instalasi PostgreSQL
check_postgresql_installation() {
    if ! command -v psql &> /dev/null; then
        echo "PostgreSQL belum terinstal. Silakan instal PostgreSQL terlebih dahulu."
        echo "Anda dapat menggunakan opsi 1 di menu utama untuk menginstal PostgreSQL."
        return 1
    fi
    return 0
}

# Fungsi untuk memeriksa dan menginstal pgAudit
check_and_install_pgaudit() {
    echo "Memeriksa instalasi pgAudit..."
    
    # Periksa apakah package pgaudit tersedia
    if ! apt-cache show postgresql-$PG_VERSION-pgaudit &> /dev/null; then
        echo "Package postgresql-$PG_VERSION-pgaudit tidak ditemukan."
        read -p "Apakah Anda ingin menginstal pgAudit sekarang? (y/n): " install_choice
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            echo "Menginstal pgAudit..."
            sudo apt-get update
            sudo apt-get install -y postgresql-$PG_VERSION-pgaudit
            if [ $? -ne 0 ]; then
                echo "Gagal menginstal pgAudit. Mencoba metode alternatif..."
                sudo apt-get install -y postgresql-server-dev-$PG_VERSION build-essential git
                git clone https://github.com/pgaudit/pgaudit.git
                cd pgaudit
                git checkout REL_${PG_VERSION}_STABLE
                make USE_PGXS=1
                sudo make USE_PGXS=1 install
                cd ..
                rm -rf pgaudit
            fi
        else
            echo "pgAudit diperlukan untuk fungsi audit. Instalasi dibatalkan."
            return 1
        fi
    fi
    return 0
}

# Fungsi untuk mengkonfigurasi audit detail
configure_detailed_audit() {
    echo "Mengkonfigurasi audit detail..."

    # Periksa instalasi PostgreSQL
    if ! check_postgresql_installation; then
        return 1
    fi

    # Periksa dan instal pgAudit jika diperlukan
    if ! check_and_install_pgaudit; then
        return 1
    fi

    echo "Mengkonfigurasi PostgreSQL untuk pgAudit..."
    
    # Update postgresql.conf
    PGCONF="$PG_CONFIG_DIR/postgresql.conf"
    if [ ! -f "$PGCONF" ]; then
        echo "Error: File konfigurasi PostgreSQL tidak ditemukan di $PGCONF"
        return 1
    fi

    # Backup konfigurasi
    sudo cp "$PGCONF" "${PGCONF}.backup"
    
    # Update shared_preload_libraries
    if ! sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
        echo "Menambahkan pgaudit ke shared_preload_libraries..."
        if sudo grep -q "^shared_preload_libraries" "$PGCONF"; then
            sudo sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1,pgaudit'/" "$PGCONF"
        else
            echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
        fi
    fi

    # Restart PostgreSQL untuk menerapkan perubahan
    echo "Merestart PostgreSQL untuk menerapkan perubahan..."
    if ! sudo systemctl restart postgresql; then
        echo "Gagal merestart PostgreSQL. Mengembalikan konfigurasi..."
        sudo mv "${PGCONF}.backup" "$PGCONF"
        return 1
    fi

    # Tunggu beberapa detik untuk PostgreSQL startup
    sleep 5

    # Konfigurasi pgAudit
    echo "Mengkonfigurasi pengaturan pgAudit..."
    sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS pgaudit;" postgres
    
    # Konfigurasi audit settings
    configure_pgaudit_settings

    # Buat tabel dan trigger audit custom
    create_custom_audit_table
    create_custom_audit_trigger

    echo "Konfigurasi audit detail selesai."
    echo "pgAudit telah dikonfigurasi dan diaktifkan."
}

# Fungsi untuk mengkonfigurasi pengaturan pgAudit
configure_pgaudit_settings() {
    echo "Mengkonfigurasi pengaturan pgAudit..."

    # Jalankan perintah konfigurasi sebagai user postgres
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log = 'all';"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_catalog = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_parameter = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_statement_once = off;"
    sudo -u postgres psql -c "ALTER SYSTEM SET pgaudit.log_level = 'log';"
    
    # Konfigurasi logging tambahan
    sudo -u postgres psql -c "ALTER SYSTEM SET log_connections = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_disconnections = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_duration = on;"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_line_prefix = '%m [%p] [%r] %q%u@%d from %h ';"
    sudo -u postgres psql -c "ALTER SYSTEM SET log_statement = 'all';"
    
    # Reload konfigurasi
    sudo -u postgres psql -c "SELECT pg_reload_conf();"
}

# ... (sisanya fungsi tetap sama seperti sebelumnya)