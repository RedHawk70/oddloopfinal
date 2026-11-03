#!/bin/bash
# ============================================================
#  Installer xraay-bot — Menu & Bot Telegram CONFIG LIST
# ------------------------------------------------------------
#  LALAI: pasang MENU SAHAJA (bot tak dipasang, service tak jalan)
#
#    bash <(wget -qO- https://raw.githubusercontent.com/RedHawk70/oddloopfinal/main/bot-menu/install.sh)
#
#  Selepas itu jalankan:  xraay-bot-menu  → pilih [1] untuk pasang bot.
#
#  Pilihan:
#    --menu-only   pasang menu sahaja (lalai)
#    --with-bot    pasang menu + bot sekali gus
#    --uninstall   buang menu & bot
#
#  Automasi:
#    BOT_TOKEN=xxx BOT_RAW=...   pasang bot tanpa tanya token
#    XRAY_BOT_RAW=...            ganti URL sumber (fork sendiri)
# ============================================================
set -uo pipefail

RAW_BASE="${XRAY_BOT_RAW:-https://raw.githubusercontent.com/RedHawk70/oddloopfinal/main/bot-menu}"

BOT_BIN="${XRAY_BOT_BIN:-/usr/local/bin/xraay-bot}"
MENU_BIN="${XRAY_BOT_MENUBIN:-/usr/local/bin/xraay-bot-menu}"
CONF_DIR="${XRAY_BOT_CONFDIR:-/etc/xraay-bot}"
CONF_FILE="$CONF_DIR/config.json"
UNIT="${XRAY_BOT_UNIT:-/etc/systemd/system/xraay-bot.service}"
SERVICE="${XRAY_BOT_SERVICE:-xraay-bot}"

c_green='\e[32m'; c_red='\e[31m'; c_cyan='\e[36m'; c_yellow='\e[33m'; c_reset='\e[0m'
info() { echo -e "${c_cyan}[*]${c_reset} $*"; }
ok()   { echo -e "${c_green}[✓]${c_reset} $*"; }
warn() { echo -e "${c_yellow}[!]${c_reset} $*"; }
err()  { echo -e "${c_red}[x]${c_reset} $*" >&2; }

[ "$(id -u)" -eq 0 ] || { err "Kena run sebagai root."; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo /tmp)"
[ -d "$HERE" ] || HERE="/tmp"

MODE="menu"
for arg in "$@"; do
    case "$arg" in
        --menu-only) MODE="menu" ;;
        --with-bot|--bot) MODE="bot" ;;
        --uninstall) MODE="uninstall" ;;
        -h|--help)
            sed -n '3,22p' "$0" 2>/dev/null || echo "Guna: install.sh [--menu-only|--with-bot|--uninstall]"
            exit 0 ;;
    esac
done

# ---------------- UNINSTALL ----------------
if [ "$MODE" = "uninstall" ]; then
    info "Membuang xraay-bot..."
    systemctl stop "$SERVICE" 2>/dev/null || true
    systemctl disable "$SERVICE" 2>/dev/null || true
    rm -f "$UNIT" "$BOT_BIN" "$MENU_BIN"
    systemctl daemon-reload 2>/dev/null || true
    read -rp "Buang juga config ($CONF_FILE)? [y/N] : " ans || true
    [[ "${ans,,}" == "y" ]] && rm -rf "$CONF_DIR"
    ok "Selesai. Menu & bot telah dibuang."
    exit 0
fi

# ---------------- UTIL ----------------
fetch() {   # fetch <url> <dest>
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 --connect-timeout 10 --max-time 60 "$url" -o "$dest" 2>/dev/null && [ -s "$dest" ] && return 0
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" --tries=3 --timeout=20 "$url" 2>/dev/null && [ -s "$dest" ] && return 0
    fi
    rm -f "$dest"
    return 1
}

valid_py() {
    [ -f "$1" ] && python3 -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$1" 2>/dev/null
}
valid_sh() { [ -f "$1" ] && bash -n "$1" 2>/dev/null; }

