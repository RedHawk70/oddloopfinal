#!/bin/bash

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[97m"
BOLD="\e[1m"
RESET="\e[0m"

install_v2() {
    echo -e "${YELLOW}${BOLD}>> Installing Script Multiport Version 2.0 [ OLD XRAYCORE ]...${RESET}"

    apt update -y && \
    apt upgrade -y && \
    apt dist-upgrade -y && \
    apt update && \
    apt install -y bzip2 gzip coreutils screen wget curl && \
    wget https://raw.githubusercontent.com/RedHawk70/oddloopfinal/main/setup.sh && \
    chmod +x setup.sh && \
    sed -i -e 's/\r$//' setup.sh && \
    screen -S setup ./setup.sh
}

install_v3() {
    echo -e "${YELLOW}${BOLD}>> Installing Script Multiport Version 3.0 [ LATEST XRAYCORE + NEW SERVICES ]...${RESET}"

    apt update -y && \
    apt upgrade -y && \
    apt dist-upgrade -y && \
    apt update && \
    apt install -y bzip2 gzip coreutils screen wget curl && \
    wget https://raw.githubusercontent.com/RedHawk70/oddloopfinal/main/setup2.sh && \
    chmod +x setup2.sh && \
    sed -i -e 's/\r$//' setup2.sh && \
    screen -S setup ./setup2.sh
}

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${RESET}             ${BOLD}${MAGENTA}SCRIPT MULTIPORT BY NILPHREAKZ${RESET}             ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}1)${RESET} Install Version 2.0 [OLD XRAYCORE]                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${GREEN}2)${RESET} Install Version 3.0 [LATEST XRAYCORE+NEW SERVICES] ${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}  ${RED}0)${RESET} Exit                                               ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -ne "${BOLD}${WHITE}Pilih option [0-2]: ${RESET}"
    read choice

    case "$choice" in
        1)
            install_v2
            read dummy
            ;;
        2)
            install_v3
            read dummy
            ;;
        0)
            echo
            echo -e "${RED}${BOLD}Keluar dari installer. Bye!${RESET}"
            exit 0
            ;;
        *)
            echo
            echo -e "${RED}Pilihan tak sah! Sila pilih 0, 1 atau 2.${RESET}"
            echo -ne "${CYAN}Tekan ENTER untuk cuba lagi...${RESET}"
            read dummy
            ;;
    esac
done
