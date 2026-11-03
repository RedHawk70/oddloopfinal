#!/bin/bash
# ============================================================
#  xraay-bot-menu — Menu urusan Bot Telegram CONFIG LIST
# ------------------------------------------------------------
#  Guna:  xraay-bot-menu
#  Atau:  bash menu.sh   (dari folder xraay-bot)
# ============================================================

CONF="${XRAY_BOT_CONF:-/etc/xraay-bot/config.json}"
BIN="${XRAY_BOT_BIN:-/usr/local/bin/xraay-bot}"
SERVICE="${XRAY_BOT_SERVICE:-xraay-bot}"
UNIT="${XRAY_BOT_UNIT:-/etc/systemd/system/${SERVICE}.service}"
SELF_DEST="${XRAY_BOT_MENUBIN:-/usr/local/bin/xraay-bot-menu}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo /tmp)"
RAW_BASE="${XRAY_BOT_RAW:-https://raw.githubusercontent.com/RedHawk70/oddloopfinal/main/bot-menu}"

R=$'\e[0m'; B=$'\e[1m'
RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; BLU=$'\e[34m'; CYN=$'\e[36m'; MAG=$'\e[35m'

clear_screen() { [ "${NO_CLEAR:-0}" = "1" ] || clear 2>/dev/null || true; }
line() { printf '%s\n' "   ${CYN}──────────────────────────────────────────────${R}"; }

pause() { printf '\n   %sTekan Enter untuk kembali...%s' "$YEL" "$R"; read -r _ || true; }
ask()   { local _p="$1" _v; printf '%s' "$_p" >&2; read -r _v || true; printf '%s' "$_v"; }
ask_num() {
    local _p="$1" _max="$2" _v
    while true; do
        printf '%s' "$_p" >&2
        read -r _v || return 1
        [[ "$_v" =~ ^[0-9]+$ ]] || { echo -e "   ${RED}Nombor sahaja.${R}" >&2; continue; }
        (( _v >= 1 && _v <= _max )) || { echo -e "   ${RED}Luar julat (1-$_max).${R}" >&2; continue; }
        printf '%s' "$_v"; return 0
    done
}
confirm() {
    local _a
    printf '%s [y/N] : ' "$1" >&2
    read -r _a || return 1
    [[ "${_a,,}" == "y" ]]
}

[ "$(id -u)" -eq 0 ] || { echo -e "${RED}Kena run sebagai root.${R}"; exit 1; }

# ---------------- config helpers ----------------
jget() {
    python3 - "$CONF" "$1" <<'PY' 2>/dev/null
import json, sys
try:
    c = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    print(""); raise SystemExit
v = c.get(sys.argv[2])
if v is None: print("")
elif isinstance(v, bool): print("true" if v else "false")
elif isinstance(v, list): print(",".join(str(x) for x in v))
else: print(v)
PY
}

jset() {
    python3 - "$CONF" "$1" "$2" <<'PY'
import json, sys
path, val = sys.argv[1], sys.argv[3]
c = json.load(open(path, encoding="utf-8"))
c[sys.argv[2]] = json.loads(val)
json.dump(c, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("ok")
PY
}

conf_ok() {
    [ -f "$CONF" ] && python3 -m json.tool "$CONF" >/dev/null 2>&1
}

ensure_conf() {
    if [ ! -f "$CONF" ]; then
        mkdir -p "$(dirname "$CONF")"
        if [ -f "$HERE/config.example.json" ]; then
            cp "$HERE/config.example.json" "$CONF"
        else
            cat > "$CONF" <<'JSON'
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
  "poll_timeout": 50
}
JSON
        fi
        chmod 600 "$CONF"
    fi
}

note_file()  { local f; f="$(jget note_file)";  echo "${f:-/var/lib/xraay-bot/note.txt}"; }
cnote_file() { local f; f="$(jget config_note_file)"; echo "${f:-/var/lib/xraay-bot/config-notes.json}"; }

