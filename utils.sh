#!/bin/bash

# Fungsi untuk menampilkan pesan error dan keluar
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Fungsi untuk menjalankan perintah SQL
run_psql() {
    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DB -c "$1"
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
    
    if [ "$PGAUDIT_ENABLED" != "true" ]; then
        echo "PgAudit tidak diaktifkan dalam konfigurasi."
        return 1
    fi
    
    PGCONF="$PG_CONFIG_DIR/postgresql.conf"
    
    if ! sudo grep -q "shared_preload_libraries.*pgaudit" "$PGCONF"; then
        echo "PgAudit belum dimuat. Mencoba mengaktifkan PgAudit..."
        
        sudo cp "$PGCONF" "${PGCONF}.bak"
        
        if sudo grep -q "shared_preload_libraries" "$PGCONF"; then
            sudo sed -i "s/shared_preload_libraries = '/shared_preload_libraries = 'pgaudit,/" "$PGCONF"
        else
            echo "shared_preload_libraries = 'pgaudit'" | sudo tee -a "$PGCONF"
        fi
        
        restart_postgresql
    fi
    
    if run_psql "SELECT 1 FROM pg_available_extensions WHERE name = 'pgaudit' AND installed_version IS NOT NULL;" | grep -q 1; then
        echo "PgAudit berhasil dimuat."
        return 0
    else
        echo "Gagal memuat PgAudit. Silakan periksa log PostgreSQL untuk informasi lebih lanjut."
        return 1
    fi
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

    if run_psql "ALTER USER postgres WITH PASSWORD '$new_password';" ; then
        echo "Password berhasil diubah."
        PG_PASSWORD=$new_password
        # Update config file
        sed -i "s/PG_PASSWORD=.*/PG_PASSWORD=\"$new_password\"/" ./config.sh
    else
        echo "Gagal mengubah password. Silakan coba lagi."
        return 1
    fi
}

backup_database() {
    echo "Melakukan backup database..."
    read -p "Masukkan nama database yang akan di-backup: " db_name
    backup_file="$BACKUP_DIR/${db_name}_$(date +%Y%m%d_%H%M%S).sql"
    
    if ! [ -d "$BACKUP_DIR" ]; then
        sudo mkdir -p "$BACKUP_DIR"
    fi

    if PGPASSWORD=$PG_PASSWORD pg_dump -h $PG_HOST -p $PG_PORT -U $PG_USER -d $db_name > "$backup_file"; then
        echo "Backup berhasil disimpan di $backup_file"
    else
        echo "Gagal melakukan backup database $db_name"
    fi
}

restore_database() {
    echo "Melakukan restore database..."
    read -p "Masukkan path file backup: " backup_file
    read -p "Masukkan nama database tujuan (baru atau yang sudah ada): " db_name

    if ! run_psql "\l" | grep -qw $db_name; then
        if ! run_psql "CREATE DATABASE $db_name;"; then
            echo "Gagal membuat database $db_name"
            return 1
        fi
    fi

    if PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $db_name < "$backup_file"; then
        echo "Database berhasil di-restore ke $db_name"
    else
        echo "Gagal melakukan restore ke database $db_name"
    fi
}