#!/bin/bash

# Fungsi untuk membuat database baru
create_new_database() {
    echo "Membuat database baru..."

    if ! ensure_pgaudit_loaded; then
        echo "Peringatan: PgAudit tidak dapat dimuat. Pembuatan database akan dilanjutkan tanpa audit."
    fi

    read -p "Masukkan nama database baru: " db_name

    if run_psql "\l" | grep -qw $db_name; then
        echo "Database '$db_name' sudah ada."
    else
        if run_psql "CREATE DATABASE $db_name;"; then
            echo "Database '$db_name' berhasil dibuat."
            
            # Aktifkan pgAudit untuk database baru
            PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $db_name -c "CREATE EXTENSION IF NOT EXISTS pgaudit;"
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

# Fungsi untuk membuat tabel baru
create_new_table() {
    local db_name=$1
    echo "Membuat tabel baru di database '$db_name'..."
    read -p "Masukkan nama tabel baru: " table_name

    # Membuat tabel sederhana sebagai contoh
    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d "$db_name" -c "
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

# Fungsi untuk menambahkan data baru (Create)
insert_data() {
    local db_name table_name
    read -p "Masukkan nama database: " db_name
    read -p "Masukkan nama tabel: " table_name
    read -p "Masukkan nama untuk data baru: " name

    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d "$db_name" -c "
    INSERT INTO $table_name (name) VALUES ('$name');"

    if [ $? -eq 0 ]; then
        echo "Data berhasil ditambahkan ke tabel '$table_name' di database '$db_name'."
    else
        echo "Gagal menambahkan data ke tabel '$table_name' di database '$db_name'."
    fi
}

# Fungsi untuk membaca data (Read)
read_data() {
    local db_name table_name
    read -p "Masukkan nama database: " db_name
    read -p "Masukkan nama tabel: " table_name

    echo "Data dalam tabel '$table_name':"
    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d "$db_name" -c "
    SELECT * FROM $table_name;"
}

# Fungsi untuk memperbarui data (Update)
update_data() {
    local db_name table_name id new_name
    read -p "Masukkan nama database: " db_name
    read -p "Masukkan nama tabel: " table_name
    read -p "Masukkan ID data yang akan diperbarui: " id
    read -p "Masukkan nama baru: " new_name

    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d "$db_name" -c "
    UPDATE $table_name SET name = '$new_name' WHERE id = $id;"

    if [ $? -eq 0 ]; then
        echo "Data dengan ID $id berhasil diperbarui di tabel '$table_name' di database '$db_name'."
    else
        echo "Gagal memperbarui data di tabel '$table_name' di database '$db_name'."
    fi
}

# Fungsi untuk menghapus data (Delete)
delete_data() {
    local db_name table_name id
    read -p "Masukkan nama database: " db_name
    read -p "Masukkan nama tabel: " table_name
    read -p "Masukkan ID data yang akan dihapus: " id

    PGPASSWORD=$PG_PASSWORD psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d "$db_name" -c "
    DELETE FROM $table_name WHERE id = $id;"

    if [ $? -eq 0 ]; then
        echo "Data dengan ID $id berhasil dihapus dari tabel '$table_name' di database '$db_name'."
    else
        echo "Gagal menghapus data dari tabel '$table_name' di database '$db_name'."
    fi
}

# Fungsi untuk mengelola operasi CRUD
manage_crud_operations() {
    while true; do
        echo "
1. Tambah Data Baru
2. Baca Data
3. Perbarui Data
4. Hapus Data
5. Kembali ke Menu Utama
"
        read -p "Pilih operasi (1-5): " choice

        case $choice in
            1) insert_data ;;
            2) read_data ;;
            3) update_data ;;
            4) delete_data ;;
            5) return ;;
            *) echo "Pilihan tidak valid. Silakan coba lagi." ;;
        esac

        read -p "Tekan Enter untuk melanjutkan..."
    done
}