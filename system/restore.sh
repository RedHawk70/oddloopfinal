#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NiLphreakz
# (C) Copyright 2022
# =========================================
# PROVIDED
creditt=$(cat /root/provided)
# BANNER COLOUR
banner_colour=$(cat /etc/banner)
# TEXT ON BOX COLOUR
box=$(cat /etc/box)
# LINE COLOUR
line=$(cat /etc/line)
# TEXT COLOUR ON TOP
text=$(cat /etc/text)
# TEXT COLOUR BELOW
below=$(cat /etc/below)
# BACKGROUND TEXT COLOUR
back_text=$(cat /etc/back)
# NUMBER COLOUR
number=$(cat /etc/number)

red='\e[1;31m'
green='\e[0;32m'
purple='\e[0;35m'
orange='\e[0;33m'
NC='\e[0m'
clear
echo ""
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo -e   "  \e[$back_text            \e[30m[\e[$box RESTORE SSH & XRAY ACCOUNT \e[30m ]\e[1m            \e[m"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo ""
echo " This Feature Can Only Be Used According To VPS Data With This Autoscript"
echo " Please Insert VPS Data Backup Link To Restore The Data"
echo ""
#read -rp " Password File: " -e InputPass
read -rp " Link File: " -e url
umask 077
workdir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$workdir"' EXIT
wget -O "$workdir/backup.zip" -- "$url" || exit 1
unzip -q "$workdir/backup.zip" -d "$workdir" || exit 1
backup_dir="$workdir/backup"
xray_dir=/usr/local/etc/xray
configlist_dir=/etc/xray/configlist

read_domain() {
    if [[ -f "$1" ]]; then
        tr -d '\r' < "$1" | awk 'NR == 1 {print $1}'
    fi
}

rewrite_configlist() {
    local source_dir="$1" old_domain="$2" new_domain="$3" file
    [[ -d "$source_dir" && -n "$old_domain" && "$old_domain" != "$new_domain" ]] || return 0
    for file in "$source_dir"/*.conf; do
        [[ -f "$file" && ! -L "$file" ]] || continue
        # Format semasa: nama, mode, proto, Address, Path, SNI/Host, Host TLS pilihan.
        # Format lama tanpa mode: nama, proto, Address, Path, SNI/Host.
        awk -v old="$old_domain" -v new="$new_domain" '
            BEGIN { FS = OFS = "\t"; old = tolower(old) }
            function change(value,    len, suffix) {
                suffix = (value ~ /[.]$/ ? "." : "")
                if (suffix) value = substr(value, 1, length(value) - 1)
                len = length(value) - length(old)
                if (tolower(value) == old) return new suffix
                if (len > 0 && substr(value, len, 1) == "." &&
                    tolower(substr(value, len + 1)) == old)
                    return substr(value, 1, len) new suffix
                return value suffix
            }
            /^[[:space:]]*(#|$)/ { print; next }
            {
                if (NF >= 6 && $2 ~ /^(vless|vmess|xtls|trojan)$/ && $3 ~ /^[1-6]$/) {
                    $4 = change($4)
                    $6 = change($6)
                    if (NF >= 7) $7 = change($7)
                } else if (NF == 5 && $2 ~ /^[1-6]$/) {
                    $3 = change($3)
                    $5 = change($5)
                }
                print
            }
        ' "$file" > "$workdir/configlist.tmp" || return 1
        cat "$workdir/configlist.tmp" > "$file" || return 1
    done
}

[[ -d "$backup_dir/xray" ]] || { echo "Backup tidak mengandungi folder backup/xray." >&2; exit 1; }
old_domain=$(read_domain "$backup_dir/xray/domain")
[[ -n "$old_domain" ]] || old_domain=$(read_domain "$backup_dir/source-domain")
new_domain=$(read_domain "$xray_dir/domain")
if [[ ! "$new_domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
    read -rp "Domain VPS semasa tidak dijumpai. Masukkan domain: " new_domain
    [[ "$new_domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] ||
        { echo "Domain tidak sah. Restore dibatalkan." >&2; exit 1; }
fi
printf 'Domain VPS semasa: %s\n' "$new_domain"
if [[ -d "$backup_dir/configlist" ]]; then
    if [[ -z "$old_domain" ]]; then
        read -rp "Domain asal tiada dalam backup. Masukkan domain asal (Enter untuk kekalkan nilai config): " old_domain
        if [[ -n "$old_domain" && ! "$old_domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
            echo "Domain asal tidak sah. Restore dibatalkan." >&2
            exit 1
        fi
    fi
    rewrite_configlist "$backup_dir/configlist" "$old_domain" "$new_domain" || exit 1
fi

echo -e "[ ${green}INFO${NC} ] Start Restore . . . "
# Fail domain dalam backup hanya digunakan untuk mengenal pasti domain asal.
rm -f -- "$backup_dir/xray/domain" || exit 1
mkdir -p "$xray_dir" || exit 1
cp -r "$backup_dir/xray/." "$xray_dir/" || exit 1
if [[ "$(read_domain "$xray_dir/domain")" != "$new_domain" ]]; then
    printf '%s\n' "$new_domain" > "$xray_dir/domain" || exit 1
fi
if [[ -d "$backup_dir/configlist" ]]; then
    mkdir -p "$configlist_dir" || exit 1
    cp -r "$backup_dir/configlist/." "$configlist_dir/" || exit 1
fi
for item in crontab cron.d shadow gshadow passwd group; do
    [[ ! -e "$backup_dir/$item" ]] || cp -r "$backup_dir/$item" /etc/ || exit 1
done
echo ""
echo -e "[ ${green}INFO${NC} ] VPS Data Restore Complete !"
echo ""
echo -e "[ ${green}INFO${NC} ] Back to menu . . . "
systemctl restart nginx
systemctl restart xray.service
systemctl restart xray@none.service
systemctl restart xray@vless.service
systemctl restart xray@vnone.service
systemctl restart xray@trojanws.service
systemctl restart xray@trnone.service
systemctl restart xray@xtrojan.service
systemctl restart xray@trojan.service
service cron restart
sleep 5
system
clear
