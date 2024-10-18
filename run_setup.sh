#!/bin/bash

# Import dependencies
source ./config.sh
source ./logger.sh

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Fungsi untuk animasi loading
show_loading() {
    local duration=$1
    local interval=0.1
    local spinstr='|/-\'
    local temp
    echo -n "  "
    for (( i=0; i<$(echo "$duration/$interval" | bc); i++ )); do
        temp=${spinstr#?}
        printf "\r%s %c  " "$2" "${spinstr}"
        spinstr=$temp${spinstr%"${temp}"}
        sleep $interval
    done
    printf "\r%s    \n" "$2"
}

# Fungsi untuk menampilkan banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ____  ____  ____ _____   ____ _____ _____ _   _ ____  "
    echo " |  _ \|  _ \/ ___|_   _| / ___|  ___|_   _| | | |  _ \ "
    echo " | |_) | | | \___ \ | |   \___ \ |_    | | | | | | |_) |"
    echo " |  __/| |_| |___) || |    ___) |  _|  | | | |_| |  __/ "
    echo " |_|   |____/|____/ |_|   |____/|_|    |_|  \___/|_|    "
    echo -e "${RESET}"
    echo -e "${YELLOW}============== PostgreSQL Server Setup ==============${RESET}"
    echo
}

# Fungsi untuk menampilkan menu
show_menu() {
    echo -e "${GREEN}1.${RESET} Setup Main Server"
    echo -e "${GREEN}2.${RESET} Setup Audit Server"
    echo -e "${RED}3.${RESET} Exit"
    echo
}

# Fungsi untuk menangani pilihan menu
handle_choice() {
    local choice
    read -p "$(echo -e ${BLUE}"Enter your choice [1-3]: "${RESET})" choice
    case $choice in
        1) 
            echo -e "${YELLOW}Starting Main Server Setup...${RESET}"
            show_loading 2 "Initializing"
            bash main_server_setup.sh
            ;;
        2) 
            echo -e "${YELLOW}Starting Audit Server Setup...${RESET}"
            show_loading 2 "Initializing"
            bash audit_server_setup.sh
            ;;
        3) 
            echo -e "${RED}Exiting...${RESET}"
            show_loading 1 "Cleaning up"
            exit 0
            ;;
        *) 
            echo -e "${RED}Invalid choice. Please try again.${RESET}"
            sleep 2
            ;;
    esac
}

# Fungsi untuk konfirmasi exit
confirm_exit() {
    read -p "$(echo -e ${YELLOW}"Are you sure you want to exit? (y/n): "${RESET})" confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo -e "${RED}Exiting...${RESET}"
        show_loading 1 "Cleaning up"
        exit 0
    fi
}

# Main loop
main() {
    trap 'confirm_exit' SIGINT
    while true
    do
        show_banner
        show_menu
        handle_choice
        echo
        read -p "$(echo -e ${MAGENTA}"Press enter to continue..."${RESET})"
    done
}

# Run the main function
main