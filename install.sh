#!/bin/bash

# Fungsi untuk menampilkan menu
show_menu() {
    clear
    echo "================================"
    echo "PostgreSQL Server Setup Installer"
    echo "================================"
    echo "1. Install/Configure Main Server"
    echo "2. Install/Configure Audit Server"
    echo "3. Exit"
    echo "================================"
}

# Fungsi untuk menangani pilihan menu
handle_choice() {
    local choice
    read -p "Enter choice [1-3]: " choice
    case $choice in
        1) 
            echo "Installing/Configuring Main Server..."
            bash main_server_setup.sh
            ;;
        2) 
            echo "Installing/Configuring Audit Server..."
            bash audit_server_setup.sh
            ;;
        3) 
            echo "Exiting..."
            exit 0
            ;;
        *) 
            echo "Invalid choice. Please try again."
            sleep 2
            ;;
    esac
}

# Main loop
while true
do
    show_menu
    handle_choice
done
