#!/bin/bash

# Fungsi untuk membuat database perpustakaan
setup_library_database() {
    echo "Membuat database perpustakaan..."

    run_psql "CREATE DATABASE library;"
    
    sudo -u postgres psql -d library -c "
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