#!/bin/bash

# Fungsi untuk mengkonfigurasi monitoring
configure_monitoring() {
    echo "Mengkonfigurasi monitoring PostgreSQL..."

    run_psql "CREATE EXTENSION IF NOT EXISTS pgaudit;"
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

    restart_postgresql

    echo "Konfigurasi monitoring PostgreSQL selesai."
}