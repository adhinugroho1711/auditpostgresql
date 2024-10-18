#!/bin/bash

# Import config
source ./config.sh

# Fungsi untuk logging
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] $message"
}

log_info() {
    log "INFO" "$1"
}

log_error() {
    log "ERROR" "$1"
}

log_warning() {
    log "WARNING" "$1"
}

log_debug() {
    if [ "$DEBUG" = true ]; then
        log "DEBUG" "$1"
    fi
}
