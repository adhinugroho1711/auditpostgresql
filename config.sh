#!/bin/bash

# PostgreSQL Version
PG_VERSION="14"

# PostgreSQL Credentials
PG_USER="postgres"
PG_PASSWORD="postgres123"  # Ganti dengan password yang aman
PG_DB="postgres"
PG_HOST="localhost"
PG_PORT="5432"

# PostgreSQL Directories
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
PG_DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
PG_LOG_DIR="/var/log/postgresql"

# PgAudit Configuration
PGAUDIT_ENABLED=true

# Backup Configuration
BACKUP_DIR="/var/backups/postgresql"
BACKUP_RETENTION_DAYS=7

# Other Settings
MAX_CONNECTIONS=100
SHARED_BUFFERS="256MB"

# Function to load environment-specific overrides
load_env_config() {
    local env_config="/etc/postgresql/pg_env.conf"
    if [ -f "$env_config" ]; then
        source "$env_config"
        echo "Loaded environment-specific configuration from $env_config"
    fi
}

# Load environment-specific configuration
load_env_config