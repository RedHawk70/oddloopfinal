#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NiLphreakz
# (C) Copyright 2022
# =========================================

red='\e[1;31m'
green='\e[0;32m'
purple='\e[0;35m'
orange='\e[0;33m'
NC='\e[0m'
clear
IP=$(wget -qO- https://icanhazip.com) || exit 1
[[ "$IP" =~ ^[0-9a-fA-F:.]+$ ]] || { echo "IP VPS tidak sah." >&2; exit 1; }
date=$(date +"%Y-%m-%d-%H:%M:%S")
umask 077
workdir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$workdir"' EXIT
cd "$workdir" || exit 1
mkdir backup || exit 1
echo -e "[ ${green}INFO${NC} ] Backup SSH & XRAY Account . . . "
cp -r /usr/local/etc/xray backup/xray || exit 1
if [[ -d /etc/xray/configlist ]]; then
    cp -r /etc/xray/configlist backup/configlist || exit 1
fi
if [[ -s backup/xray/domain ]]; then
    domain=$(awk 'NR == 1 {print $1}' backup/xray/domain | tr -d '\r')
else
    domain="$IP"
    if [[ "$IP" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
        printf '%s\n' "$IP" > backup/source-domain || exit 1
    fi
fi
[[ "$domain" =~ ^[a-zA-Z0-9.:-]+$ ]] || domain="$IP"
[[ ! -d /home/vps/public_html ]] || cp -r /home/vps/public_html backup/public_html || exit 1
cp /etc/shadow /etc/gshadow /etc/passwd /etc/group backup/ || exit 1
archive="$IP-$date-$domain-oddloop.zip"
zip -qr "$archive" backup || exit 1
rclone copy "$workdir/$archive" dr:backup/ || exit 1
url=$(rclone link "dr:backup/$archive") || exit 1
if [[ "$url" =~ [\?\&]id=([a-zA-Z0-9_-]+) || "$url" =~ drive\.google\.com/file/d/([a-zA-Z0-9_-]+) ]]; then
    link="https://drive.google.com/u/4/uc?id=${BASH_REMATCH[1]}&export=download"
else
    link="$url"
fi
clear
echo -e "\033[1;37mVPS Data Backup By NiLphreakz\033[0m
\033[1;37mTelegram : https://t.me/NiLphreakz / @NiLphreakz\033[0m"
echo ""
echo "Please Copy Link Below & Save In Notepad"
echo ""
echo -e "Your VPS IP ( \033[1;37m$IP\033[0m )"
echo ""
echo -e "\033[1;37m$link\033[0m"
echo ""
echo "If you want to restore data, please enter the link above"
echo ""