fail_download() {
    err "Gagal muat turun: $1"
    echo ""
    echo "  Semak:"
    echo "    1. Fail dah di-upload ke GitHub? (branch 'main', folder 'bot-menu')"
    echo "    2. URL betul: ${RAW_BASE}/$1"
    echo "    3. Server ada internet?  curl -I https://raw.githubusercontent.com"
    echo ""
    echo "  Guna cara manual:"
    echo "    unzip xraay-bot.zip && cd xraay-bot && bash install.sh"
}

SRC_DIR=""
prepare_src() {   # prepare_src <fail...>
    if valid_sh "$HERE/menu.sh" || valid_py "$HERE/bot.py"; then
        SRC_DIR="$HERE"
        ok "Sumber: folder tempatan ($HERE)"
        return 0
    fi

    info "Memuat turun dari GitHub..."
    info "  $RAW_BASE"
    SRC_DIR="$(mktemp -d /tmp/xraay-bot.XXXXXX)"
    local f
    for f in "$@"; do
        if fetch "$RAW_BASE/$f" "$SRC_DIR/$f"; then
            ok "  $f"
        else
            fail_download "$f"
            rm -rf "$SRC_DIR"
            return 1
        fi
    done
    return 0
}

# ---------------- PYTHON ----------------
if ! command -v python3 >/dev/null 2>&1; then
    info "python3 tiada, memasang..."
    if command -v apt-get >/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q python3
    else
        err "python3 tiada dan tiada package manager dikenali."; exit 1
    fi
fi

