#!/bin/bash
# =========================================
# IPv4 + IPv6 Toggle  (v2 — persistence lasak)
# Asal: NevermoreSSH / NiLphreakz
# =========================================
# v2: tetapan tak lagi boleh ditumpangkan fail lain semasa boot.
#     1. sysctl.d guna nama yang DIISIH PALING AKHIR (99-zz-...)
#     2. systemd oneshot unit jalan SELEPAS systemd-sysctl
#     3. fallback OpenRC (/etc/local.d) & rc.local
#     4. apply ke SETIAP interface, bukan all/default sahaja
#     5. `--diag` untuk tunjuk fail mana yang tumpangkan tetapan
# =========================================

set -o pipefail

STATE_FILE="${STATE_FILE:-/etc/ipv6-toggle.state}"
SYSCTL_FILE="${SYSCTL_FILE:-/etc/sysctl.d/99-zz-ipv6-toggle.conf}"
HELPER="${HELPER:-/usr/local/sbin/ipv6-toggle-apply}"
UNIT="${UNIT:-/etc/systemd/system/ipv6-toggle.service}"
LOCALD="${LOCALD:-/etc/local.d/ipv6-toggle.start}"
RCLOCAL="${RCLOCAL:-/etc/rc.local}"

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
cyan="\e[96m"

die() { echo -e "${red}$*${reset}" >&2; exit 1; }
need_root() { [[ "${EUID}" -eq 0 ]] || die "Skrip ni kena jalan sebagai root. Guna: sudo bash $0"; }

