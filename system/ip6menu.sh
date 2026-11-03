#!/bin/bash
# =========================================
# IPv4 + IPv6 Toggle  (fixed)
# Asal: NevermoreSSH / NiLphreakz
# =========================================
# Pembaikan utama vs versi asal:
#   1. Tetapan DISIMPAN ke /etc/sysctl.d/ — kekal selepas reboot
#   2. Semakan root
#   3. Tiada lagi bergantung pada command `ip6menu` / `menu` dalam PATH
#   4. Pengesanan IPv4/IPv6 lebih tepat (guna `ip`, bukan `hostname -I`)
#   5. Toggle disable/enable tak lagi paksa reboot secara membuta
#   6. Selamat kalau kernel tak sokong IPv6
# =========================================

set -o pipefail

SYSCTL_FILE="${SYSCTL_FILE:-/etc/sysctl.d/99-ipv6-toggle.conf}"
SYSCTL_DIR="$(dirname "$SYSCTL_FILE")"

# Warna
line="38;5;208"
GREEN="\e[92m"
WHITE="\033[1;37m"
PINK="\e[38;5;205m"
back_text="1;37;44"
box="1;37"
text="1;37"
title="\e[30;107m"
number="\e[38;5;205"
below="0;37"
reset="\e[0m"
red="\e[91m"
yellow="\e[93m"

# ---------------- fungsi bantu ----------------
die() { echo -e "${red}$*${reset}" >&2; exit 1; }

need_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "Skrip ni kena jalan sebagai root. Guna: sudo bash $0"
    fi
}

ipv6_supported() {
    [[ -e /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]
}

# Baca nilai 1/0, kosongkan kalau tak wujud
read_sysctl() {
    cat "/proc/sys/net/ipv6/conf/$1/disable_ipv6" 2>/dev/null || true
}

# "Disabled" / "Enabled" / "Not supported" / "Partial"
ipv6_status() {
    if ! ipv6_supported; then
        echo "Not supported"
        return
    fi
    local a d
    a="$(read_sysctl all)"
    d="$(read_sysctl default)"
    if [[ "$a" == "1" && "$d" == "1" ]]; then
        echo "Disabled"
    elif [[ "$a" == "0" && "$d" == "0" ]]; then
        echo "Enabled"
    elif [[ -z "$a" && -z "$d" ]]; then
        echo "Not supported"
    else
        echo "Partial (all=${a:-?}, default=${d:-?})"
    fi
}

ipv4_addr() {
    local ip
    ip="$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{print $2; exit}')"
    ip="${ip%%/*}"
    [[ -n "$ip" ]] || ip="Not assigned"
    echo "$ip"
}

ipv6_global() {
    local ip
    ip="$(ip -6 addr show scope global 2>/dev/null | awk '/inet6 /{print $2; exit}')"
    ip="${ip%%/*}"
    [[ -n "$ip" ]] || ip="Not assigned"
    echo "$ip"
}

ipv6_linklocal() {
    local ip
    ip="$(ip -6 addr show scope link 2>/dev/null | awk '/inet6 /{print $2; exit}')"
    ip="${ip%%/*}"
    [[ -n "$ip" ]] || ip="None"
    echo "$ip"
}

# Tulis tetapan kekal ke /etc/sysctl.d/
persist_ipv6() {
    local val="$1"
    mkdir -p "$SYSCTL_DIR" 2>/dev/null || return 1
    if ! cat >"$SYSCTL_FILE" <<EOF
# Diurus oleh ip6menu — toggle IPv4/IPv6
# 1 = IPv6 dimatikan, 0 = IPv6 dihidupkan
net.ipv6.conf.all.disable_ipv6 = $val
net.ipv6.conf.default.disable_ipv6 = $val
EOF
    then
        return 1
    fi
    chmod 644 "$SYSCTL_FILE" 2>/dev/null || true
    sync_sysctl_conf "$val"
    # Muat semula semua fail sysctl.d supaya tetapan lain tak terlanggar
    sysctl --system >/dev/null 2>&1 || sysctl -p >/dev/null 2>&1 || true
    return 0
}

# /etc/sysctl.conf dibaca SELEPAS /etc/sysctl.d oleh systemd-sysctl.
# Kalau ada nilai lama kat situ, dia akan tumpangkan tetapan kita.
sync_sysctl_conf() {
    local val="$1" f=/etc/sysctl.conf tmp
    [[ -f "$f" ]] || return 0
    grep -qE '^[[:space:]]*#?[[:space:]]*net\.ipv6\.conf\.(all|default)\.disable_ipv6' "$f" || return 0
    cp -a "$f" "${f}.bak-ip6menu" 2>/dev/null || true
    tmp="$(mktemp)" || return 0
    grep -vE '^[[:space:]]*#?[[:space:]]*net\.ipv6\.conf\.(all|default)\.disable_ipv6' "$f" >"$tmp"
    {
        echo ""
        echo "# ip6menu"
        echo "net.ipv6.conf.all.disable_ipv6 = $val"
        echo "net.ipv6.conf.default.disable_ipv6 = $val"
    } >>"$tmp"
    cat "$tmp" >"$f"
    rm -f "$tmp"
}

# Apply serta-merta
apply_ipv6() {
    local val="$1" fail=0
    sysctl -w "net.ipv6.conf.all.disable_ipv6=$val" >/dev/null 2>&1 || fail=1
    sysctl -w "net.ipv6.conf.default.disable_ipv6=$val" >/dev/null 2>&1 || fail=1
    return "$fail"
}

pause() { read -r -p " Tekan Enter untuk teruskan..." _ || true; }

ask_reboot() {
    local ans
    read -r -p " Reboot sekarang? [y/N] : " ans || ans=""
    case "$ans" in
        y | Y | yes | YES) echo " Rebooting..."; sleep 1; reboot ;;
        *) echo " OK — tetapan dah disimpan. Reboot bila-bila masa." ;;
    esac
}

