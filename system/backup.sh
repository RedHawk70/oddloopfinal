#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NiLphreakz
# (C) Copyright 2022
# Auto-detect rclone remotes edition
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

# =========================================
# Auto-detect setiap remote dalam rclone.conf
# =========================================
command -v rclone >/dev/null 2>&1 || { echo "rclone tidak dipasang." >&2; exit 1; }

conf_file="${RCLONE_CONFIG:-$HOME/.config/rclone/rclone.conf}"
if [[ ! -r "$conf_file" ]]; then
    conf_file=$(rclone config file 2>/dev/null \
        | sed -n 's/^Configuration file is stored at:[[:space:]]*//p' \
        | head -n 1)
fi
[[ -n "$conf_file" && -r "$conf_file" ]] || {
    echo "rclone.conf tidak dijumpai. Jalankan: rclone config" >&2
    exit 1
}

# Baca [nama remote] dan baris "type = ..." daripada fail konfigurasi.
# Hasil: satu baris "nama<TAB>jenis" bagi setiap remote yang lengkap.
REMOTES=()
while IFS=$'\t' read -r r_name r_type; do
    [[ -n "$r_name" && -n "$r_type" ]] && REMOTES+=("$r_name|$r_type")
done < <(awk '
    /^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
        if (name != "" && type != "") print name "\t" type
        name = $0
        sub(/^[[:space:]]*\[/, "", name)
        sub(/\][[:space:]]*$/, "", name)
        type = ""
        next
    }
    /^[[:space:]]*type[[:space:]]*=/ {
        line = $0
        sub(/^[^=]*=[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line)
        type = line
    }
    END { if (name != "" && type != "") print name "\t" type }
' "$conf_file")

# Remote yang ditakrifkan melalui pemboleh ubah persekitaran (RCLONE_CONFIG_*)
# tidak berada dalam fail konfigurasi; tambah sebagai 'unknown' jika ada.
while IFS= read -r lr; do
    lr="${lr%:}"
    [[ -n "$lr" ]] || continue
    found=0
    for entry in "${REMOTES[@]}"; do
        [[ "${entry%%|*}" == "$lr" ]] && { found=1; break; }
    done
    [[ $found -eq 1 ]] || REMOTES+=("$lr|unknown")
done < <(rclone listremotes 2>/dev/null)

if [[ ${#REMOTES[@]} -eq 0 ]]; then
    echo "Tiada remote dijumpai dalam $conf_file. Jalankan: rclone config" >&2
    exit 1
fi

remote_label() {
    case "$1" in
        drive)          echo "Google Drive" ;;
        onedrive)       echo "OneDrive" ;;
        dropbox)        echo "Dropbox" ;;
        mega)           echo "MEGA" ;;
        gphotos)        echo "Google Photos" ;;
        s3)             echo "Amazon S3" ;;
        b2)             echo "Backblaze B2" ;;
        box)            echo "Box" ;;
        pcloud)         echo "pCloud" ;;
        yandex)         echo "Yandex Disk" ;;
        ftp|sftp)       echo "${1^^}" ;;
        webdav)         echo "WebDAV" ;;
        crypt)          echo "Crypt" ;;
        alias)          echo "Alias" ;;
        *)              echo "Remote" ;;
    esac
}

args=()
[[ "${BACKUP_DRY_RUN:-0}" == "1" ]] && args+=(--dry-run)
# Folder tujuan pada setiap remote. Tukar jika mahu guna folder lain.
BACKUP_DIR="${BACKUP_DIR:-backup}"
# Simpan hanya backup yang lebih muda daripada tempoh ini (contoh: 24h, 48h, 7d).
RETENTION="${RETENTION:-24h}"
# Hanya fail yang sepadan corak ini dipadam, supaya fail lain dalam folder tidak tersentuh.
if [[ -z "${CLEAN_INCLUDE:-}" ]]; then
    archive_suffix="${archive#*-$date-}"
    if [[ -n "$archive_suffix" && "$archive_suffix" != "$archive" ]]; then
        CLEAN_INCLUDE="*-$archive_suffix"
    else
        CLEAN_INCLUDE="*oddloop.zip"
    fi
    # Pastikan corak sentiasa sepadan dengan arkib baru; jika tidak, guna corak umum.
    case "$archive" in
        $CLEAN_INCLUDE) ;;
        *) CLEAN_INCLUDE="*-oddloop.zip" ;;
    esac
fi

echo -e "[ ${green}INFO${NC} ] Remote dijumpai: ${#REMOTES[@]} (${conf_file})"
uploaded=()
failed=()

