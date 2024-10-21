# Panduan Langkah Demi Langkah: Pengaturan Monitoring PostgreSQL dan Database Perpustakaan

Ikuti langkah-langkah berikut untuk mengatur sistem monitoring PostgreSQL dan database perpustakaan:

## 1. Persiapan

1. Pastikan Anda memiliki akses root atau sudo pada sistem Ubuntu atau Debian Anda.
2. Buka terminal.

## 2. Instalasi PostgreSQL dan pgaudit

1. Buat file `postgresql_monitoring_installer.sh` dengan konten yang ada di README.md.
2. Berikan izin eksekusi pada file:
   ```
   chmod +x postgresql_monitoring_installer.sh
   ```
3. Jalankan script installer:
   ```
   sudo ./postgresql_monitoring_installer.sh
   ```

## 3. Konfigurasi Monitoring

1. Buat file `postgresql_monitoring.conf` dengan konten yang ada di README.md.
2. Buat file `postgresql_monitoring_setup.sh` dengan konten yang ada di README.md.
3. Berikan izin eksekusi pada file setup:
   ```
   chmod +x postgresql_monitoring_setup.sh
   ```
4. Jalankan script setup:
   ```
   sudo ./postgresql_monitoring_setup.sh
   ```

## 4. Verifikasi Konfigurasi Monitoring

1. Masuk ke PostgreSQL sebagai user postgres:
   ```
   sudo -u postgres psql
   ```
2. Cek apakah view monitoring telah dibuat:
   ```sql
   \d log_view
   ```
3. Cek apakah fungsi monitoring telah dibuat:
   ```sql
   \df get_recent_logs
   ```
4. Keluar dari PostgreSQL:
   ```sql
   \q
   ```

## 5. Setup Database Perpustakaan

1. Buat file `library_database_setup.sql` dengan konten yang ada di README.md.
2. Jalankan script SQL:
   ```
   sudo -u postgres psql -f library_database_setup.sql
   ```

## 6. Verifikasi Setup Database Perpustakaan

1. Masuk ke database library:
   ```
   sudo -u postgres psql -d library
   ```
2. Cek apakah tabel books telah dibuat:
   ```sql
   \d books
   ```
3. Cek apakah view book_summary telah dibuat:
   ```sql
   \d book_summary
   ```
4. Cek apakah stored procedure add_book telah dibuat:
   ```sql
   \df add_book
   ```
5. Cek apakah fungsi get_book_count_by_year telah dibuat:
   ```sql
   \df get_book_count_by_year
   ```

## 7. Penggunaan

1. Tambahkan buku baru:
   ```sql
   CALL add_book('Pride and Prejudice', 'Jane Austen', 1813, '9780141439518');
   ```
2. Lihat semua buku:
   ```sql
   SELECT * FROM books;
   ```
3. Perbarui informasi buku:
   ```sql
   UPDATE books SET publication_year = 1961 WHERE id = 1;
   ```
4. Hapus buku:
   ```sql
   DELETE FROM books WHERE id = 2;
   ```
5. Lihat ringkasan buku:
   ```sql
   SELECT * FROM book_summary;
   ```
6. Hitung jumlah buku untuk tahun tertentu:
   ```sql
   SELECT get_book_count_by_year(1813);
   ```
7. Lihat log terbaru:
   ```sql
   SELECT * FROM get_recent_logs(10);
   ```

## 8. Akses Jarak Jauh (Opsional)

Jika Anda ingin mengakses database dari jarak jauh:

1. Pastikan firewall Anda mengizinkan koneksi ke port 5432.
2. Gunakan tool seperti pgAdmin atau psql untuk terhubung ke database menggunakan alamat IP server Anda.

## 9. Keamanan

1. Tinjau pengaturan di pg_hba.conf untuk membatasi akses hanya ke alamat IP yang dipercaya.
2. Pertimbangkan untuk menggunakan SSL untuk enkripsi koneksi.
3. Selalu gunakan password yang kuat untuk user database.

Selamat! Anda telah berhasil mengatur sistem monitoring PostgreSQL dan database perpustakaan. Pastikan untuk selalu menjaga keamanan sistem Anda dan melakukan backup secara teratur.