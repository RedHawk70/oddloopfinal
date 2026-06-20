#!/bin/bash

# =========================================
# BBR Manager + Optimizer
# Date: 2025-12-11
# Original Author: NevermoreSSH + GPT
# (C) Copyright 2025 - 2026
# =========================================
# Warna
line="38;5;208"         # Oyen terang
GREEN="\e[92m" # hijau
WHITE="\033[1;37m"
PINK="\e[38;5;205m" # Pink terang
back_text="1;37;44"  # Putih + biru gelap
box="1;37"           # Putih bold
# ============================
# COLOR THEME PREMIUM
# ============================
text="1;37"          # Putih bold (info text)
title="\e[30;107m"   # 30 = hitam, 107 = background putih
number="\e[38;5;205"        # Kuning gold (untuk nombor menu)
below="0;37"         # Putih lembut
reset="\e[0m"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Add line if not exists
Add_Line_If_Not_Exist(){
    if [ "$(tail -n1 $1 | wc -l)" == "0" ]; then
        echo "" >> "$1"
    fi
    echo "$2" >> "$1"
}

# Check and add line if missing
Check_And_Add_Line(){
    if [ -z "$(grep -Fx "$2" "$1")" ]; then
        Add_Line_If_Not_Exist "$1" "$2"
    fi
}

# Check BBR status
check_status() {
    cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    if [[ "$cc" == "bbr" ]]; then
        echo -e "${BLUE}Current congestion control: ${YELLOW}$cc${NC} (${GREEN}BBR ON${NC})"
    else
        echo -e "${BLUE}Current congestion control: ${YELLOW}$cc${NC} (${RED}BBR OFF${NC})"
    fi
}

# Enable BBR
enable_bbr() {
    echo -e "${GREEN}Enabling BBR...${NC}"
    modprobe tcp_bbr
    Add_Line_If_Not_Exist "/etc/modules-load.d/modules.conf" "tcp_bbr"
    sed -i '/net.ipv4.tcp_congestion_control\s*=\s*cubic/d' /etc/sysctl.conf
    Add_Line_If_Not_Exist "/etc/sysctl.conf" "net.core.default_qdisc = fq"
    Add_Line_If_Not_Exist "/etc/sysctl.conf" "net.ipv4.tcp_congestion_control = bbr"
    sysctl -p
    if lsmod | grep -q tcp_bbr && sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
        echo -e "${GREEN}BBR successfully enabled!${NC}"
    else
        echo -e "${RED}Failed to enable BBR!${NC}"
    fi
    check_status
}

# Disable BBR (switch to cubic)
disable_bbr() {
    echo -e "${RED}Disabling BBR (switching to cubic)...${NC}"
    sed -i '/net.ipv4.tcp_congestion_control\s*=\s*bbr/d' /etc/sysctl.conf
    sysctl -w net.ipv4.tcp_congestion_control=cubic
    sysctl -p
    echo -e "${RED}BBR is now disabled, using cubic.${NC}"
    check_status
}

# Optimize system parameters
optimize_parameters() {
    echo -e "${BLUE}Optimizing system parameters...${NC}"
    Check_And_Add_Line "/etc/security/limits.conf" "* soft nofile 51200"
    Check_And_Add_Line "/etc/security/limits.conf" "* hard nofile 51200"
    Check_And_Add_Line "/etc/security/limits.conf" "root soft nofile 51200"
    Check_And_Add_Line "/etc/security/limits.conf" "root hard nofile 51200"
    Check_And_Add_Line "/etc/sysctl.conf" "fs.file-max = 51200"
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.rmem_max = 67108864"
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.wmem_max = 67108864"
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.netdev_max_backlog = 250000"
    Check_And_Add_Line "/etc/sysctl.conf" "net.core.somaxconn = 4096"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_syncookies = 1"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_tw_reuse = 1"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_fin_timeout = 30"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_keepalive_time = 1200"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.ip_local_port_range = 10000 65000"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_max_syn_backlog = 8192"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_max_tw_buckets = 5000"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_fastopen = 3"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_mem = 25600 51200 102400"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_rmem = 4096 87380 67108864"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_wmem = 4096 65536 67108864"
    Check_And_Add_Line "/etc/sysctl.conf" "net.ipv4.tcp_mtu_probing = 1"
    sysctl -p
    echo -e "${GREEN}System optimization completed.${NC}"
}

# Interactive menu
while true; do
    clear
    echo -e "\e[${line}m═══════════════════════════════════════════${reset}"
    echo -e "\e[${title}       [ BBR Manager + Optimizer ]         ${reset}"
    echo -e "\e[${line}m═══════════════════════════════════════════${reset}
\033[1;37mBBR Manager By NiLphreakz\033[0m
\033[1;37mTelegram : https://t.me/NiLphreakz \033[0m"
	echo -e " "
    check_status
	echo -e " "
    echo -e "${YELLOW}Select an option:${NC}"
    echo -e "${WHITE}1) Enable BBR${NC}"
    echo -e "${WHITE}2) Disable BBR${NC}"
    echo -e "${WHITE}3) Optimize system parameters${NC}"
    echo -e "${WHITE}4) Check BBR status${NC}"
	echo -e " "
    echo -e "${RED}0) Back to menu${NC}"
    read -p "Enter choice [0-4]: " choice

    case $choice in
        1) enable_bbr ;;
        2) disable_bbr ;;
        3) optimize_parameters ;;
        4) check_status ;;
        0) menu ;;
		x) menu-tweak ;;
        *) echo -e "${RED}Invalid choice!${NC}" ; sleep 1 ;;
    esac
    read -p "Press Enter to return to menu..."
done