# ============================================================
#  MOD MENU — pasang menu sahaja
# ============================================================
install_menu() {
    prepare_src menu.sh || exit 1
    if ! valid_sh "$SRC_DIR/menu.sh"; then
        err "menu.sh rosak / bukan skrip bash yang sah."
        [[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"
        exit 1
    fi
    mkdir -p "$(dirname "$MENU_BIN")"
    if ! install -m 755 "$SRC_DIR/menu.sh" "$MENU_BIN"; then
        err "Gagal memasang menu ke $MENU_BIN"
        [[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"
        exit 1
    fi
    ok "Menu dipasang: $MENU_BIN"
    [[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"
}

if [ "$MODE" = "menu" ]; then
    install_menu

    echo ""
    echo -e "${c_green}══════════════════════════════════════════════${c_reset}"
    echo "  Menu urus dah sedia. Bot BELUM dipasang."
    echo ""
    echo "    xraay-bot-menu"
    echo ""
    echo "  Dalam menu, pilih:"
    echo "    [1] Install / Update bot   ← pasang bot bila dah ready"
    echo "    [2] Set / Tukar token bot"
    echo -e "${c_green}══════════════════════════════════════════════${c_reset}"

    # kalau dijalankan secara interactive, tawarkan pasang bot terus
    if [ -t 0 ]; then
        echo ""
        read -rp "  Pasang bot sekarang juga? [y/N] : " jawab || true
        if [[ "${jawab,,}" == "y" ]]; then
            MODE="bot"
        else
            echo ""
            info "Selesai. Jalankan 'xraay-bot-menu' bila nak pasang bot."
            exit 0
        fi
    else
        exit 0
    fi
fi

# ============================================================
#  MOD BOT — pasang menu + bot + service
# ============================================================
prepare_src bot.py menu.sh config.example.json || exit 1

if ! valid_py "$SRC_DIR/bot.py"; then
    err "bot.py rosak / bukan fail Python yang sah."
    echo "  (Biasanya fail belum di-upload — GitHub pulangkan 404.)"
    [[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"
    exit 1
fi

[ -d /etc/xray/configlist ] || warn "Amaran: /etc/xray/configlist belum wujud (bot akan papar 'tiada config')."
[ -f /root/log-install.txt ] || warn "Amaran: /root/log-install.txt tak jumpa — port lalai 443/80 digunakan."

# ---- config ----
mkdir -p "$CONF_DIR"

if [ -f "$CONF_FILE" ]; then
    info "Config sedia ada dikekalkan (backup dibuat)."
    cp -a "$CONF_FILE" "$CONF_FILE.bak.$(date +%s)"
else
    [ -f "$SRC_DIR/config.example.json" ] && cp "$SRC_DIR/config.example.json" "$CONF_FILE"
    if [ ! -f "$CONF_FILE" ]; then
        cat > "$CONF_FILE" <<'JSON'
{
  "bot_token": "",
  "allowed_chat_ids": [],
  "admin_ids": [],
  "configlist_dir": "/etc/xray/configlist",
  "xray_configs": ["/usr/local/etc/xray/config.json", "/usr/local/etc/xray/none.json"],
  "log_install": "/root/log-install.txt",
  "fragment_style": "name",
  "display_server_tag": false,
  "note_file": "/var/lib/xraay-bot/note.txt",
  "note_max_len": 800,
  "config_note_file": "/var/lib/xraay-bot/config-notes.json",
  "poll_timeout": 50,
  "ports": {"ws_tls": "443", "ws_none": "80", "hu_tls": "443", "hu_none": "80", "xhttp_tls": "443", "xhttp_none": "80"}
}
JSON
    fi

    TOKEN="${BOT_TOKEN:-}"
    if [ -z "$TOKEN" ]; then
        echo ""
        echo -e "   ${c_cyan}Token bot dari @BotFather${c_reset} (kosong = isi kemudian):"
        read -rp "   Token : " TOKEN || true
    fi
    if [ -n "$TOKEN" ]; then
        python3 - "$CONF_FILE" "$TOKEN" <<'PY'
import json, sys
p, t = sys.argv[1], sys.argv[2].strip()
c = json.load(open(p, encoding="utf-8"))
c["bot_token"] = t
json.dump(c, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
        ok "Token disimpan."
    else
        warn "Token kosong — isi melalui: xraay-bot-menu → [2]"
    fi
fi
chmod 600 "$CONF_FILE"
ok "Config: $CONF_FILE"

# ---- binari + menu ----
mkdir -p "$(dirname "$BOT_BIN")"
if ! install -m 755 "$SRC_DIR/bot.py" "$BOT_BIN"; then
    err "Gagal memasang binari ke $BOT_BIN"
    [[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"
    exit 1
fi
ok "Binari : $BOT_BIN"

if valid_sh "$SRC_DIR/menu.sh"; then
    install -m 755 "$SRC_DIR/menu.sh" "$MENU_BIN"
    ok "Menu   : $MENU_BIN"
fi

# ---- service ----
mkdir -p "$(dirname "$UNIT")"
cat > "$UNIT" <<EOF
[Unit]
Description=xraay-bot - Bot Telegram CONFIG LIST (Panel Xray VLESS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BOT_BIN
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
Environment=XRAY_BOT_CONFIG=$CONF_FILE
StandardOutput=journal
StandardError=journal
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF
if [ ! -s "$UNIT" ]; then
    err "Gagal menulis unit systemd ke $UNIT"
    [[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"
    exit 1
fi
chmod 644 "$UNIT"
ok "Service: $UNIT"

systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1
systemctl restart "$SERVICE"
sleep 2

if systemctl is-active --quiet "$SERVICE"; then
    ok "Bot BERJALAN."
else
    err "Bot gagal start. Log:"
    journalctl -u "$SERVICE" -n 30 --no-pager 2>/dev/null || true
    [[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"
    exit 1
fi

[[ "$SRC_DIR" == /tmp/xraay-bot.* ]] && rm -rf "$SRC_DIR"

echo ""
echo -e "${c_green}══════════════════════════════════════════════${c_reset}"
echo "  Lega. Urusan seterusnya guna menu:"
echo "    xraay-bot-menu"
echo ""
echo "  Ujian tanpa Telegram:"
echo "    xraay-bot --dump <USER_ID>"
echo ""
echo "  Log:"
echo "    journalctl -u xraay-bot -f"
echo -e "${c_green}══════════════════════════════════════════════${c_reset}"
