#!/bin/bash

# Fungsi untuk membuat database baru
create_new_database() {
    echo "Membuat database baru..."

    if ! ensure_pgaudit_loaded; then
        echo "Peringatan: PgAudit tidak dapat dimuat. Pembuatan database akan dilanjutkan tanpa audit."
    fi

    read -p "Masukkan nama database baru: " db_name

    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw $db_name; then
        echo "Database '$db_name' sudah ada."
    else
        if sudo -u postgres createdb $db_name; then
            echo "Database '$db_name' berhasil dibuat."
            
            # Aktifkan pgAudit untuk database baru
            sudo -u postgres psql -d $db_name -c "CREATE EXTENSION IF NOT EXISTS pgaudit;"
            echo "Audit telah diaktifkan untuk database '$db_name'."

            # Tanyakan apakah user ingin membuat tabel
            read -p "Apakah Anda ingin membuat tabel baru di database ini? (y/n): " create_table
            if [[ $create_table =~ ^[Yy]$ ]]; then
                create_new_table "$db_name"
            fi
        else
            echo "Gagal membuat database '$db_name'."
        fi
    fi
}

# ... (fungsi-fungsi lain tetap sama)

# Fungsi untuk membuat tabel baru
create_new_table() {
    local db_name=$1
    echo "Membuat tabel baru di database '$db_name'..."
    read -p "Masukkan nama tabel baru: " table_name

    # Membuat tabel sederhana sebagai contoh
    sudo -u postgres psql -d "$db_name" -c "
    CREATE TABLE $table_name (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"

    if [ $? -eq 0 ]; then
        echo "Tabel '$table_name' berhasil dibuat di database '$db_name'."
    else
        echo "Gagal membuat tabel '$table_name' di database '$db_name'."
    fi
}