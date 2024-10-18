# PostgreSQL Server Setup

Proyek ini menyediakan script bash untuk menyiapkan dan mengkonfigurasi server PostgreSQL, termasuk server utama dan server audit. Script ini dirancang untuk mempermudah proses setup, konfigurasi, dan pengujian server PostgreSQL.

## Fitur

- Setup otomatis untuk server PostgreSQL utama dan audit
- Konfigurasi Foreign Data Wrapper untuk koneksi antar server
- Pembuatan tabel sampel dan operasi CRUD
- Implementasi sistem audit log
- Antarmuka pengguna interaktif dengan tampilan berwarna
- Logging komprehensif untuk kemudahan debugging

## Persyaratan Sistem

- Sistem operasi berbasis Debian (misalnya Ubuntu)
- Akses sudo
- Bash shell

## Struktur Proyek

```
.
├── config.sh
├── create_tables.sh
├── crud_operations.sh
├── logger.sh
├── main_server_setup.sh
├── audit_server_setup.sh
└── run_setup.sh
```

## Cara Penggunaan

1. Clone repositori ini ke mesin lokal Anda:
   ```
   git clone https://github.com/username/postgresql-server-setup.git
   cd postgresql-server-setup
   ```

2. Beri izin eksekusi pada semua file bash:
   ```
   chmod +x *.sh
   ```

3. Edit `config.sh` sesuai dengan kebutuhan Anda (opsional):
   ```
   nano config.sh
   ```

4. Jalankan script setup:
   ```
   sudo ./run_setup.sh
   ```

5. Ikuti petunjuk di layar untuk menyelesaikan proses setup.

## Konfigurasi

Anda dapat mengubah konfigurasi default dengan mengedit file `config.sh`. Beberapa pengaturan yang dapat diubah meliputi:

- Nama database
- Nama pengguna dan kata sandi
- Lokasi file log

## Logging

Log dari proses setup disimpan di `/var/log/postgresql_setup.log` secara default. Anda dapat mengubah lokasi ini di `config.sh`.

## Troubleshooting

Jika Anda mengalami masalah saat menjalankan script:

1. Pastikan Anda memiliki akses sudo.
2. Periksa file log untuk informasi lebih detail tentang error.
3. Pastikan semua dependensi telah terpenuhi.

## Kontribusi

Kontribusi untuk proyek ini sangat diterima. Silakan fork repositori ini, buat perubahan, dan ajukan pull request.

## Lisensi

Proyek ini dilisensikan di bawah [MIT License](LICENSE).

## Kontak

Jika Anda memiliki pertanyaan atau masalah, silakan buka issue di repositori GitHub ini.