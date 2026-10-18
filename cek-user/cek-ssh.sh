#!/usr/bin/env bash
# cek-ssh.sh — papar sesi login aktif Dropbear / OpenSSH / OpenVPN
# Jalankan sebagai root (sudo) supaya journalctl/ss/lsof dapat maklumat penuh.
#
# Guna:
#   sudo ./cek-ssh.sh                 # default: journal sejak "7 days ago"
#   sudo ./cek-ssh.sh "2 days ago"    # tempoh journal custom
#   sudo ./cek-ssh.sh --all           # tunjuk root juga
#   sudo ./cek-ssh.sh --no-root       # sembunyi root (default)
#
# Serasi: Debian / Ubuntu (bash 4+, systemd, iproute2)

set -u -o pipefail
export LANG=en_US.UTF-8

# ---------------------------
# Parse argumen (flag vs tempoh)
# ---------------------------
SEED_SINCE="7 days ago"
SKIP_ROOT=1
for a in "$@"; do
  case "$a" in
    --all|-a)     SKIP_ROOT=0 ;;
    --no-root|-n) SKIP_ROOT=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) SEED_SINCE="$a" ;;
  esac
done

# ---------------------------
# Semakan asas
# ---------------------------
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "AMARAN: bukan root — maklumat mungkin tidak lengkap. Guna: sudo $0" >&2
fi

if ! command -v ss >/dev/null 2>&1; then
  echo "Perintah 'ss' tidak ditemui. Pasang package 'iproute2'." >&2
  exit 1
fi

HAS_JOURNALCTL=0
command -v journalctl >/dev/null 2>&1 && HAS_JOURNALCTL=1
HAS_LSOF=0
command -v lsof >/dev/null 2>&1 && HAS_LSOF=1

# ---------------------------
# Fail sementara (satu set sahaja, dibersihkan oleh trap)
# ---------------------------
TMP_JOURNAL="$(mktemp /tmp/cek-ssh-journal-XXXXXX)"
TMP_SS="$(mktemp /tmp/cek-ssh-ss-XXXXXX)"
cleanup() { rm -f "$TMP_JOURNAL" "$TMP_SS" 2>/dev/null || true; }
trap cleanup EXIT

# ---------------------------
# Helper
# ---------------------------
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

sanitize_field() {
  printf '%s' "$1" | tr -d '[:cntrl:]'
}

