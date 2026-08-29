#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0 (fixed)
# Auther  : NiLphreakz
# =========================================
clear

TLS_FILE="/usr/local/etc/xray/config.json"   # TLS (443)
NONE_FILE="/usr/local/etc/xray/none.json"    # NONE-TLS (80)
XTR_FILE="/usr/local/etc/xray/akunxtr.conf"

today=$(date -d "$(date +%Y-%m-%d)" +%s)
restart_tls=0
restart_none=0
deleted_users=()

# Buang user expired dari SATU fail ikut marker.
# PENTING: exp dibaca dari fail YANG SAMA dengan fail yang kena sed.
clean_file() {
    local file="$1" marker="$2"
    [[ -f "$file" ]] || return 0

    while read -r user; do
        [[ -z "$user" ]] && continue
        while read -r exp; do
            [[ -z "$exp" ]] && continue
            local d1
            d1=$(date -d "$exp" +%s 2>/dev/null) || continue
            if [[ $(( (d1 - today) / 86400 )) -le 0 ]]; then
                sed -i "/^${marker} ${user} ${exp} /,/^},{/d" "$file"
                echo "Deleted ${marker} ${user} (exp ${exp}) dari ${file}"
                deleted_users+=("$user")
                [[ "$file" == "$TLS_FILE" ]] && restart_tls=1
                [[ "$file" == "$NONE_FILE" ]] && restart_none=1
            fi
        done < <(grep -w "^${marker} ${user}" "$file" | cut -d ' ' -f 3 | sort -u)
    done < <(grep "^${marker} " "$file" | cut -d ' ' -f 2 | sort -u)
}

#----- Auto Remove Vmess WS
clean_file "$TLS_FILE"  "#vms"
clean_file "$NONE_FILE" "#vms"

#----- Auto Remove Vless WS
clean_file "$TLS_FILE"  "#vls"
clean_file "$NONE_FILE" "#vls"

#----- Auto Remove Vless HTTPUpgrade
clean_file "$TLS_FILE"  "#vls-http"
clean_file "$NONE_FILE" "#vls-http"

#----- Auto Remove Vless XHTTP
clean_file "$TLS_FILE"  "#vls-xhttp"
clean_file "$NONE_FILE" "#vls-xhttp"

#----- Auto Remove Trojan WS
clean_file "$TLS_FILE"  "#trws"
clean_file "$NONE_FILE" "#trws"

#----- Auto Remove VLESS TCP XTLS
clean_file "$TLS_FILE" "#vxtls"

#----- Auto Remove Trojan TCP
clean_file "$XTR_FILE"  "###"
clean_file "$TLS_FILE"  "#trx"

#----- Buang fail config per-user sekali lalu
if [[ ${#deleted_users[@]} -gt 0 ]]; then
    printf '%s\n' "${deleted_users[@]}" | sort -u | while read -r u; do
        rm -f "/usr/local/etc/xray/${u}-tls.json"
        rm -f "/usr/local/etc/xray/${u}-none.json"
        rm -f "/usr/local/etc/xray/${u}-clash-for-android.yaml"
        rm -f "/home/vps/public_html/${u}-clash-for-android.yaml"
    done
fi

#----- Restart SEKALI sahaja kalau ada perubahan
[[ "$restart_tls"  -eq 1 ]] && systemctl restart xray@config
[[ "$restart_none" -eq 1 ]] && systemctl restart xray@none

echo -e " Delete Exp User Xray Success (NiLphreakz)"
echo
echo -e " Back To Menu In 5 Sec"
sleep 5
menu