svc_active() { systemctl is-active --quiet "$SERVICE" 2>/dev/null; }

# token dianggap belum diset kalau kosong atau masih placeholder
token_missing() {
    local t; t="$(jget bot_token)"
    [ -z "$t" ] || [[ "$t" == ISI_TOKEN* ]]
}

fetch_file() {   # fetch_file <url> <dest>
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

# ---------------- status ringkas ----------------
banner() {
    clear_screen
    ensure_conf
    local st token adm note cn cfgdir telco ncfg
    if svc_active; then st="${GRN}● RUNNING${R}"; else st="${RED}○ STOPPED${R}"; fi

    token="$(jget bot_token)"
    if [ -z "$token" ] || [[ "$token" == ISI_TOKEN* ]]; then token="${RED}(belum diset)${R}"; else token="${token:0:12}…"; fi

    adm="$(jget admin_ids)"
    if [ -z "$adm" ]; then adm="-"; else adm="$(printf '%s' "$adm" | awk -F, '{print NF}') ID"; fi

    [ -s "$(note_file)" ] && note="ada" || note="kosong"

    cn=0
    [ -f "$(cnote_file)" ] && cn="$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))))' "$(cnote_file)" 2>/dev/null || echo 0)"

    cfgdir="$(jget configlist_dir)"; cfgdir="${cfgdir:-/etc/xray/configlist}"
    telco=0; ncfg=0
    if [ -d "$cfgdir" ]; then
        for f in "$cfgdir"/*.conf; do
            [ -f "$f" ] || continue
            local c
            c="$(awk -F'\t' 'NF>=5 && $2=="vless"' "$f" 2>/dev/null | wc -l)"
            (( c > 0 )) && { telco=$((telco+1)); ncfg=$((ncfg+c)); }
        done
    fi

    echo ""
    echo -e "   ${MAG}${B}╔══════════════════════════════════════════════╗${R}"
    echo -e "   ${MAG}${B}║      BOT CONFIG LIST VLESS — PANEL URUS      ║${R}"
    echo -e "   ${MAG}${B}╚══════════════════════════════════════════════╝${R}"
    echo ""
    printf '   %-12s : %s\n' "Status" "$st"
    printf '   %-12s : %s\n' "Token" "$token"
    printf '   %-12s : %s\n' "Admin" "$adm"
    printf '   %-12s : %s\n' "Note umum" "$note"
    printf '   %-12s : %s\n' "Note config" "$cn"
    printf '   %-12s : %s\n' "Config list" "${telco} telco / ${ncfg} config"
    [ -f "$BIN" ] || echo -e "   ${YEL}⚠  Bot belum dipasang (${BIN} tiada)${R}"
    echo ""
}

# ---------------- [1] install / update ----------------
find_source() {
    local p
    for p in "$HERE/bot.py" "/root/xraay-bot/bot.py" "/root/bot.py"; do
        [ -f "$p" ] && { echo "$p"; return 0; }
    done
    p="$(ask "   Path ke bot.py : ")"
    [ -f "$p" ] && { echo "$p"; return 0; }
    return 1
}

write_unit() {
    mkdir -p "$(dirname "$UNIT")" 2>/dev/null
    cat > "$UNIT" <<EOF
[Unit]
Description=xraay-bot - Bot Telegram CONFIG LIST (Panel Xray VLESS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$BIN
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
Environment=XRAY_BOT_CONFIG=$CONF
StandardOutput=journal
StandardError=journal
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$UNIT"
}

do_install() {
    clear_screen; echo -e "   ${B}[ INSTALL / UPDATE BOT ]${R}"; line; echo ""
    echo "   1) GitHub (branch main)"
    echo "   2) Fail tempatan"
    echo ""
    local p; p="$(ask "   Pilih sumber [1/2] : ")"
    [ -z "$p" ] && p=1

    local src_bot="" src_menu="" tmp=""
    if [ "$p" = "2" ]; then
        src_bot="$(find_source)" || { echo -e "   ${RED}bot.py tak jumpa.${R}"; pause; return; }
        [ -f "$HERE/menu.sh" ] && src_menu="$HERE/menu.sh"
    else
        echo ""
        echo -e "   ${CYN}Memuat turun dari GitHub...${R}"
        echo -e "   ${CYN}$RAW_BASE${R}"
        tmp="$(mktemp -d /tmp/xraay-bot.XXXXXX)"
        if ! fetch_file "$RAW_BASE/bot.py" "$tmp/bot.py"; then
            echo -e "   ${RED}✗ Gagal muat turun bot.py${R}"
            echo "   Semak fail dah di-upload ke GitHub (branch main, folder bot-menu)."
            rm -rf "$tmp"; pause; return
        fi
        if ! valid_py "$tmp/bot.py"; then
            echo -e "   ${RED}✗ bot.py rosak / bukan Python yang sah.${R}"
            echo "   (Biasanya fail belum di-upload — GitHub pulangkan 404.)"
            rm -rf "$tmp"; pause; return
        fi
        echo -e "   ${GRN}✓${R} bot.py"
        if fetch_file "$RAW_BASE/menu.sh" "$tmp/menu.sh" && bash -n "$tmp/menu.sh" 2>/dev/null; then
            echo -e "   ${GRN}✓${R} menu.sh"
            src_menu="$tmp/menu.sh"
        else
            echo -e "   ${YEL}!${R} menu.sh gagal — menu sedia ada dikekalkan."
        fi
        src_bot="$tmp/bot.py"
    fi

    command -v python3 >/dev/null 2>&1 || {
        echo -e "   ${YEL}python3 tiada, memasang...${R}"
        if command -v apt-get >/dev/null 2>&1; then
            DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3
        elif command -v yum >/dev/null 2>&1; then yum install -y -q python3
        fi
    }

    mkdir -p "$(dirname "$BIN")" 2>/dev/null
    if install -m 755 "$src_bot" "$BIN"; then
        echo -e "   ${GRN}✓${R} Binari  : $BIN"
    else
        echo -e "   ${RED}✗ Gagal memasang binari ke $BIN${R}"
        pause; return
    fi
    if [ -n "$src_menu" ]; then
        mkdir -p "$(dirname "$SELF_DEST")" 2>/dev/null
        if install -m 755 "$src_menu" "$SELF_DEST"; then
            echo -e "   ${GRN}✓${R} Menu    : $SELF_DEST"
        else
            echo -e "   ${YEL}!${R} Menu gagal dikemas kini (dikekalkan)."
        fi
    fi

    if [ ! -f "$UNIT" ]; then
        write_unit
        echo -e "   ${GRN}✓${R} Unit    : $UNIT"
    fi

    [ -n "$tmp" ] && rm -rf "$tmp"

    systemctl daemon-reload
    systemctl enable "$SERVICE" >/dev/null 2>&1
    systemctl restart "$SERVICE"
    sleep 2

    # token belum ada? tanya sekarang, kalau tidak bot takkan jalan
    if token_missing; then
        echo ""
        echo -e "   ${YEL}! Token bot belum diset — bot tak boleh jalan tanpanya.${R}"
        local tk; tk="$(ask "   Token bot (kosong = isi kemudian) : ")"
        if [ -n "$tk" ]; then
            if [[ "$tk" =~ ^[0-9]{5,}:[A-Za-z0-9_-]{20,}$ ]]; then
                jset bot_token "\"$tk\"" >/dev/null
                chmod 600 "$CONF" 2>/dev/null
                systemctl restart "$SERVICE" >/dev/null 2>&1
                sleep 2
                echo -e "   ${GRN}✓ Token disimpan.${R}"
            else
                echo -e "   ${RED}Format token nampak salah.${R} Guna menu [2] untuk set semula."
            fi
        else
            echo -e "   ${YEL}Set kemudian melalui menu [2].${R}"
        fi
    fi

    if svc_active; then
        echo -e "   ${GRN}✓ Bot BERJALAN.${R}"
    else
        echo -e "   ${RED}✗ Bot gagal start.${R} Semak log (menu 11)."
    fi
    pause
}

# ---------------- [2] token ----------------
do_token() {
    clear_screen; echo -e "   ${B}[ SET / TUKAR TOKEN BOT ]${R}"; line; echo ""
    local cur new
    cur="$(jget bot_token)"
    echo -e "   Token semasa : ${cur:0:12}…"
    echo ""
    new="$(ask "   Token baru (kosong = batal) : ")"
    [ -z "$new" ] && return
    if ! [[ "$new" =~ ^[0-9]{5,}:[A-Za-z0-9_-]{25,}$ ]]; then
        echo -e "   ${RED}Format token nampak salah.${R}"
        echo "   Contoh: 123456789:AAH8xK2mPq9vLzR3sT1uVwXyZabcdEfGh"
        pause; return
    fi

    echo -e "   ${CYN}Menguji token dengan Telegram...${R}"
    local resp
    resp="$(curl -s --max-time 15 "https://api.telegram.org/bot${new}/getMe")"
    if [[ "$resp" != *'"ok":true'* ]]; then
        echo -e "   ${RED}Telegram tolak token ni.${R}"
        echo "   $resp" | head -c 200; echo ""
        confirm "   Simpan juga?" || { pause; return; }
    else
        local uname
        uname="$(printf '%s' "$resp" | python3 -c 'import json,sys;print(json.load(sys.stdin)["result"]["username"])' 2>/dev/null)"
        echo -e "   ${GRN}✓ Token sah — bot @${uname}${R}"
    fi

    jset bot_token "\"${new}\"" >/dev/null
    chmod 600 "$CONF"
    systemctl restart "$SERVICE" >/dev/null 2>&1
    echo -e "   ${GRN}✓ Token disimpan & service di-restart.${R}"
    pause
}

# ---------------- [3] status ----------------
do_status() {
    clear_screen; echo -e "   ${B}[ STATUS TERPERINCI ]${R}"; line; echo ""
    if [ -f "$UNIT" ]; then
        systemctl status "$SERVICE" --no-pager -l 2>&1 | head -20
    else
        echo -e "   ${YEL}Service belum dipasang.${R}"
    fi
    echo ""
    echo -e "   ${CYN}Semakan cepat:${R}"
    [ -f "$BIN" ] && echo -e "   ${GRN}✓${R} Binari ada ($BIN)" || echo -e "   ${RED}✗${R} Binari tiada"
    conf_ok && echo -e "   ${GRN}✓${R} JSON config sah" || echo -e "   ${RED}✗${R} JSON config ROSAK"
    [ -d "$(jget configlist_dir || echo /etc/xray/configlist)" ] && echo -e "   ${GRN}✓${R} Config list ada" || echo -e "   ${YEL}!${R} Config list tiada"
    [ -f /root/log-install.txt ] && echo -e "   ${GRN}✓${R} log-install.txt ada" || echo -e "   ${YEL}!${R} log-install.txt tiada (guna port lalai)"
    pause
}

# ---------------- [4] service ----------------
do_service() {
    clear_screen; echo -e "   ${B}[ KAWALAN SERVICE ]${R}"; line; echo ""
    if svc_active; then echo -e "   Status: ${GRN}RUNNING${R}"; else echo -e "   Status: ${RED}STOPPED${R}"; fi
    echo ""
    echo "   1) Start"
    echo "   2) Stop"
    echo "   3) Restart"
    echo ""
    local p; p="$(ask "   Pilih [1-3, x] : ")"
    case "$p" in
        1) systemctl start "$SERVICE" ;;
        2) systemctl stop "$SERVICE" ;;
        3) systemctl restart "$SERVICE" ;;
        *) return ;;
    esac
    sleep 1
    svc_active && echo -e "   ${GRN}✓ RUNNING${R}" || echo -e "   ${RED}✗ STOPPED${R}"
    pause
}

# ---------------- [5] admin ----------------
do_admin() {
    while true; do
        clear_screen; echo -e "   ${B}[ URUS ADMIN ]${R}"; line; echo ""
        local list; list="$(jget admin_ids)"
        if [ -z "$list" ]; then echo "   (tiada admin)"; else echo "   Admin: $list"; fi
        echo ""
        echo "   a) Tambah admin"
        echo "   d) Buang admin"
        echo "   x) Kembali"
        echo ""
        local p; p="$(ask "   Pilih [a/d/x] : ")"
        case "${p,,}" in
            a)
                local id
                id="$(ask "   Chat ID admin baru : ")"
                if ! [[ "$id" =~ ^[0-9]+$ ]]; then echo -e "   ${RED}Chat ID mesti nombor.${R}"; sleep 1; continue; fi
                python3 - "$CONF" "$id" <<'PY'
import json, sys
p, i = sys.argv[1], int(sys.argv[2])
c = json.load(open(p, encoding="utf-8"))
a = set(int(x) for x in (c.get("admin_ids") or []))
a.add(i)
c["admin_ids"] = sorted(a)
json.dump(c, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("   ✓ admin_ids =", ", ".join(str(x) for x in c["admin_ids"]))
PY
                systemctl restart "$SERVICE" >/dev/null 2>&1
                echo -e "   ${GRN}✓${R} Service di-restart."
                sleep 2 ;;
            d)
                [ -z "$list" ] && { echo -e "   ${YEL}Tiada admin.${R}"; sleep 1; continue; }
                local id2
                id2="$(ask "   Chat ID nak dibuang : ")"
                python3 - "$CONF" "$id2" <<'PY'
import json, sys
p, i = sys.argv[1], sys.argv[2]
c = json.load(open(p, encoding="utf-8"))
a = [x for x in (c.get("admin_ids") or []) if str(x) != i]
c["admin_ids"] = a
json.dump(c, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("   ✓ admin_ids =", ", ".join(str(x) for x in a) or "(kosong)")
PY
                systemctl restart "$SERVICE" >/dev/null 2>&1
                sleep 2 ;;
            x) return ;;
        esac
    done
}

# ---------------- [6] allowlist ----------------
do_allow() {
    while true; do
        clear_screen; echo -e "   ${B}[ ALLOWLIST PENGGUNA ]${R}"; line; echo ""
        local list; list="$(jget allowed_chat_ids)"
        if [ -z "$list" ]; then
            echo -e "   ${YEL}(kosong — bot terbuka untuk sesiapa)${R}"
        else
            echo "   Dibenarkan: $list"
        fi
        echo ""
        echo "   a) Tambah chat ID"
        echo "   d) Buang chat ID"
        echo "   c) Kosongkan (buka untuk semua)"
        echo "   x) Kembali"
        echo ""
        local p; p="$(ask "   Pilih [a/d/c/x] : ")"
        case "${p,,}" in
            a)
                local id
                id="$(ask "   Chat ID : ")"
                [[ "$id" =~ ^[0-9]+$ ]] || { echo -e "   ${RED}Mesti nombor.${R}"; sleep 1; continue; }
                python3 - "$CONF" "$id" <<'PY'
import json, sys
p, i = sys.argv[1], int(sys.argv[2])
c = json.load(open(p, encoding="utf-8"))
a = set(int(x) for x in (c.get("allowed_chat_ids") or []))
a.add(i)
c["allowed_chat_ids"] = sorted(a)
json.dump(c, open(p, "w", encoding="utf-8"), indent=2)
print("   ✓ allowed_chat_ids =", ", ".join(str(x) for x in c["allowed_chat_ids"]))
PY
                systemctl restart "$SERVICE" >/dev/null 2>&1; sleep 2 ;;
            d)
                local id2
                id2="$(ask "   Chat ID nak dibuang : ")"
                python3 - "$CONF" "$id2" <<'PY'
import json, sys
p, i = sys.argv[1], sys.argv[2]
c = json.load(open(p, encoding="utf-8"))
a = [x for x in (c.get("allowed_chat_ids") or []) if str(x) != i]
c["allowed_chat_ids"] = a
json.dump(c, open(p, "w", encoding="utf-8"), indent=2)
print("   ✓ allowed_chat_ids =", ", ".join(str(x) for x in a) or "(kosong)")
PY
                systemctl restart "$SERVICE" >/dev/null 2>&1; sleep 2 ;;
            c)
                confirm "   Pasti nak buka bot untuk semua?" || continue
                jset allowed_chat_ids "[]" >/dev/null
                systemctl restart "$SERVICE" >/dev/null 2>&1; sleep 2 ;;
            x) return ;;
        esac
    done
}

# ---------------- [7] note umum ----------------
do_note() {
    clear_screen; echo -e "   ${B}[ NOTE UMUM ]${R}"; line; echo ""
    local f; f="$(note_file)"
    if [ -s "$f" ]; then echo -e "   ${CYN}Note semasa:${R}"; sed 's/^/   │ /' "$f"; else echo "   (kosong)"; fi
    echo ""
    echo "   1) Set note (satu baris)"
    echo "   2) Edit dengan nano (boleh berbilang baris)"
    echo "   3) Padam note"
    echo "   x) Kembali"
    echo ""
    local p; p="$(ask "   Pilih [1-3, x] : ")"
    case "$p" in
        1)
            local t
            t="$(ask "   Teks note : ")"
            [ -z "$t" ] && return
            mkdir -p "$(dirname "$f")"; printf '%s\n' "$t" > "$f"; chmod 600 "$f"
            echo -e "   ${GRN}✓ Note disimpan.${R}" ;;
        2)
            mkdir -p "$(dirname "$f")"; touch "$f"
            ${EDITOR:-nano} "$f" ;;
        3)
            rm -f "$f"; echo -e "   ${GRN}✓ Note dipadam.${R}" ;;
        *) return ;;
    esac
    pause
}

# ---------------- [8] note per-config ----------------
list_configs() {
    local cfgdir f p name mode proto addr cpath extra idx=0
    cfgdir="$(jget configlist_dir)"; cfgdir="${cfgdir:-/etc/xray/configlist}"
    for f in "$cfgdir"/*.conf; do
        [ -f "$f" ] || continue
        p="$(basename "$f" .conf)"
        while IFS=$'\t' read -r name mode proto addr cpath extra; do
            [ -z "$name" ] && continue
            case "$name" in \#*) continue ;; esac
            if [[ "$mode" != "vmess" && "$mode" != "vless" && "$mode" != "xtls" ]]; then
                extra="$cpath"; cpath="$addr"; addr="$proto"; proto="$mode"; mode="vless"
            fi
            [ "$mode" = "vless" ] || continue
            idx=$((idx+1))
            printf '%s\t%s\t%s\n' "$idx" "$p" "$name"
        done < "$f"
    done
}

do_cnote() {
    while true; do
        clear_screen; echo -e "   ${B}[ NOTE PER-CONFIG ]${R}"; line; echo ""
        local -a rows=()
        mapfile -t rows < <(list_configs)
        if [ ${#rows[@]} -eq 0 ]; then
            echo -e "   ${YEL}Tiada config dalam CONFIG LIST.${R}"; pause; return
        fi
        local cf; cf="$(cnote_file)"
        local r idx prov name n
        for r in "${rows[@]}"; do
            IFS=$'\t' read -r idx prov name <<< "$r"
            n="$(python3 - "$cf" "$prov|$name" <<'PY'
import json,sys
try: d=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: d={}
print("ada note" if d.get(sys.argv[2]) else "-")
PY
)"
            printf '   %2s) %-10s %-42s %s\n' "$idx" "$prov" "$name" "$n"
        done
        echo ""
        echo -e "   ${CYN}x) Kembali${R}"
        echo ""
        local pick
        pick="$(ask "   Pilih nombor config : ")"
        [ "${pick,,}" = "x" ] && return
        [[ "$pick" =~ ^[0-9]+$ ]] || continue
        local chosen=""
        for r in "${rows[@]}"; do
            IFS=$'\t' read -r idx prov name <<< "$r"
            [ "$idx" = "$pick" ] && { chosen="$r"; break; }
        done
        [ -z "$chosen" ] && continue
        IFS=$'\t' read -r idx prov name <<< "$chosen"
        cnote_edit "$prov" "$name"
    done
}

cnote_edit() {
    local prov="$1" name="$2" cf key cur
    cf="$(cnote_file)"; key="$prov|$name"
    while true; do
        clear_screen; echo -e "   ${B}${name}${R}  (${prov})"; line; echo ""
        cur="$(python3 - "$cf" "$key" <<'PY'
import json,sys
try: d=json.load(open(sys.argv[1],encoding="utf-8"))
except Exception: d={}
print(d.get(sys.argv[2],""))
PY
)"
        if [ -n "$cur" ]; then echo -e "   ${CYN}Note semasa:${R}"; printf '%s\n' "$cur" | sed 's/^/   │ /'; else echo "   (kosong)"; fi
        echo ""
        echo "   1) Set / tukar note"
        echo "   2) Padam note"
        echo "   x) Kembali"
        echo ""
        local p; p="$(ask "   Pilih [1/2/x] : ")"
        case "$p" in
            1)
                local t
                t="$(ask "   Teks note : ")"
                [ -z "$t" ] && continue
                mkdir -p "$(dirname "$cf")"
                python3 - "$cf" "$key" "$t" <<'PY'
import json, sys, os
p, k, t = sys.argv[1], sys.argv[2], sys.argv[3]
try: d = json.load(open(p, encoding="utf-8"))
except Exception: d = {}
d[k] = t
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False, sort_keys=True)
os.chmod(p, 0o600)
PY
                echo -e "   ${GRN}✓ Note disimpan.${R}"; sleep 1 ;;
            2)
                python3 - "$cf" "$key" <<'PY'
import json, sys
p, k = sys.argv[1], sys.argv[2]
try: d = json.load(open(p, encoding="utf-8"))
except Exception: d = {}
d.pop(k, None)
json.dump(d, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False, sort_keys=True)
PY
                echo -e "   ${GRN}✓ Note dipadam.${R}"; sleep 1 ;;
            *) return ;;
        esac
    done
}

# ---------------- [9] ujian ----------------
do_test() {
    clear_screen; echo -e "   ${B}[ UJI CARIAN USER ID ]${R}"; line; echo ""
    local id
    id="$(ask "   User ID (UUID) : ")"
    [ -z "$id" ] && return
    echo ""
    if [ -f "$BIN" ]; then
        XRAY_BOT_CONFIG="$CONF" "$BIN" --dump "$id" | sed 's/<[^>]*>//g'
    else
        echo -e "   ${RED}Bot belum dipasang.${R}"
    fi
    pause
}

# ---------------- [10] papar config ----------------
do_show() {
    clear_screen; echo -e "   ${B}[ CONFIG SEMASA ]${R}"; line; echo ""
    if ! conf_ok; then echo -e "   ${RED}JSON ROSAK: $CONF${R}"; pause; return; fi
    python3 - "$CONF" <<'PY'
import json, sys
c = json.load(open(sys.argv[1], encoding="utf-8"))
t = c.get("bot_token") or ""
if t: c["bot_token"] = t[:12] + "…" + t[-4:]
print(json.dumps(c, indent=2, ensure_ascii=False))
PY
    pause
}

# ---------------- [11] log ----------------
do_log() {
    clear_screen; echo -e "   ${B}[ LOG BOT ]${R}"; line; echo ""
    echo "  1) 40 baris terakhir"
    echo "  2) Ikut log langsung (Ctrl+C untuk keluar)"
    echo ""
    local p; p="$(ask "   Pilih [1/2, x] : ")"
    case "$p" in
        1) journalctl -u "$SERVICE" -n 40 --no-pager ;;
        2) echo -e "   ${YEL}Ctrl+C untuk kembali${R}"; sleep 1; journalctl -u "$SERVICE" -f ;;
        *) return ;;
    esac
    pause
}

# ---------------- [12] uninstall ----------------
do_uninstall() {
    clear_screen; echo -e "   ${B}[ UNINSTALL ]${R}"; line; echo ""
    echo -e "   ${YEL}Ini akan membuang:${R}"
    echo "     • service $SERVICE"
    echo "     • $BIN"
    echo "     • $SELF_DEST (menu)"
    echo ""
    confirm "   Teruskan?" || return
    systemctl stop "$SERVICE" >/dev/null 2>&1
    systemctl disable "$SERVICE" >/dev/null 2>&1
    rm -f "$UNIT" "$BIN" "$SELF_DEST"
    systemctl daemon-reload
    echo -e "   ${GRN}✓ Bot dibuang.${R}"
    if confirm "   Buang juga config & note?"; then
        rm -rf "$(dirname "$CONF")" "$(dirname "$(note_file)")"
        echo -e "   ${GRN}✓ Config & note dibuang.${R}"
    fi
    pause
    exit 0
}

# ---------------- MAIN ----------------
main_menu() {
    while true; do
        banner
        echo -e "   ${CYN}┌── PEMASANGAN ────────────────────────────────${R}"
        echo -e "   ${CYN}│${R}  ${B}[1]${R} Install / Update bot"
        echo -e "   ${CYN}│${R}  ${B}[2]${R} Set / Tukar token bot"
        echo -e "   ${CYN}└──────────────────────────────────────────────${R}"
        echo -e "   ${CYN}┌── PERKHIDMATAN ──────────────────────────────${R}"
        echo -e "   ${CYN}│${R}  ${B}[3]${R} Status terperinci"
        echo -e "   ${CYN}│${R}  ${B}[4]${R} Start / Stop / Restart"
        echo -e "   ${CYN}└──────────────────────────────────────────────${R}"
        echo -e "   ${CYN}┌── AKSES ─────────────────────────────────────${R}"
        echo -e "   ${CYN}│${R}  ${B}[5]${R} Urus admin"
        echo -e "   ${CYN}│${R}  ${B}[6]${R} Urus allowlist pengguna"
        echo -e "   ${CYN}└──────────────────────────────────────────────${R}"
        echo -e "   ${CYN}┌── NOTE ──────────────────────────────────────${R}"
        echo -e "   ${CYN}│${R}  ${B}[7]${R} Note umum"
        echo -e "   ${CYN}│${R}  ${B}[8]${R} Note per-config"
        echo -e "   ${CYN}└──────────────────────────────────────────────${R}"
        echo -e "   ${CYN}┌── LAIN-LAIN ─────────────────────────────────${R}"
        echo -e "   ${CYN}│${R}  ${B}[9]${R} Uji carian User ID"
        echo -e "   ${CYN}│${R}  ${B}[10]${R} Papar config semasa"
        echo -e "   ${CYN}│${R}  ${B}[11]${R} Log bot"
        echo -e "   ${CYN}│${R}  ${B}[12]${R} Uninstall"
        echo -e "   ${CYN}│${R}  ${B}[0]${R}  Keluar"
        echo -e "   ${CYN}└──────────────────────────────────────────────${R}"
        echo ""
        local p; p="$(ask "   Pilih [0-12] : ")"
        case "$p" in
            1) do_install ;;
            2) do_token ;;
            3) do_status ;;
            4) do_service ;;
            5) do_admin ;;
            6) do_allow ;;
            7) do_note ;;
            8) do_cnote ;;
            9) do_test ;;
            10) do_show ;;
            11) do_log ;;
            12) do_uninstall ;;
            0|q|Q) clear_screen; exit 0 ;;
            *) ;;
        esac
    done
}

ensure_conf
main_menu