# parse_peer "<addr>" -> "ip port"
# Sokong: "1.2.3.4:22", "[::1]:22", "2001:db8::1" (IPv6 tanpa kurungan = IP sahaja)
parse_peer() {
  local peer="$1" ip="" port=""
  peer="${peer#"${peer%%[![:space:]]*}"}"
  peer="${peer%"${peer##*[![:space:]]}"}"

  if [[ "$peer" =~ ^\[(.+)\]:([0-9]+)$ ]]; then
    ip="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[2]}"
  elif [[ "$peer" == *.*:* ]]; then
    ip="${peer%:*}"; port="${peer##*:}"
  elif [[ "$peer" == *:*:* ]]; then
    ip="$peer"   # IPv6 tanpa kurungan — tiada port boleh dipastikan
  elif [[ "$peer" == *:* ]]; then
    ip="${peer%:*}"; port="${peer##*:}"
  else
    ip="$peer"
  fi
  printf '%s %s' "$ip" "$port"
}

get_addr_from_ss() {
  local pid="$1"
  ss -Htnp 2>/dev/null | awk -v p="pid=$pid," 'index($0,p){ print $(NF-1); exit }'
}

get_addr_from_lsof() {
  local pid="$1" out=""
  [ "$HAS_LSOF" -eq 1 ] || return 0
  out="$(lsof -Pan -p "$pid" -i 2>/dev/null | awk '/->[0-9a-fA-F[]/{ for (i=1;i<=NF;i++) if ($i ~ /->/) { sub(/.*->/,"",$i); print $i; exit } }')"
  printf '%s' "$out"
}

pid_start_epoch() {
  local pid="$1" start ts
  start="$(ps -p "$pid" -o lstart= 2>/dev/null || true)"
  if [ -n "$start" ]; then
    ts="$(date -d "$start" +%s 2>/dev/null || echo 0)"
  else
    ts=0
  fi
  printf '%s' "$ts"
}

epoch_to_hm() {
  local ts="$1"
  if [ "${ts:-0}" -gt 0 ]; then
    date -d "@$ts" '+%H:%M' 2>/dev/null || echo '-'
  else
    echo '-'
  fi
}

# Format baris output (tanpa kotak)
ROW_FMT='%-7s %-14s %-24s %-7s %-5s\n'
print_table_header() {
  printf "$ROW_FMT" "ID" "Username" "IP Address:Port" "Start" "Total"
}
print_row() {
  printf "$ROW_FMT" \
    "$(sanitize_field "$1")" "$(sanitize_field "$2")" \
    "$(sanitize_field "$3")" "$(sanitize_field "$4")" "$(sanitize_field "$5")"
}

# =============================================================
# Seksyen Dropbear
# =============================================================
echo
echo "-----=[ Dropbear User Login ]=------"

db_pids="$(ps -o pid= -C dropbear 2>/dev/null | tr -s ' \n' ' ' || true)"
db_rows=0

if [ -z "${db_pids// /}" ]; then
  echo "(no dropbear process found)"
else
  declare -A db_user db_ip db_port db_start db_total

  # Baca journal SEKALI sahaja, map pid -> user/ip/port
  if [ "$HAS_JOURNALCTL" -eq 1 ]; then
    journalctl --no-pager -u dropbear --since "$SEED_SINCE" -o short-iso 2>/dev/null \
      | sed -n "s/.*dropbear\[\([0-9]\+\)\].*auth succeeded for '\([^']\+\)'.* from \([0-9a-fA-F:.]\+\):\([0-9]\+\).*/\1 \2 \3 \4/p" \
      > "$TMP_JOURNAL" || true
    while IFS=' ' read -r pid user ip port; do
      [ -z "${pid:-}" ] && continue
      [ -n "${user:-}" ] && db_user["$pid"]="$user"
      [ -n "${ip:-}" ]   && db_ip["$pid"]="$ip"
      [ -n "${port:-}" ] && db_port["$pid"]="$port"
    done < "$TMP_JOURNAL"
  fi

  # Fallback alamat dari ss/lsof + masa mula
  for pid in $db_pids; do
    [ -z "$pid" ] && continue
    if [ -z "${db_ip[$pid]:-}" ]; then
      addr="$(get_addr_from_ss "$pid")"
      [ -z "$addr" ] && addr="$(get_addr_from_lsof "$pid")"
      if [ -n "$addr" ]; then
        read -r _ip _port <<<"$(parse_peer "$addr")"
        [ -n "${_ip:-}" ]   && db_ip["$pid"]="$_ip"
        [ -n "${_port:-}" ] && db_port["$pid"]="$_port"
      fi
    fi
    db_start["$pid"]="$(pid_start_epoch "$pid")"
  done

  # Kira total HANYA untuk baris yang akan dipapar
  show_pids=()
  for pid in $db_pids; do
    [ -z "$pid" ] && continue
    user="${db_user[$pid]:-}"
    ip="${db_ip[$pid]:-}"
    [ -z "$user" ] || [ -z "$ip" ] && continue
    [ "$(lower "$user")" = "root" ] && [ "$SKIP_ROOT" -eq 1 ] && continue
    show_pids+=("$pid")
    db_total["$user"]=$(( ${db_total["$user"]:-0} + 1 ))
  done

  if [ "${#show_pids[@]}" -eq 0 ]; then
    echo "(No User Login Detected)"
  else
    print_table_header
    for pid in "${show_pids[@]}"; do
      user="${db_user[$pid]}"
      ip="${db_ip[$pid]}"
      port="${db_port[$pid]:-}"
      ipport="$ip"; [ -n "$port" ] && ipport="${ip}:${port}"
      print_row "$pid" "$user" "$ipport" "$(epoch_to_hm "${db_start[$pid]:-0}")" "${db_total[$user]:-1}"
      db_rows=$((db_rows + 1))
    done
  fi
fi

echo
if [ "$db_rows" -gt 0 ]; then
  echo "Total All Online Users: $db_rows"
else
  echo "(No Dropbear Sessions Detected)"
fi
echo "------------------------------------"

# =============================================================
# Seksyen OpenSSH
# =============================================================
echo
echo "-----=[ OpenSSH User Login ]=------"

declare -A s_user s_ip s_port s_start s_owner s_total

# Journal: Debian/Ubuntu guna unit "ssh"; distro lain "sshd" — cuba kedua-duanya
if [ "$HAS_JOURNALCTL" -eq 1 ]; then
  journalctl --no-pager -u ssh -u sshd --since "$SEED_SINCE" -o short-iso 2>/dev/null \
    | sed -n 's/.*sshd\[\([0-9]\+\)\].*Accepted [^ ]* for \([^ ]\+\) from \([^ ]\+\) port \([0-9]\+\).*/\1 \2 \3 \4/p' \
    > "$TMP_JOURNAL" || true
  while IFS=' ' read -r pid user ip port; do
    [ -z "${pid:-}" ] && continue
    [ -n "${user:-}" ] && s_user["$pid"]="$user"
    [ -n "${ip:-}" ]   && s_ip["$pid"]="$ip"
    [ -n "${port:-}" ] && s_port["$pid"]="$port"
  done < "$TMP_JOURNAL"
fi

# Sambungan aktif dari ss
ss -Htnp 2>/dev/null | grep -F '"sshd"' > "$TMP_SS" || true

ssh_pids=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  peer="$(awk '{ print $(NF-1) }' <<<"$line")"
  # Boleh ada beberapa pid= dalam satu baris users:(...)
  while read -r pid; do
    [ -z "$pid" ] && continue
    if [ -z "${s_start[$pid]:-}" ]; then
      ssh_pids+=("$pid")
      s_start["$pid"]="$(pid_start_epoch "$pid")"
    fi
    read -r _ip _port <<<"$(parse_peer "$peer")"
    [ -n "${s_ip[$pid]:-}" ]   || { [ -n "${_ip:-}" ] && s_ip["$pid"]="$_ip"; }
    [ -n "${s_port[$pid]:-}" ] || { [ -n "${_port:-}" ] && s_port["$pid"]="$_port"; }

    owner="$(ps -p "$pid" -o user= 2>/dev/null | tr -d ' ' || true)"
    s_owner["$pid"]="$owner"

    if [ -z "${s_user[$pid]:-}" ]; then
      cmd="$(ps -p "$pid" -o cmd= 2>/dev/null || true)"
      if [[ "$cmd" =~ sshd:[[:space:]]+([^@[:space:]]+) ]]; then
        s_user["$pid"]="${BASH_REMATCH[1]}"
      fi
    fi
  done < <(grep -o 'pid=[0-9]\+' <<<"$line" | cut -d= -f2 | sort -u)
done < "$TMP_SS"

# Susun ikut masa mula (terbaru dahulu) dan tapis
sorted_pids=()
if [ "${#ssh_pids[@]}" -gt 0 ]; then
  while IFS=$'\t' read -r _ts pid; do
    sorted_pids+=("$pid")
  done < <(for p in "${ssh_pids[@]}"; do printf '%s\t%s\n' "${s_start[$p]:-0}" "$p"; done | sort -rn)
fi

show_pids=()
for pid in "${sorted_pids[@]}"; do
  user="${s_user[$pid]:-${s_owner[$pid]:-}}"
  [ -z "$user" ] && continue
  user_lc="$(lower "$user")"
  [ "$user_lc" = "root" ] && [ "$SKIP_ROOT" -eq 1 ] && continue
  [ "$user_lc" = "sshd" ] || [ "$user_lc" = "unknown" ] && continue
  show_pids+=("$pid")
  s_total["$user"]=$(( ${s_total["$user"]:-0} + 1 ))
done

ssh_rows=0
if [ "${#show_pids[@]}" -eq 0 ]; then
  echo "(No User Login Detected)"
else
  print_table_header
  for pid in "${show_pids[@]}"; do
    user="${s_user[$pid]:-${s_owner[$pid]}}"
    ip="${s_ip[$pid]:-unknown}"
    port="${s_port[$pid]:-}"
    ipport="$ip"; [ -n "$port" ] && ipport="${ip}:${port}"
    print_row "$pid" "$user" "$ipport" "$(epoch_to_hm "${s_start[$pid]:-0}")" "${s_total[$user]:-1}"
    ssh_rows=$((ssh_rows + 1))
  done
fi

echo
if [ "$ssh_rows" -gt 0 ]; then
  echo "Total All Online Users: $ssh_rows"
else
  echo "(No OpenSSH Sessions Detected)"
fi
echo "------------------------------------"

# =============================================================
# Seksyen OpenVPN
# =============================================================
print_openvpn() {
  local label="$1" logfile="$2"
  [ -f "$logfile" ] || return 0
  echo
  echo "----=[ OpenVPN $label User Login ]=----"
  printf '%-14s %-24s %s\n' "Username" "IP Address" "Connected Since"
  awk -F',' '/^CLIENT_LIST/ { printf "%-14s %-24s %s\n", $2, $3, $8 }' "$logfile" 2>/dev/null || true
}

print_openvpn "TCP" "/etc/openvpn/server/openvpn-tcp.log"
print_openvpn "UDP" "/etc/openvpn/server/openvpn-udp.log"

exit 0
