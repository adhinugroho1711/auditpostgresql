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

# Fungsi untuk menginstal PostgreSQL dan pgaudit
install_postgresql_and_pgaudit() {
    echo "Menginstal PostgreSQL dan pgaudit..."
    
    # Install PostgreSQL jika belum terinstal
    if ! command -v psql &> /dev/null; then
        apt-get update || error_exit "Gagal mengupdate package list"
        apt-get install -y postgresql postgresql-contrib || error_exit "Gagal menginstal PostgreSQL"
    fi

    # Dapatkan versi PostgreSQL
    PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
    echo "Terdeteksi PostgreSQL versi $PG_VERSION"

    # Install pgaudit extension
    if apt-cache show postgresql-$PG_VERSION-pgaudit &> /dev/null; then
        apt-get install -y postgresql-$PG_VERSION-pgaudit || error_exit "Gagal menginstal pgaudit extension"
    else
        echo "Paket postgresql-$PG_VERSION-pgaudit tidak ditemukan. Mencoba cara alternatif..."
        apt-get install -y postgresql-server-dev-$PG_VERSION build-essential git
        git clone https://github.com/pgaudit/pgaudit.git
        cd pgaudit
        git checkout REL_${PG_VERSION}_STABLE
        make USE_PGXS=1
        make USE_PGXS=1 install
        cd ..
        rm -rf pgaudit
    fi

    # Aktifkan pgaudit extension
    run_psql "CREATE EXTENSION IF NOT EXISTS pgaudit;"

    # Tambahkan konfigurasi pgaudit ke postgresql.conf
    echo "shared_preload_libraries = 'pgaudit'" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf

    # Restart PostgreSQL service
    systemctl restart postgresql || error_exit "Gagal merestart PostgreSQL service"

    echo "Instalasi PostgreSQL dan pgaudit selesai."
}

# Fungsi untuk mengkonfigurasi monitoring
configure_monitoring() {
    echo "Mengkonfigurasi monitoring PostgreSQL..."

    run_psql "ALTER SYSTEM SET log_destination = 'csvlog';"
    run_psql "ALTER SYSTEM SET logging_collector = on;"
    run_psql "ALTER SYSTEM SET log_directory = '/var/log/postgresql';"
    run_psql "ALTER SYSTEM SET log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log';"
    run_psql "ALTER SYSTEM SET log_rotation_age = '1d';"
    run_psql "ALTER SYSTEM SET log_rotation_size = 0;"
    run_psql "ALTER SYSTEM SET log_statement = 'all';"
    run_psql "ALTER SYSTEM SET log_connections = on;"
    run_psql "ALTER SYSTEM SET log_disconnections = on;"
    run_psql "ALTER SYSTEM SET log_duration = on;"
    run_psql "ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';"
    
    run_psql "ALTER SYSTEM SET pgaudit.log = 'write, function, role, ddl';"
    run_psql "ALTER SYSTEM SET pgaudit.log_catalog = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_parameter = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_statement_once = on;"
    run_psql "ALTER SYSTEM SET pgaudit.log_level = log;"

    # Buat view untuk query log
    run_psql "
    CREATE OR REPLACE VIEW log_view AS
    SELECT * FROM pg_catalog.pg_logical_slot_peek_changes('test_slot', null, null);
    "

    # Buat fungsi untuk query log terbaru
    run_psql "
    CREATE OR REPLACE FUNCTION get_recent_logs(minutes integer DEFAULT 5)
    RETURNS TABLE (
        log_time timestamp with time zone,
        user_name text,
        database_name text,
        connection_from text,
        message text,
        query text
    ) AS \$\$
    BEGIN
        RETURN QUERY
        SELECT
            (regexp_matches(data, 'log_time:([^,]+)'))[1]::timestamp with time zone,
            (regexp_matches(data, 'user_name:([^,]+)'))[1],
            (regexp_matches(data, 'database_name:([^,]+)'))[1],
            (regexp_matches(data, 'connection_from:([^,]+)'))[1],
            (regexp_matches(data, 'message:([^,]+)'))[1],
            (regexp_matches(data, 'query:([^,]+)'))[1]
        FROM pg_catalog.pg_logical_slot_peek_changes('test_slot', null, null)
        WHERE (regexp_matches(data, 'log_time:([^,]+)'))[1]::timestamp with time zone > (current_timestamp - (minutes || ' minutes')::interval)
        ORDER BY (regexp_matches(data, 'log_time:([^,]+)'))[1]::timestamp with time zone DESC;
    END;
    \$\$ LANGUAGE plpgsql;
    "

    echo "Konfigurasi monitoring PostgreSQL selesai."
}

