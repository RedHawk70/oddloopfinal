#!/usr/bin/env bash
#
# socks-manager.sh — Menu interaktif untuk urus Xray SOCKS5 server
# Guna: sudo bash socks-manager.sh
#
set -uo pipefail

CONFIG_FILE="/usr/local/etc/xray/socks.json"
SERVICE_FILE="/etc/systemd/system/xray-socks.service"
XRAY_BIN="/usr/local/bin/xray"
SOCKS_PORT_DEFAULT="1080"

# ---------- Warna ----------
G="\033[1;32m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

# ---------- Semak root ----------
if [[ $EUID -ne 0 ]]; then
  echo -e "${R}❌ Sila jalankan sebagai root (sudo).${N}"; exit 1
fi

pause(){ echo ""; read -rp "Tekan [Enter] untuk sambung..."; }

# ---------- Pasang keperluan ----------
ensure_deps(){
  local need=0
  for b in curl openssl jq; do command -v "$b" >/dev/null 2>&1 || need=1; done
  if [[ $need -eq 1 ]]; then
    echo -e "${Y}==> Memasang keperluan (curl, openssl, jq)...${N}"
    apt update -y && apt install -y curl openssl jq iptables
  fi
}

xray_installed(){ [[ -x "$XRAY_BIN" ]]; }

# ---------- Install Xray + config asas + servis ----------
initial_setup(){
  ensure_deps
  if ! xray_installed; then
    echo -e "${Y}==> Install Xray...${N}"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
  else
    echo -e "${G}Xray sudah dipasang: $($XRAY_BIN version | head -n1)${N}"
  fi

  mkdir -p /usr/local/etc/xray /var/log/xray
  touch /var/log/xray/socks-access.log /var/log/xray/socks-error.log

  local port="$SOCKS_PORT_DEFAULT"
  read -rp "Port SOCKS5 [${SOCKS_PORT_DEFAULT}]: " p; [[ -n "${p:-}" ]] && port="$p"

  if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${Y}Config sedia ada dijumpai — kekalkan user sedia ada.${N}"
  else
    cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "access": "/var/log/xray/socks-access.log",
    "error": "/var/log/xray/socks-error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${port},
      "protocol": "socks",
      "settings": {
        "auth": "password",
        "accounts": [],
        "udp": true
      },
      "tag": "socks-in"
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": ["10.0.0.0/8","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.168.0.0/16","::1/128","fc00::/7","fe80::/10"],
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
    echo -e "${G}Config asas dicipta.${N}"
  fi

  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Xray SOCKS5 Server
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=${XRAY_BIN} run -config ${CONFIG_FILE}
Restart=on-failure
RestartSec=5
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now xray-socks >/dev/null 2>&1

  open_firewall "$port"
  restart_service
  echo -e "${G}✅ Setup asas selesai. Sekarang tambah user dari menu (pilihan 1).${N}"
  pause
}

# ---------- Firewall ----------
open_firewall(){
  local port="$1"
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${port}/tcp" >/dev/null 2>&1
    echo -e "${G}Firewall (UFW): port ${port}/tcp dibuka.${N}"
  else
    local pos
    pos=$(iptables -L INPUT --line-numbers -n 2>/dev/null | awk '/ufw-/{print $1; exit}')
    if [[ -n "${pos:-}" ]]; then
      iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT "$pos" -p tcp --dport "$port" -j ACCEPT
    else
      iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
    fi
    command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1 || true
    echo -e "${G}Firewall (iptables): port ${port}/tcp dibuka.${N}"
  fi
}

need_config(){
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${R}Config belum wujud. Jalankan 'Setup / Install' (pilihan 9) dulu.${N}"; pause; return 1
  fi
}

get_port(){ jq -r '.inbounds[0].port' "$CONFIG_FILE"; }

apply(){ # test + restart
  if "$XRAY_BIN" -test -config "$CONFIG_FILE" >/dev/null 2>&1; then
    systemctl restart xray-socks
    echo -e "${G}✅ Diguna & servis di-restart.${N}"
  else
    echo -e "${R}❌ Config tak sah! Perubahan tak diguna. Semak:${N}"
    "$XRAY_BIN" -test -config "$CONFIG_FILE"
  fi
}

restart_service(){ systemctl restart xray-socks 2>/dev/null && echo -e "${G}Servis di-restart.${N}" || echo -e "${R}Gagal restart.${N}"; }

# ---------- Urus user ----------
add_user(){
  need_config || return
  local u p
  read -rp "Username baru: " u
  [[ -z "$u" ]] && { echo -e "${R}Username kosong.${N}"; pause; return; }
  if jq -e --arg u "$u" '.inbounds[0].settings.accounts[]|select(.user==$u)' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo -e "${R}User '$u' sudah wujud.${N}"; pause; return
  fi
  read -rp "Password (kosong = auto-rawak): " p
  [[ -z "$p" ]] && { p="$(openssl rand -base64 18)"; echo -e "${Y}Password auto: ${C}$p${N}"; }
  jq --arg u "$u" --arg p "$p" \
    '.inbounds[0].settings.accounts += [{"user":$u,"pass":$p}]' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  echo -e "${G}User '$u' ditambah.${N}"
  apply; pause
}

del_user(){
  need_config || return
  list_users_raw
  local u
  read -rp "Username untuk dibuang: " u
  [[ -z "$u" ]] && return
  if ! jq -e --arg u "$u" '.inbounds[0].settings.accounts[]|select(.user==$u)' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo -e "${R}User '$u' tak dijumpai.${N}"; pause; return
  fi
  jq --arg u "$u" \
    '.inbounds[0].settings.accounts |= map(select(.user != $u))' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  echo -e "${G}User '$u' dibuang.${N}"
  apply; pause
}

