#!/bin/bash
# =========================================
# IPv4 + IPv6 Toggle
# Date: 2025-12-11
# Author: NevermoreSSH
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

# Detect IPv4
IPV4=$(hostname -I | awk '{print $1}')

# Detect IPv6 global (skip link-local fe80::)
IPV6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | head -n1)
[ -z "$IPV6" ] && IPV6="Not assigned"

# Detect IPv6 link-local
IPV6_LL=$(ip -6 addr show scope link | grep inet6 | awk '{print $2}' | head -n1)

# Cek status IPv6 kernel
STATUS_IPV6=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
[ "$STATUS_IPV6" -eq 0 ] && IPV6_STATUS="Enabled" || IPV6_STATUS="Disabled"
clear
echo ""
echo -e "\e[${line}m═══════════════════════════════════════════════${reset}"
echo -e "\e[${title}        [ IP Menu - IPv4 / IPv6 Toggle ]       ${reset}"
echo -e "\e[${line}m═══════════════════════════════════════════════${reset}
\033[1;37mIPv4v6 Changer By NiLphreakz\033[0m
\033[1;37mTelegram : https://t.me/NiLphreakz \033[0m"
echo ""

echo -e " IPv4 Address      : \033[1;32m$IPV4${reset}"
echo -e " IPv6 Link-Local   : \033[1;36m$IPV6_LL${reset}"
echo -e " IPv6 Global       : \033[1;36m$IPV6${reset}"
echo -e " IPv6 Status       : \033[1;33m$IPV6_STATUS${reset}"
echo ""

echo -e " [\033[1;36m•1\033[0m]  \e[${below}mIPv4 Only (Disable IPv6)${reset}"
echo -e " [\033[1;36m•2\033[0m]  \e[${below}mIPv4 + IPv6 (Enable IPv6)${reset}"
echo -e " [\033[1;36m•3\033[0m]  \e[${below}mReboot Server${reset}"
echo ""
echo -e " [\033[1;36m•0\033[0m]  \e[${below}mBack To Menu${reset}"
echo "
 Notes: 
 - Please restart / reboot server after change IPv4v6."
echo ""
echo -e "\033[1;37mPress [ Ctrl+C ] • To Exit Script${reset}"
echo ""
echo -e "\e[${below}m"

read -p " Select menu : " opt
echo -e ""

case $opt in
1)
    clear
    echo "Disabling IPv6..."
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1
    echo "IPv6 telah dimatikan. Hanya IPv4 aktif."
    sleep 2
    exec ip6menu
    ;;
3)
    clear
    reboot
    ;;
2)
    clear
    echo "Enabling IPv6..."
    sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sysctl -w net.ipv6.conf.default.disable_ipv6=0
    echo -e ""
    echo "IPv6 telah diaktifkan. IPv4 + IPv6 aktif."
	read -n 1 -s -r -p "Press any key to reboot"
	reboot
    ;;
0|x)
    clear
    exec menu
    ;;
*)
    echo "Wrong Button"
    sleep 1
    exec ip6menu
    ;;
esac
