#!/bin/bash

# Konfigurasi umum
LOG_FILE="/var/log/postgresql_setup.log"
DEBUG=true

# PostgreSQL configuration
PG_VERSION="14"
DB_NAME="mydb"
AUDIT_DB_NAME="audit_db"
DB_USER="myuser"
AUDIT_DB_USER="audit_user"
DB_PASSWORD="mypassword"
AUDIT_DB_PASSWORD="audit_password"