change_pass(){
  need_config || return
  list_users_raw
  local u p
  read -rp "Username untuk tukar password: " u
  [[ -z "$u" ]] && return
  if ! jq -e --arg u "$u" '.inbounds[0].settings.accounts[]|select(.user==$u)' "$CONFIG_FILE" >/dev/null 2>&1; then
    echo -e "${R}User '$u' tak dijumpai.${N}"; pause; return
  fi
  read -rp "Password baru (kosong = auto-rawak): " p
  [[ -z "$p" ]] && { p="$(openssl rand -base64 18)"; echo -e "${Y}Password auto: ${C}$p${N}"; }
  jq --arg u "$u" --arg p "$p" \
    '.inbounds[0].settings.accounts |= map(if .user==$u then .pass=$p else . end)' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  echo -e "${G}Password '$u' dikemas kini.${N}"
  apply; pause
}

list_users_raw(){
  echo -e "${C}--- Senarai user ---${N}"
  jq -r '.inbounds[0].settings.accounts[] | "  \(.user)  :  \(.pass)"' "$CONFIG_FILE" 2>/dev/null || echo "  (tiada)"
  echo -e "${C}--------------------${N}"
}
list_users(){ need_config || return; list_users_raw; pause; }

show_info(){
  need_config || return
  local ip port
  ip=$(curl -s https://ifconfig.me || echo "IP-VPS")
  port=$(get_port)
  echo -e "${C}=== Maklumat Sambungan ===${N}"
  echo " Alamat : $ip"
  echo " Port   : $port"
  list_users_raw
  echo ""
  echo -e "${Y}Outbound untuk config client (contoh user pertama):${N}"
  local u p
  u=$(jq -r '.inbounds[0].settings.accounts[0].user // "USER"' "$CONFIG_FILE")
  p=$(jq -r '.inbounds[0].settings.accounts[0].pass // "PASS"' "$CONFIG_FILE")
  cat <<EOF
  {
    "protocol": "socks",
    "tag": "socks5",
    "settings": { "servers": [ {
      "address": "$ip", "port": $port,
      "users": [ { "user": "$u", "pass": "$p" } ]
    } ] }
  }
EOF
  pause
}

status(){ systemctl status xray-socks --no-pager -l | head -n 15; echo ""; ss -tlnp 2>/dev/null | grep ":$(get_port 2>/dev/null)" || true; pause; }

test_local(){
  need_config || return
  local u p port
  port=$(get_port)
  u=$(jq -r '.inbounds[0].settings.accounts[0].user // empty' "$CONFIG_FILE")
  p=$(jq -r '.inbounds[0].settings.accounts[0].pass // empty' "$CONFIG_FILE")
  [[ -z "$u" ]] && { echo -e "${R}Tiada user. Tambah user dulu.${N}"; pause; return; }
  echo "Menguji proxy (user: $u)..."
  local out
  out=$(curl -s --max-time 10 -x "socks5h://${u}:${p}@127.0.0.1:${port}" https://ifconfig.me || echo "GAGAL")
  echo -e "Hasil: ${C}${out}${N}"
  pause
}

uninstall(){
  read -rp "Pasti nak buang servis SOCKS5? (config & Xray kekal) [y/N]: " a
  [[ "${a,,}" == "y" ]] || { echo "Batal."; pause; return; }
  systemctl disable --now xray-socks 2>/dev/null || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  echo -e "${G}Servis xray-socks dibuang. (socks.json masih ada di $CONFIG_FILE)${N}"
  pause
}

menu(){
  clear
  echo -e "${C}╔══════════════════════════════════════════╗${N}"
  echo -e "${C}║      XRAY SOCKS5 — MENU PENGURUSAN       ║${N}"
  echo -e "${C}╚══════════════════════════════════════════╝${N}"
  if [[ -f "$CONFIG_FILE" ]]; then
    local n; n=$(jq '.inbounds[0].settings.accounts | length' "$CONFIG_FILE" 2>/dev/null || echo "?")
    echo -e " Status config : ${G}ADA${N}   |  Port: $(get_port 2>/dev/null)  |  User: ${n}"
  else
    echo -e " Status config : ${R}BELUM SETUP${N}"
  fi
  echo "--------------------------------------------"
  echo "  1) Tambah user"
  echo "  2) Buang user"
  echo "  3) Tukar password user"
  echo "  4) Senarai user (+ password)"
  echo "  5) Maklumat sambungan / blok outbound client"
  echo "  6) Status servis"
  echo "  7) Test proxy (dari VPS)"
  echo "  8) Restart servis"
  echo "  9) Setup / Install (jalankan sekali di awal)"
  echo " 10) Uninstall servis"
  echo "  0) Keluar"
  echo "--------------------------------------------"
  read -rp "Pilih [0-10]: " ch
  case "$ch" in
    1) add_user ;;
    2) del_user ;;
    3) change_pass ;;
    4) list_users ;;
    5) show_info ;;
    6) status ;;
    7) test_local ;;
    8) restart_service; pause ;;
    9) initial_setup ;;
    10) uninstall ;;
    0) exit 0 ;;
    *) echo -e "${R}Pilihan tak sah.${N}"; sleep 1 ;;
  esac
}

# ---------- Main loop ----------
while true; do menu; done