# Fungsi untuk mengatur akses remote
setup_remote_access() {
    echo "Mengatur akses remote untuk PostgreSQL..."

    PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
    echo "host    all             all             0.0.0.0/0               md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf

    # Buka port PostgreSQL di firewall
    ufw allow 5432/tcp

    systemctl restart postgresql

    echo "Pengaturan akses remote selesai. PostgreSQL sekarang dapat diakses dari alamat IP eksternal."
    echo "PERINGATAN: Pastikan untuk mengamankan server Anda dan hanya mengizinkan koneksi dari alamat IP yang dipercaya."
}

# Fungsi untuk membuat database perpustakaan
setup_library_database() {
    echo "Membuat database perpustakaan..."

    run_psql "CREATE DATABASE library;"
    
    run_psql -d library "
    CREATE TABLE books (
        id SERIAL PRIMARY KEY,
        title VARCHAR(100) NOT NULL,
        author VARCHAR(100) NOT NULL,
        publication_year INTEGER,
        isbn VARCHAR(13) UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE OR REPLACE FUNCTION update_modified_column()
    RETURNS TRIGGER AS \$\$
    BEGIN
        NEW.updated_at = now();
        RETURN NEW;
    END;
    \$\$ language 'plpgsql';

    CREATE TRIGGER update_books_modtime
        BEFORE UPDATE ON books
        FOR EACH ROW
        EXECUTE FUNCTION update_modified_column();

    INSERT INTO books (title, author, publication_year, isbn)
    VALUES ('To Kill a Mockingbird', 'Harper Lee', 1960, '9780446310789');

    INSERT INTO books (title, author, publication_year, isbn)
    VALUES ('1984', 'George Orwell', 1949, '9780451524935');

    CREATE VIEW book_summary AS
    SELECT id, title, author, publication_year
    FROM books
    ORDER BY publication_year DESC;

    CREATE OR REPLACE PROCEDURE add_book(
        p_title VARCHAR(100),
        p_author VARCHAR(100),
        p_publication_year INTEGER,
        p_isbn VARCHAR(13)
    )
    LANGUAGE plpgsql
    AS \$\$
    BEGIN
        INSERT INTO books (title, author, publication_year, isbn)
        VALUES (p_title, p_author, p_publication_year, p_isbn);
    END;
    \$\$;

    CREATE OR REPLACE FUNCTION get_book_count_by_year(p_year INTEGER)
    RETURNS INTEGER
    LANGUAGE plpgsql
    AS \$\$
    DECLARE
        book_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO book_count
        FROM books
        WHERE publication_year = p_year;
        
        RETURN book_count;
    END;
    \$\$;
    "

    echo "Database perpustakaan telah dibuat dan diatur."
}

# Menu utama
while true; do
    echo "
PostgreSQL Monitoring dan Database Perpustakaan Setup
=====================================================
1. Instal PostgreSQL dan pgaudit
2. Konfigurasi Monitoring
3. Setup Akses Remote
4. Buat Database Perpustakaan
5. Keluar
"
    read -p "Pilih opsi (1-5): " choice

    case $choice in
        1) install_postgresql_and_pgaudit ;;
        2) configure_monitoring ;;
        3) setup_remote_access ;;
        4) setup_library_database ;;
        5) echo "Terima kasih telah menggunakan script ini."; exit 0 ;;
        *) echo "Pilihan tidak valid. Silakan coba lagi." ;;
    esac

    echo "Tekan Enter untuk kembali ke menu..."
    read
done