# ---------------- pengesanan ----------------
ipv6_supported() { [[ -e /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]; }
read_sysctl() { cat "/proc/sys/net/ipv6/conf/$1/disable_ipv6" 2>/dev/null || true; }

ipv6_status() {
    local a d bad=0
    if ! ipv6_supported; then echo "Not supported"; return; fi
    a="$(read_sysctl all)"; d="$(read_sysctl default)"
    local f
    for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do
        [[ -e "$f" ]] || continue
        [[ "$(cat "$f" 2>/dev/null)" == "0" ]] || bad=1
    done
    if [[ "$a" == "1" && "$d" == "1" ]]; then
        echo "Disabled"
    elif [[ "$a" == "0" && "$d" == "0" && "$bad" == "0" ]]; then
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
    ip="${ip%%/*}"; [[ -n "$ip" ]] || ip="Not assigned"; echo "$ip"
}
ipv6_global() {
    local ip
    ip="$(ip -6 addr show scope global 2>/dev/null | awk '/inet6 /{print $2; exit}')"
    ip="${ip%%/*}"; [[ -n "$ip" ]] || ip="Not assigned"; echo "$ip"
}
ipv6_linklocal() {
    local ip
    ip="$(ip -6 addr show scope link 2>/dev/null | awk '/inet6 /{print $2; exit}')"
    ip="${ip%%/*}"; [[ -n "$ip" ]] || ip="None"; echo "$ip"
}

init_system() {
    if [[ -n "${INIT_SYSTEM:-}" ]]; then echo "$INIT_SYSTEM"; return; fi
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        echo systemd
    elif command -v rc-update >/dev/null 2>&1; then
        echo openrc
    elif [[ -f "$RCLOCAL" ]]; then
        echo sysv
    else
        echo unknown
    fi
}

# ---------------- tulis mekanisme kekal ----------------
write_state() {
    printf '%s\n' "$1" >"$STATE_FILE" || return 1
    chmod 644 "$STATE_FILE" 2>/dev/null || true
}

write_sysctl_file() {
    local val="$1"
    mkdir -p "$(dirname "$SYSCTL_FILE")" 2>/dev/null || return 1
    cat >"$SYSCTL_FILE" <<EOF || return 1
# Diurus oleh ip6menu — JANGAN ubah nama fail ni.
# Nama "99-zz-" dipilih supaya diisih SELEPAS 99-sysctl.conf (symlink ke
# /etc/sysctl.conf). Fail yang diisih kemudian akan menang.
# 1 = IPv6 dimatikan, 0 = IPv6 dihidupkan
net.ipv6.conf.all.disable_ipv6 = $val
net.ipv6.conf.default.disable_ipv6 = $val
EOF
    chmod 644 "$SYSCTL_FILE" 2>/dev/null || true
}

write_helper() {
    mkdir -p "$(dirname "$HELPER")" 2>/dev/null || return 1
    cat >"$HELPER" <<'EOF' || return 1
#!/bin/bash
# Diurus oleh ip6menu. Dipanggil oleh systemd / OpenRC semasa boot.
STATE="__STATE_FILE__"
val="$(cat "$STATE" 2>/dev/null || echo 0)"
[[ "$val" == "0" || "$val" == "1" ]] || val=0

# Jangan buat apa-apa kalau kernel tak sokong IPv6
[[ -e /proc/sys/net/ipv6/conf/all/disable_ipv6 ]] || exit 0

sysctl -w net.ipv6.conf.all.disable_ipv6="$val" >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6="$val" >/dev/null 2>&1

# Setiap interface (all/default tak override nilai per-interface sedia ada)
for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do
    [[ -e "$f" ]] || continue
    echo "$val" >"$f" 2>/dev/null
done
exit 0
EOF
    sed -i "s|__STATE_FILE__|$STATE_FILE|g" "$HELPER" 2>/dev/null || true
    chmod 755 "$HELPER" || return 1
}

write_systemd_unit() {
    [[ "$(init_system)" == "systemd" ]] || return 0
    cat >"$UNIT" <<EOF || return 1
[Unit]
Description=Apply IPv6 toggle state (ip6menu)
DefaultDependencies=no
After=systemd-sysctl.service local-fs.target
Before=network-pre.target shutdown.target
Wants=network-pre.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$HELPER

[Install]
WantedBy=sysinit.target
EOF
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable ipv6-toggle.service >/dev/null 2>&1 || true
}

write_openrc_local() {
    [[ "$(init_system)" == "openrc" ]] || return 0
    mkdir -p /etc/local.d 2>/dev/null || return 0
    cat >"$LOCALD" <<EOF
#!/bin/sh
$HELPER
EOF
    chmod 755 "$LOCALD"
    rc-update add local default >/dev/null 2>&1 || true
}

write_rclocal() {
    [[ -f "$RCLOCAL" ]] || return 0
    grep -qF "$HELPER" "$RCLOCAL" && return 0
    cp -a "$RCLOCAL" "${RCLOCAL}.bak-ip6menu" 2>/dev/null || true
    local tmp
    tmp="$(mktemp)" || return 0
    awk -v cmd="$HELPER" '
        BEGIN { done = 0 }
        /^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ && !done { print cmd; done = 1 }
        { print }
        END { if (!done) print cmd }
    ' "$RCLOCAL" >"$tmp" && cat "$tmp" >"$RCLOCAL"
    rm -f "$tmp"
    chmod 755 "$RCLOCAL" 2>/dev/null || true
}

# /etc/sysctl.conf dibaca selepas sysctl.d pada beberapa distro.
# Kalau dia ada nilai lama, tulis semula supaya konsisten.
sync_sysctl_conf() {
    local val="$1" f=/etc/sysctl.conf tmp
    [[ -f "$f" ]] || return 0
    grep -qE '^[[:space:]]*#?[[:space:]]*net\.ipv6\.conf\.(all|default)\.disable_ipv6[[:space:]]*=' "$f" || return 0
    cp -a "$f" "${f}.bak-ip6menu" 2>/dev/null || true
    tmp="$(mktemp)" || return 0
    grep -vE '^[[:space:]]*#?[[:space:]]*net\.ipv6\.conf\.(all|default)\.disable_ipv6[[:space:]]*=' "$f" >"$tmp"
    {
        echo ""
        echo "# ip6menu"
        echo "net.ipv6.conf.all.disable_ipv6 = $val"
        echo "net.ipv6.conf.default.disable_ipv6 = $val"
    } >>"$tmp"
    cat "$tmp" >"$f"
    rm -f "$tmp"
}

# Sama untuk 99-sysctl.conf kalau ia fail SALINAN (bukan symlink).
sync_sysctl_d_99() {
    local val="$1" f=/etc/sysctl.d/99-sysctl.conf
    [[ -f "$f" && ! -L "$f" ]] || return 0
    grep -qE '^[[:space:]]*#?[[:space:]]*net\.ipv6\.conf\.(all|default)\.disable_ipv6[[:space:]]*=' "$f" || return 0
    cp -a "$f" "${f}.bak-ip6menu" 2>/dev/null || true
    local tmp; tmp="$(mktemp)" || return 0
    grep -vE '^[[:space:]]*#?[[:space:]]*net\.ipv6\.conf\.(all|default)\.disable_ipv6[[:space:]]*=' "$f" >"$tmp"
    {
        echo ""
        echo "# ip6menu"
        echo "net.ipv6.conf.all.disable_ipv6 = $val"
        echo "net.ipv6.conf.default.disable_ipv6 = $val"
    } >>"$tmp"
    cat "$tmp" >"$f"
    rm -f "$tmp"
}

# ---------------- apply ----------------
apply_ipv6() {
    local val="$1" fail=0 f
    sysctl -w "net.ipv6.conf.all.disable_ipv6=$val" >/dev/null 2>&1 || fail=1
    sysctl -w "net.ipv6.conf.default.disable_ipv6=$val" >/dev/null 2>&1 || fail=1
    for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do
        [[ -e "$f" ]] || continue
        echo "$val" >"$f" 2>/dev/null || fail=1
    done
    return "$fail"
}

# Buang fail versi lama (nama 99-ipv6-toggle.conf) supaya tak mengelirukan
cleanup_legacy() {
    local old=/etc/sysctl.d/99-ipv6-toggle.conf
    [[ -f "$old" && "$old" != "$SYSCTL_FILE" ]] && rm -f "$old"
    return 0
}

persist_all() {
    local val="$1" rc=0
    cleanup_legacy
    write_state "$val" || rc=1
    write_sysctl_file "$val" || rc=1
    write_helper || rc=1
    write_systemd_unit || rc=1
    write_openrc_local || rc=1
    write_rclocal || rc=1
    sync_sysctl_conf "$val" || rc=1
    sync_sysctl_d_99 "$val" || rc=1
    sysctl --system >/dev/null 2>&1 || sysctl -p >/dev/null 2>&1 || true
    return "$rc"
}

# ---------------- diagnosa ----------------
do_diag() {
    local f
    echo -e "${cyan}=== 1. Nilai kernel sekarang ===${reset}"
    if ipv6_supported; then
        printf " all     = %s\n" "$(read_sysctl all)"
        printf " default = %s\n" "$(read_sysctl default)"
        echo " per-interface:"
        for f in /proc/sys/net/ipv6/conf/*/disable_ipv6; do
            [[ -e "$f" ]] || continue
            printf "   %-24s = %s\n" "$(basename "$(dirname "$f")")" "$(cat "$f" 2>/dev/null)"
        done
    else
        echo -e " ${red}/proc/sys/net/ipv6 tak wujud — IPv6 dimatikan pada peringkat kernel/GRUB.${reset}"
    fi

    echo ""
    echo -e "${cyan}=== 2. Fail sysctl yang set disable_ipv6 (ikut susunan load) ===${reset}"
    local found=0
    for f in \
        /usr/lib/sysctl.d/*.conf /run/sysctl.d/*.conf \
        /etc/sysctl.d/*.conf /etc/sysctl.conf; do
        [[ -f "$f" ]] || continue
        if grep -qE 'net\.ipv6\.conf\.[a-z0-9*]+\.disable_ipv6[[:space:]]*=' "$f" 2>/dev/null; then
            found=1
            local real="$f"
            [[ -L "$f" ]] && real="$f -> $(readlink -f "$f")"
            echo -e " ${yellow}$f${reset}  ($real)"
            grep -nE 'net\.ipv6\.conf\.[a-z0-9*]+\.disable_ipv6[[:space:]]*=' "$f" | sed 's/^/     /'
        fi
    done
    [[ "$found" -eq 0 ]] && echo " (tiada)"

    echo ""
    echo -e "${cyan}=== 3. Skrip boot lain ===${reset}"
    grep -ns 'disable_ipv6' /etc/rc.local /etc/local.d/* /etc/rc.d/rc.local 2>/dev/null | sed 's/^/ /' || echo " (tiada)"

    echo ""
    echo -e "${cyan}=== 4. systemd / OpenRC ===${reset}"
    echo " init: $(init_system)"
    command -v systemctl >/dev/null 2>&1 && {
        echo -n " ipv6-toggle.service : "
        systemctl is-enabled ipv6-toggle.service 2>/dev/null || echo "tidak didaftar"
        systemctl is-active ipv6-toggle.service 2>/dev/null || true
    }
    [[ -x "$LOCALD" ]] && echo " $LOCALD : ada"

    echo ""
    echo -e "${cyan}=== 5. GRUB / cmdline ===${reset}"
    grep -s 'ipv6.disable' /etc/default/grub /etc/default/grub.d/* 2>/dev/null | sed 's/^/ /' || echo " /etc/default/grub: tiada ipv6.disable"
    echo -n " /proc/cmdline: "; cat /proc/cmdline
    if tr ' ' '\n' </proc/cmdline 2>/dev/null | grep -qx 'ipv6.disable=1'; then
        echo -e " ${red}>>> KERNEL DIMATIKAN oleh ipv6.disable=1 — sysctl TIDAK akan berkesan.${reset}"
        echo -e " ${red}>>> Buang dari GRUB_CMDLINE_LINUX dan jalankan update-grub, lepas tu reboot.${reset}"
    fi

    echo ""
    echo -e "${cyan}=== 6. Status skrip ===${reset}"
    echo " state  : $(cat "$STATE_FILE" 2>/dev/null || echo 'tiada')"
    echo " sysctl : $SYSCTL_FILE $([[ -f "$SYSCTL_FILE" ]] && echo '(ada)' || echo '(TIADA)')"
    echo " helper : $HELPER $([[ -x "$HELPER" ]] && echo '(ada)' || echo '(TIADA)')"
    echo ""
    echo -e "${cyan}=== 7. Interface & route IPv6 ===${reset}"
    ip -6 addr show scope global 2>/dev/null | sed 's/^/ /' || true
    ip -6 route 2>/dev/null | head -5 | sed 's/^/ /' || true
}

# ---------------- UI ----------------
pause() { read -r -p " Tekan Enter untuk teruskan..." _ || true; }

ask_reboot() {
    local ans
    read -r -p " Reboot sekarang? [y/N] : " ans || ans=""
    case "$ans" in
        y | Y | yes | YES) echo " Rebooting..."; sleep 1; reboot ;;
        *) echo " OK — tetapan dah disimpan." ;;
    esac
}

back_to_menu() {
    if command -v menu >/dev/null 2>&1; then exec menu; fi
    if [[ -f /usr/local/bin/menu ]]; then exec /usr/local/bin/menu; fi
    echo " (Menu induk tak dijumpai — keluar.)"
    exit 0
}

draw_menu() {
    local st v4 v6g v6ll
    st="$(ipv6_status)"; v4="$(ipv4_addr)"; v6g="$(ipv6_global)"; v6ll="$(ipv6_linklocal)"

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
    echo -e " [\033[1;36m•3\033[0m]  \e[${below}mDiagnose (semak kenapa tak kekal)${reset}"
    echo -e " [\033[1;36m•4\033[0m]  \e[${below}mReboot Server${reset}"
    echo ""
    echo -e " [\033[1;36m•0\033[0m]  \e[${below}mBack To Menu${reset}"
    echo ""
    echo -e "\033[1;37mPress [ Ctrl+C ] • To Exit Script${reset}"
    echo ""
}

# ---------------- main ----------------
if [[ "${1:-}" == "--diag" || "${1:-}" == "-d" ]]; then
    do_diag
    exit 0
fi

need_root
if ! ipv6_supported; then
    echo -e "${yellow} Amaran: /proc/sys/net/ipv6 tak wujud — IPv6 dimatikan pada peringkat kernel.${reset}"
    echo -e "${yellow} Semak: grep -r ipv6.disable /etc/default/grub ; cat /proc/cmdline${reset}"
    echo ""
fi

while true; do
    draw_menu
    read -r -p " Select menu : " opt || exit 0
    echo ""

    case "$opt" in
    1)
        echo " Disabling IPv6..."
        if ! apply_ipv6 1; then
            echo -e "${red} Gagal apply sysctl sekarang (container/VPS tak benarkan?).${reset}"
            pause; continue
        fi
        if persist_all 1; then
            echo -e " ${GREEN}IPv6 dimatikan — runtime + kekal selepas reboot.${reset}"
        else
            echo -e "${yellow} Runtime OK, tapi ada bahagian persistence gagal ditulis.${reset}"
            echo -e "${yellow} Jalankan menu 3 (Diagnose) dan hantar output.${reset}"
        fi
        echo " Status sekarang : $(ipv6_status)"
        echo ""; ask_reboot
        ;;
    2)
        echo " Enabling IPv6..."
        if ! apply_ipv6 0; then
            echo -e "${red} Gagal apply sysctl sekarang.${reset}"
            pause; continue
        fi
        if persist_all 0; then
            echo -e " ${GREEN}IPv6 dihidupkan — runtime + kekal selepas reboot.${reset}"
        else
            echo -e "${yellow} Runtime OK, tapi ada bahagian persistence gagal ditulis.${reset}"
            echo -e "${yellow} Jalankan menu 3 (Diagnose) dan hantar output.${reset}"
        fi
        echo " Status sekarang : $(ipv6_status)"
        echo -e " ${yellow}Alamat global mungkin hanya muncul selepas reboot (>RA/DHCPv6).${reset}"
        echo ""; ask_reboot
        ;;
    3)
        clear
        do_diag
        echo ""
        pause
        ;;
    4)
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
