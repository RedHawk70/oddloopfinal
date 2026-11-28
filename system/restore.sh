#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NiLphreakz
# (C) Copyright 2022
# =========================================
# PROVIDED
creditt=$(cat /root/provided 2>/dev/null || true)
# BANNER COLOUR
banner_colour=$(cat /etc/banner 2>/dev/null || true)
# TEXT ON BOX COLOUR
box=$(cat /etc/box 2>/dev/null || true)
# LINE COLOUR
line=$(cat /etc/line 2>/dev/null || true)
# TEXT COLOUR ON TOP
text=$(cat /etc/text 2>/dev/null || true)
# TEXT COLOUR BELOW
below=$(cat /etc/below 2>/dev/null || true)
# BACKGROUND TEXT COLOUR
back_text=$(cat /etc/back 2>/dev/null || true)
# NUMBER COLOUR
number=$(cat /etc/number 2>/dev/null || true)

red='\e[1;31m'
green='\e[0;32m'
purple='\e[0;35m'
orange='\e[0;33m'
NC='\e[0m'
TERM=${TERM:-xterm}
export TERM
clear 2>/dev/null || true
echo ""
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo -e   "  \e[$back_text            \e[30m[\e[$box RESTORE SSH & XRAY ACCOUNT \e[30m ]\e[1m            \e[m"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo ""
echo " This Feature Can Only Be Used According To VPS Data With This Autoscript"
echo " Please Insert VPS Data Backup Link To Restore The Data"
echo ""
#read -rp " Password File: " -e InputPass
command -v unzip >/dev/null 2>&1 || { echo "unzip tidak dipasang. Pasang dengan: apt install unzip" >&2; exit 1; }
read -rp "Link Google Drive/OneDrive/Dropbox/MEGA atau path remote (cth. dr:backup/fail.zip): " -e url
url="${url#"${url%%[![:space:]]*}"}"
url="${url%"${url##*[![:space:]]}"}"
[[ -n "$url" ]] || { echo "Tiada pautan/path dimasukkan. Restore dibatalkan." >&2; exit 1; }
umask 077
workdir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$workdir"' EXIT
# Terima mana-mana remote yang benar-benar wujud dalam rclone.conf,
# bukan hanya od:/dbx:/mega: (selaras dengan skrip backup yang auto-detect).
is_rclone_path() {
    local value="$1" name
    [[ "$value" == *:* ]] || return 1
    [[ "$value" == http://* || "$value" == https://* ]] && return 1
    name="${value%%:*}"
    [[ -n "$name" ]] || return 1
    command -v rclone >/dev/null 2>&1 || return 1
    rclone listremotes 2>/dev/null | sed 's/:$//' | grep -Fxq -- "$name"
}

if is_rclone_path "$url"; then
    command -v rclone >/dev/null 2>&1 || { echo "Rclone tidak dipasang." >&2; exit 1; }
    echo -e "[ ${green}INFO${NC} ] Download backup daripada remote rclone (${url%%:}) . . . "
    rclone copyto "$url" "$workdir/backup.zip" || { echo "Gagal memuat turun backup daripada storan awan." >&2; exit 1; }
else
    echo -e "[ ${green}INFO${NC} ] Download backup daripada pautan perkongsian . . . "
    command -v rclone >/dev/null 2>&1 || { echo "Rclone tidak dipasang." >&2; exit 1; }
    if [[ "$url" == *"1drv.ms"* || "$url" == *"onedrive.live.com"* || "$url" == *"sharepoint.com"* ]]; then
        # OneDrive Personal: pautan perkongsian 1drv.ms boleh memerlukan header pelayar
        # dan cookie redirect. Cuba beberapa kaedah, kemudian sahkan ZIP sebelum restore.
        command -v curl >/dev/null 2>&1 || { echo "curl tidak dipasang. Pasang dengan: apt install curl" >&2; exit 1; }
        onedrive_url="$url"
        if [[ "$onedrive_url" == *"?"* ]]; then
            [[ "$onedrive_url" == *"download="* ]] || onedrive_url="${onedrive_url}&download=1"
        else
            onedrive_url="${onedrive_url}?download=1"
        fi
        rm -f "$workdir/backup.zip" "$workdir/onedrive.cookies"
        echo "[ INFO ] Cuba muat turun OneDrive dengan redirect biasa..."
        curl -fLsS --retry 1 --connect-timeout 20 --max-time 600 \
            -A 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36' \
            -e 'https://onedrive.live.com/' -c "$workdir/onedrive.cookies" \
            -b "$workdir/onedrive.cookies" "$onedrive_url" -o "$workdir/backup.zip" || true
        if ! unzip -tq "$workdir/backup.zip" >/dev/null 2>&1; then
            rm -f "$workdir/backup.zip"
            echo "[ INFO ] Cuba semula dengan sesi cookie OneDrive..."
            curl -sS -L --retry 1 --connect-timeout 20 --max-time 600 \
                -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36' \
                -H 'Accept: */*' -H 'Accept-Language: en-US,en;q=0.9' \
                -e 'https://onedrive.live.com/' -c "$workdir/onedrive.cookies" \
                -b "$workdir/onedrive.cookies" "$onedrive_url" -o "$workdir/backup.zip" || true
        fi
        if ! unzip -tq "$workdir/backup.zip" >/dev/null 2>&1; then
            echo "Muat turun pautan OneDrive gagal atau respons bukan fail ZIP." >&2
            echo "Pautan mungkin memerlukan pengesahan tambahan Microsoft atau format share link yang tidak serasi dengan muat turun terus." >&2
            echo "Sebagai pilihan sementara, gunakan path remote od:backup/nama-fail.zip." >&2
            exit 1
        fi
    elif [[ "$url" == *mega.nz* || "$url" == *mega.co.nz* ]]; then
        # MEGA share links carry the decryption key in the URL fragment.
        # megatools understands both legacy (#!) and current (/file/...#) links.
        if ! command -v megatools >/dev/null 2>&1; then
            echo "Alat megatools belum dipasang. Pasang dahulu dengan arahan:" >&2
            echo "apt-get update && apt-get install -y megatools" >&2
            exit 1
        fi
        echo "[ INFO ] Muat turun dan nyahsulit fail daripada pautan MEGA..."
        if ! megatools dl --no-progress --path "$workdir" "$url"; then
            echo "Muat turun pautan MEGA gagal. Pastikan pautan lengkap termasuk kunci selepas tanda # dan fail boleh diakses umum." >&2
            exit 1
        fi
        # megatools preserves the original shared filename; locate the ZIP safely.
        mega_zip=""
        while IFS= read -r -d '' candidate; do
            if unzip -tq "$candidate" >/dev/null 2>&1; then
                mega_zip="$candidate"
                break
            fi
        done < <(find "$workdir" -maxdepth 1 -type f -name '*.zip' -print0)
        if [[ -z "$mega_zip" ]]; then
            echo "Fail yang dimuat turun daripada MEGA bukan ZIP yang sah atau tiada fail ZIP ditemui." >&2
            exit 1
        fi
        cp -- "$mega_zip" "$workdir/backup.zip" || exit 1
    elif [[ "$url" == *dropbox.com* ]]; then
        if [[ "$url" == *"?dl="* || "$url" == *"&dl="* ]]; then
            url="${url//dl=0/dl=1}"
        elif [[ "$url" == *"?"* ]]; then
            url="${url}&dl=1"
        else
            url="${url}?dl=1"
        fi
        rclone copyurl "$url" "$workdir/backup.zip" || {
            echo "Muat turun Dropbox gagal. Pastikan pautan perkongsian aktif." >&2
            exit 1
        }
    else
        # Google Drive: URL terus /export=download.
        rclone copyurl "$url" "$workdir/backup.zip" 2>/dev/null || true
        if ! unzip -tq "$workdir/backup.zip" >/dev/null 2>&1; then
            # Fail besar melalui 'uc?export=download' memerlukan pengesahan.
            gid=$(printf '%s' "$url" | sed -n 's/.*[?&]id=\([A-Za-z0-9_-]\{10,\}\).*/\1/p')
            [[ -n "$gid" ]] || gid=$(printf '%s' "$url" | sed -n 's|.*/file/d/\([A-Za-z0-9_-]\{10,\}\).*|\1|p')
            if [[ -n "$gid" ]] && command -v curl >/dev/null 2>&1; then
                echo "[ INFO ] Cuba semula melalui endpoint muat turun Google Drive..."
                curl -fLsS --retry 2 --connect-timeout 20 --max-time 900 \
                    "https://drive.usercontent.google.com/download?id=$gid&export=download&confirm=t" \
                    -o "$workdir/backup.zip" || true
            fi
        fi
        if ! unzip -tq "$workdir/backup.zip" >/dev/null 2>&1; then
            echo "Muat turun Google Drive gagal. Pastikan pautan perkongsian aktif dan fail boleh diakses umum." >&2
            exit 1
        fi
    fi
fi
[[ -s "$workdir/backup.zip" ]] || { echo "Fail backup kosong atau tidak dijumpai." >&2; exit 1; }
unzip -tq "$workdir/backup.zip" >/dev/null 2>&1 || { echo "Fail yang dimuat turun bukan ZIP yang sah. Restore dibatalkan." >&2; exit 1; }
# Halang zip-slip: entri '../' atau laluan mutlak tidak dibenarkan.
if unzip -Z1 "$workdir/backup.zip" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    echo "Arkib backup mengandungi laluan tidak selamat. Restore dibatalkan." >&2
    exit 1
fi
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
if [[ -d "$backup_dir/public_html" ]]; then
    mkdir -p /home/vps || exit 1
    cp -a "$backup_dir/public_html/." /home/vps/public_html/ || exit 1
fi
echo ""
echo -e "[ ${green}INFO${NC} ] VPS Data Restore Complete !"
echo ""
echo -e "[ ${green}INFO${NC} ] Back to menu . . . "
for svc in nginx xray.service xray@none.service xray@vless.service \
           xray@vnone.service xray@trojanws.service xray@trnone.service \
           xray@xtrojan.service xray@trojan.service; do
    systemctl restart "$svc" >/dev/null 2>&1 || true
done
service cron restart >/dev/null 2>&1 || true
sleep 5
command -v system >/dev/null 2>&1 && system
clear
