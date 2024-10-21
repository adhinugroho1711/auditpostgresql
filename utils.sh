#!/bin/bash

# Fungsi untuk menampilkan pesan error dan keluar
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Fungsi untuk menjalankan perintah SQL
run_psql() {
    sudo -u postgres psql -c "$1"
}

# Fungsi untuk restart PostgreSQL
restart_postgresql() {
    echo "Merestart PostgreSQL..."
    sudo systemctl restart postgresql || error_exit "Gagal merestart PostgreSQL service"
    echo "PostgreSQL telah direstart."
}

# Fungsi untuk memverifikasi koneksi PostgreSQL
verify_postgres_connection() {
    echo "Memverifikasi koneksi PostgreSQL..."
    if PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -c '\q' 2>/dev/null; then
        echo "Koneksi berhasil."
        return 0
    else
        echo "Koneksi gagal. Mohon periksa kredensial Anda."
        return 1
    fi
}

# Fungsi untuk memeriksa status PostgreSQL
check_postgresql_status() {
    echo "Memeriksa status PostgreSQL $PG_VERSION..."
    if sudo systemctl is-active --quiet postgresql; then
        echo "PostgreSQL $PG_VERSION sedang berjalan."
        sudo systemctl status postgresql | grep Active
    else
        echo "PostgreSQL $PG_VERSION tidak berjalan."
        echo "Mencoba menjalankan PostgreSQL $PG_VERSION..."
        sudo systemctl start postgresql
        if sudo systemctl is-active --quiet postgresql; then
            echo "PostgreSQL $PG_VERSION berhasil dijalankan."
        else
            echo "Gagal menjalankan PostgreSQL $PG_VERSION. Silakan periksa log sistem untuk informasi lebih lanjut."
        fi
    fi
}

ensure_pgaudit_loaded() {
    echo "Memeriksa status PgAudit..."
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'pgaudit' AND installed_version IS NOT NULL;" | grep -q 1; then
        echo "PgAudit belum dimuat. Mencoba memuat PgAudit..."
        
        PGCONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
        if ! sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
            echo "Menambahkan pgaudit ke shared_preload_libraries..."
            if sudo grep -q "shared_preload_libraries" "$PGCONF"; then
                sudo sed -i "s/shared_preload_libraries = '/shared_preload_libraries = 'pgaudit,/" "$PGCONF"
            else
                echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
            fi
        fi
        
        echo "Me-restart PostgreSQL untuk menerapkan perubahan..."
        sudo systemctl restart postgresql
        
        # Tunggu sebentar agar PostgreSQL memiliki waktu untuk restart
        sleep 5
        
        # Periksa lagi apakah PgAudit sudah dimuat
        if sudo -u postgres psql -tAc "SELECT 1 FROM pg_available_extensions WHERE name = 'pgaudit' AND installed_version IS NOT NULL;" | grep -q 1; then
            echo "PgAudit berhasil dimuat."
        else
            echo "Gagal memuat PgAudit. Silakan periksa konfigurasi PostgreSQL Anda."
            return 1
        fi
    else
        echo "PgAudit sudah dimuat."
    fi
    return 0
}

change_postgres_password() {
    echo "Mengubah password untuk user PostgreSQL..."
    read -s -p "Masukkan password baru untuk user postgres: " new_password
    echo
    read -s -p "Konfirmasi password baru: " confirm_password
    echo

    if [ "$new_password" != "$confirm_password" ]; then
        echo "Password tidak cocok. Silakan coba lagi."
        return 1
    fi

    if sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$new_password';" ; then
        echo "Password berhasil diubah."
        # Update variabel global PG_PASSWORD
        PG_PASSWORD=$new_password
    else
        echo "Gagal mengubah password. Silakan coba lagi."
        return 1
    fi
}
