#!/bin/bash
set -Eeuo pipefail

GitUser="RedHawk70"
STATE_FILE="/home/limit"

Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[ON]${Font_color_suffix}"
Error="${Red_font_prefix}[OFF]${Font_color_suffix}"

trap 'echo -e "\n${Red_font_prefix}Error${Font_color_suffix}: line $LINENO, command: $BASH_COMMAND" >&2' ERR

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Sila run sebagai root: sudo $0"
    exit 1
  fi
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

ensure_state_file() {
  [[ -e "$STATE_FILE" ]] || : > "$STATE_FILE" 2>/dev/null || true
}

# ====== STATE: enabled/down/up ======
read_state() {
  local enabled="0" down="" up=""
  if [[ -f "$STATE_FILE" ]]; then
    enabled="$(awk -F= '/^enabled=/{print $2}' "$STATE_FILE" 2>/dev/null | tail -n1 || echo "0")"
    down="$(awk -F= '/^down_kbps=/{print $2}' "$STATE_FILE" 2>/dev/null | tail -n1 || true)"
    up="$(awk -F= '/^up_kbps=/{print $2}' "$STATE_FILE" 2>/dev/null | tail -n1 || true)"
  fi
  echo "${enabled}|${down}|${up}"
}

write_state() {
  local enabled="$1" down="${2:-}" up="${3:-}"
  {
    echo "enabled=${enabled}"
    echo "down_kbps=${down}"
    echo "up_kbps=${up}"
  } > "$STATE_FILE" 2>/dev/null || true
}

format_rate() {
  local kbps="${1:-}"
  [[ -z "$kbps" ]] && { echo "-"; return 0; }
  if [[ "$kbps" =~ ^[0-9]+$ ]] && (( kbps >= 1000 )); then
    awk -v k="$kbps" 'BEGIN{printf "%.2f Mbps", (k/1000)}'
  else
    echo "${kbps} Kbps"
  fi
}

get_status() {
  local st enabled
  st="$(read_state)"
  enabled="${st%%|*}"
  [[ "$enabled" == "1" ]] && echo "$Info" || echo "$Error"
}

get_current_limit_line() {
  local st enabled down up
  st="$(read_state)"
  enabled="${st%%|*}"
  down="$(echo "$st" | cut -d'|' -f2)"
  up="$(echo "$st" | cut -d'|' -f3)"
  if [[ "$enabled" == "1" ]]; then
    echo "Down: $(format_rate "$down") | Up: $(format_rate "$up")"
  else
    echo "Down: - | Up: -"
  fi
}

get_nic() {
  local nic=""
  nic="$(ip -o -4 route show default 2>/dev/null | awk 'NR==1{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
  [[ -z "$nic" ]] && nic="$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
  [[ -z "$nic" ]] && { echo "Tak dapat detect NIC. Semak: ip route"; exit 1; }
  echo "$nic"
}

validate_kbps() {
  local v="$1"
  [[ -z "$v" ]] && return 0
  [[ "$v" =~ ^[0-9]+$ ]]
}

service_exists() {
  systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "$1"
}

apply_limit() {
  # Ini yang buat update jadi jalan: clear dulu, baru apply
  local nic="$1" down="$2" up="$3"

  # clear lama (kalau belum ada pun takpe)
  wondershaper -ca "$nic" >/dev/null 2>&1 || true

  # apply baru
  wondershaper -a "$nic" -d "$down" -u "$up" >/dev/null 2>&1
}

start_limit() {
  local nic="$1"
  echo "Limit Speed All Service (NIC: $nic)"
  read -r -p "Set maximum download rate (in Kbps): " down
  read -r -p "Set maximum upload rate (in Kbps): " up

  if [[ -z "$down" && -z "$up" ]]; then
    echo "Tiada input. Batal."
    return 0
  fi

  if ! validate_kbps "$down" || ! validate_kbps "$up"; then
    echo "Input mesti nombor (Kbps). Contoh: 1024"
    return 1
  fi

  if ! has_cmd wondershaper; then
    echo "Error: wondershaper tidak dijumpai. Sila install dulu."
    return 1
  fi

  echo "Apply/Update Configuration..."
  apply_limit "$nic" "${down:-0}" "${up:-0}" || {
    echo "Gagal apply wondershaper. Semak NIC & permission."
    return 1
  }

  # Optional: kalau ada service, enable je (tak restart supaya tak override setting)
  if has_cmd systemctl && service_exists "wondershaper.service"; then
    systemctl enable --now wondershaper.service >/dev/null 2>&1 || true
  fi

  write_state "1" "${down:-0}" "${up:-0}"
  echo "Done"
}

stop_limit() {
  local nic="$1"

  if has_cmd wondershaper; then
    wondershaper -ca "$nic" >/dev/null 2>&1 || true
  fi

  if has_cmd systemctl && service_exists "wondershaper.service"; then
    systemctl stop wondershaper.service >/dev/null 2>&1 || true
  fi

  write_state "0" "" ""
  echo "Stop Configuration... Done"
}

change_limit() {
  # Sama macam start_limit (update tanpa perlu stop)
  start_limit "$1"
}

main_menu() {
  require_root
  ensure_state_file

  local nic
  nic="$(get_nic)"

  while true; do
    clear
    local sts cur
    sts="$(get_status)"
    cur="$(get_current_limit_line)"

    echo -e " \e[0;32m==============================\e[0m"
    echo -e "     \e[1;36mLimit Bandwidth Speed\e[0m"
    echo -e " \e[0;32m==============================\e[0m"
    echo -e " Status        $sts"
    echo -e " NIC           $nic"
    echo -e " Current Limit $cur"
    echo -e "  1. Start Limit (Apply/Update)"
    echo -e "  2. Stop Limit"
    echo -e "  3. Change Limit (Update)"
    echo -e "  0. Exit"
    echo
    read -r -p " Please Enter The Correct Number : " num

    case "${num}" in
      1) start_limit "$nic" ;;
      2) stop_limit "$nic" ;;
      3) change_limit "$nic" ;;
      0) exit 0 ;;
      *) echo "Input salah."; sleep 1 ;;
    esac
  done
}

main_menu