for entry in "${REMOTES[@]}"; do
    r_name="${entry%%|*}"
    r_type="${entry#*|}"
    label=$(remote_label "$r_type")

    # Tolak nama remote yang mengandungi aksara tidak selamat untuk shell/path.
    if [[ ! "$r_name" =~ ^[A-Za-z0-9._@+-]+$ ]]; then
        echo -e "[ ${orange}SKIP${NC} ] Nama remote '$r_name' tidak sah, dilangkau."
        continue
    fi

    echo -e "[ ${green}INFO${NC} ] Upload backup ke $label ($r_name:backup/) . . . "
    if rclone copy "$workdir/$archive" "$r_name:$BACKUP_DIR/" "${args[@]}"; then
        uploaded+=("$r_name|$r_type")
        # Padam backup lama pada remote ini SELEPAS upload berjaya,
        # supaya backup lama kekal jika upload gagal.
        # Guna --filter (bukan --include/--exclude) supaya susunan peraturan
        # deterministik: arkib baru dikecualikan dahulu, kemudian corak backup,
        # dan semua fail lain dikecualikan.
        if rclone delete "$r_name:$BACKUP_DIR" --min-age "$RETENTION" \
            --filter "- $archive" \
            --filter "+ $CLEAN_INCLUDE" \
            --filter "- **" "${args[@]}"; then
            echo -e "[ ${green}OK${NC} ] Backup lama (> $RETENTION) pada $label dibersihkan."
        else
            echo -e "[ ${orange}AMARAN${NC} ] Gagal padam backup lama pada $label ($r_name:)."
        fi
    else
        echo -e "[ ${red}GAGAL${NC} ] Upload ke $label ($r_name:) gagal."
        failed+=("$r_name|$r_type")
    fi
done

if [[ ${#uploaded[@]} -eq 0 ]]; then
    echo "Tiada satu pun upload berjaya." >&2
    exit 1
fi

# Jana pautan perkongsian ikut jenis backend. Jika backend tidak menyokong
# pautan awam atau akaun menyekat perkongsian, path rclone tetap dipaparkan.
make_link() {
    local remote="$1" type="$2" link
    link=$(rclone link "$remote:$BACKUP_DIR/$archive" 2>/dev/null || true)
    case "$type" in
        drive)
            if [[ "$link" =~ [\?\&]id=([a-zA-Z0-9_-]+) || "$link" =~ drive\.google\.com/file/d/([a-zA-Z0-9_-]+) ]]; then
                link="https://drive.google.com/uc?id=${BASH_REMATCH[1]}&export=download"
            fi
            ;;
        onedrive)
            if [[ -n "$link" ]]; then
                if [[ "$link" == *"?"* ]]; then
                    [[ "$link" == *"download="* ]] || link="${link}&download=1"
                else
                    link="${link}?download=1"
                fi
            fi
            ;;
        dropbox)
            if [[ -n "$link" && "$link" == *dropbox.com* ]]; then
                if [[ "$link" == *"?dl="* || "$link" == *"&dl="* ]]; then
                    link="${link//dl=0/dl=1}"
                elif [[ "$link" == *"?"* ]]; then
                    link="${link}&dl=1"
                else
                    link="${link}?dl=1"
                fi
            fi
            ;;
    esac
    printf '%s' "$link"
}

clear
echo -e "\\033[1;37mVPS Data Backup By NiLphreakz\\033[0m
\\033[1;37mTelegram : https://t.me/NiLphreakz / @NiLphreakz\\033[0m"
echo ""
echo -e "Your VPS IP ( \\033[1;37m$IP\\033[0m )"

for entry in "${uploaded[@]}"; do
    r_name="${entry%%|*}"
    r_type="${entry#*|}"
    label=$(remote_label "$r_type")
    link=$(make_link "$r_name" "$r_type")

    echo ""
    echo "$label:"
    if [[ -n "$link" ]]; then
        echo "$link"
    else
        echo "Pautan gagal dijana. Gunakan path Rclone."
    fi
    echo "Path Rclone: $r_name:$BACKUP_DIR/$archive"
done

if [[ ${#failed[@]} -gt 0 ]]; then
    echo ""
    echo -e "${red}Remote yang gagal:${NC}"
    for entry in "${failed[@]}"; do
        r_name="${entry%%|*}"
        r_type="${entry#*|}"
        echo "- $(remote_label "$r_type") ($r_name:)"
    done
fi

echo ""
echo "Nota: Pautan perkongsian mesti boleh diakses oleh sesiapa yang mempunyai pautan."
echo "Jika pautan sesuatu cloud gagal dijana, gunakan path rclone yang dipaparkan."
echo "Nota MEGA: untuk restore paling stabil, gunakan path mega:$BACKUP_DIR/nama-fail.zip."
echo "Retensi: fail '$CLEAN_INCLUDE' lebih tua daripada $RETENTION dipadam setiap kali backup."
echo "Tukar tempoh: RETENTION=48h bash $0 | Tukar folder: BACKUP_DIR=backup-vps bash $0"
echo "Untuk ujian tanpa muat naik sebenar: BACKUP_DRY_RUN=1 bash $0"
echo ""