back_to_menu() {
    if command -v menu >/dev/null 2>&1; then
        exec menu
    fi
    if [[ -f /usr/local/bin/menu ]]; then
        exec /usr/local/bin/menu
    fi
    echo " (Menu induk tak dijumpai — keluar.)"
    exit 0
}

# ---------------- UI ----------------
draw_menu() {
    local st v4 v6g v6ll
    st="$(ipv6_status)"
    v4="$(ipv4_addr)"
    v6g="$(ipv6_global)"
    v6ll="$(ipv6_linklocal)"

    clear 2>/dev/null || true
    echo ""
    echo -e "\e[${line}m═══════════════════════════════════════════════${reset}"
    echo -e "\e[${title}        [ IP Menu - IPv4 / IPv6 Toggle ]       ${reset}"
    echo -e "\e[${line}m═══════════════════════════════════════════════${reset}
\033[1;37mIPv4v6 Changer By NiLphreakz\033[0m
\033[1;37mTelegram : https://t.me/NiLphreakz \033[0m"
    echo ""

    echo -e " IPv4 Address      : \033[1;32m$v4${reset}"
    echo -e " IPv6 Link-Local   : \033[1;36m$v6ll${reset}"
    echo -e " IPv6 Global       : \033[1;36m$v6g${reset}"
    if [[ "$st" == "Enabled" ]]; then
        echo -e " IPv6 Status       : \033[1;32m$st${reset}"
    elif [[ "$st" == "Disabled" ]]; then
        echo -e " IPv6 Status       : \033[1;31m$st${reset}"
    else
        echo -e " IPv6 Status       : \033[1;33m$st${reset}"
    fi
    echo -e " Tetapan kekal     : \033[0;37m$SYSCTL_FILE${reset}"
    echo ""

    echo -e " [\033[1;36m•1\033[0m]  \e[${below}mIPv4 Only (Disable IPv6)${reset}"
    echo -e " [\033[1;36m•2\033[0m]  \e[${below}mIPv4 + IPv6 (Enable IPv6)${reset}"
    echo -e " [\033[1;36m•3\033[0m]  \e[${below}mReboot Server${reset}"
    echo ""
    echo -e " [\033[1;36m•0\033[0m]  \e[${below}mBack To Menu${reset}"
    echo ""
    echo " Notes:"
    echo " - Tetapan disimpan kekal; tak perlu ulang selepas reboot."
    echo ""
    echo -e "\033[1;37mPress [ Ctrl+C ] • To Exit Script${reset}"
    echo ""
}

# ---------------- main ----------------
need_root

while true; do
    draw_menu
    read -r -p " Select menu : " opt || exit 0
    echo ""

    case "$opt" in
    1)
        if ! ipv6_supported; then
            echo -e "${yellow} Kernel ni tak sokong IPv6 — tiada apa nak dimatikan.${reset}"
            pause
            continue
        fi

        echo " Disabling IPv6..."
        if ! apply_ipv6 1; then
            echo -e "${red} Gagal apply sysctl. Mungkin VPS/container tak benarkan.${reset}"
            pause
            continue
        fi

        if persist_ipv6 1; then
            echo -e " ${GREEN}IPv6 dimatikan (runtime + kekal).${reset}"
        else
            echo -e " ${yellow}IPv6 dimatikan untuk sesi ni sahaja — gagal tulis $SYSCTL_FILE.${reset}"
            echo -e " ${yellow}Tetapan akan BALIK selepas reboot. Semak permission/disk.${reset}"
        fi

        echo " Status sekarang : $(ipv6_status)"
        echo ""
        ask_reboot
        ;;
    2)
        if ! ipv6_supported; then
            echo -e "${yellow} Kernel ni tak sokong IPv6 (tiada /proc/sys/net/ipv6).${reset}"
            pause
            continue
        fi

        echo " Enabling IPv6..."
        if ! apply_ipv6 0; then
            echo -e "${red} Gagal apply sysctl. Mungkin VPS/container tak benarkan.${reset}"
            pause
            continue
        fi

        if persist_ipv6 0; then
            echo -e " ${GREEN}IPv6 dihidupkan (runtime + kekal).${reset}"
        else
            echo -e " ${yellow}IPv6 dihidupkan untuk sesi ni sahaja — gagal tulis $SYSCTL_FILE.${reset}"
        fi

        echo " Status sekarang : $(ipv6_status)"
        echo -e " ${yellow}Nota: alamat IPv6 global mungkin hanya muncul selepas reboot${reset}"
        echo -e " ${yellow}atau restart network (netplan/systemd-networkd).${reset}"
        echo ""
        ask_reboot
        ;;
    3)
        echo -n " Pasti nak reboot sekarang? [y/N] : "
        read -r ans
        case "$ans" in
            y | Y | yes | YES) echo " Rebooting..."; sleep 1; reboot ;;
            *) echo " Dibatalkan."; sleep 1 ;;
        esac
        ;;
    0 | x | q)
        back_to_menu
        ;;
    *)
        echo -e "${red} Wrong Button${reset}"
        sleep 1
        ;;
    esac
done
