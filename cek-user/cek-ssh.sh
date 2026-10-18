#!/usr/bin/env bash
# cek-ssh.sh — papar sesi login aktif Dropbear / OpenSSH / OpenVPN
# Jalankan sebagai root (sudo) supaya journalctl/ss/lsof dapat maklumat penuh.
#
# Guna:
#   sudo ./cek-ssh.sh                 # boot semasa sahaja
#   sudo ./cek-ssh.sh "2 hours ago"   # hadkan tempoh (dalam boot semasa)
#   sudo ./cek-ssh.sh --all           # tunjuk root juga
#   sudo ./cek-ssh.sh --debug         # tunjuk baris yang ditapis + sebab
#
# Serasi: Debian / Ubuntu (bash 4+, systemd, iproute2)

set -u -o pipefail
export LANG=en_US.UTF-8

# ---------------------------
# Parse argumen (flag vs tempoh)
# ---------------------------
SEED_SINCE=""
SKIP_ROOT=1
DEBUG=0
for a in "$@"; do
  case "$a" in
    --all|-a)     SKIP_ROOT=0 ;;
    --no-root|-n) SKIP_ROOT=1 ;;
    --debug|-d)   DEBUG=1 ;;
    -h|--help)
      sed -n '2,13p' "$0"; exit 0 ;;
    *) SEED_SINCE="$a" ;;
  esac
done

debug() { [ "$DEBUG" -eq 1 ] && printf 'DEBUG: %s\n' "$*" >&2; return 0; }

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

normalize_ip() {
  local ip="$1"
  ip="${ip#[}"; ip="${ip%]}"
  printf '%s' "${ip#::ffff:}"
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
  printf '%s %s' "$(normalize_ip "$ip")" "$port"
}

# Padan alamat dalam journal dengan peer socket sebenar.
# Ini yang menghalang "ghost row" akibat PID diguna semula.
peer_matches() {
  local jip jport lip lport
  jip="$(normalize_ip "$1")"; jport="$2"; lip=""; lport=""
  read -r lip lport <<<"$(parse_peer "$3")"
  [ -n "$jip" ] && [ -n "$lip" ] || return 1
  [ "$jip" = "$lip" ] || return 1
  [ -z "$jport" ] && return 0
  [ -z "$lport" ] && return 0
  [ "$jport" = "$lport" ]
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

# Bina peta PID -> peer daripada socket ESTABLISHED sahaja.
# Sumber kebenaran: proses mesti benar-benar ada sambungan aktif.
# Zombie / proses pra-auth tanpa socket tidak akan masuk senarai.
#
# PENTING: proses dropbear/sshd juga memegang socket trafik yang di-forward
# (ssh -L/-R/-D, proxy). Socket tu ada local port ephemeral, BUKAN port
# perkhidmatan. Kita tapis ikut port listen (22/109/143 dsb.) supaya yang
# diambil hanya socket sesi SSH sebenar, bukan trafik proxy pengguna.
declare -A LIVE_PEER=()
declare -A LISTEN_PORT=()

map_listen_ports() {
  local proc="$1" line la
  LISTEN_PORT=()
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    la="$(awk '{ print $4 }' <<<"$line")"
    LISTEN_PORT["${la##*:}"]=1
  done < <(ss -Htlnp 2>/dev/null | awk '$1=="LISTEN"' | grep -F "\"$proc\"")
}

map_established() {
  local proc="$1" line lport peer pid
  LIVE_PEER=()
  map_listen_ports "$proc"

  ss -Htnp 2>/dev/null | awk '$1=="ESTAB"' | grep -F "\"$proc\"" > "$TMP_SS" || true
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    # Hanya socket yang local port-nya port listen = sambungan sesi SSH
    if [ "${#LISTEN_PORT[@]}" -gt 0 ]; then
      lport="$(awk '{ print $4 }' <<<"$line")"; lport="${lport##*:}"
      if [ -z "${LISTEN_PORT[$lport]:-}" ]; then
        debug "$proc: langkau socket keluar local port $lport (trafik forward/proxy)"
        continue
      fi
    fi

    peer="$(awk '{ print $(NF-1) }' <<<"$line")"
    while IFS= read -r pid; do
      [ -n "$pid" ] && LIVE_PEER["$pid"]="$peer"
    done < <(grep -o 'pid=[0-9]\+' <<<"$line" | cut -d= -f2 | sort -u)
  done < "$TMP_SS"
}

journal_dropbear() {
  local jargs=(--no-pager -b -u dropbear -o short-iso)
  [ -n "$SEED_SINCE" ] && jargs+=(--since "$SEED_SINCE")
  journalctl "${jargs[@]}" 2>/dev/null \
    | sed -n "s/.*dropbear\[\([0-9]\+\)\].*auth succeeded for '\([^']\+\)'.* from \([0-9a-fA-F:.]\+\):\([0-9]\+\).*/\1 \2 \3 \4/p" \
    > "$TMP_JOURNAL" || true
}

journal_sshd() {
  local jargs=(--no-pager -b -u ssh -u sshd -o short-iso)
  [ -n "$SEED_SINCE" ] && jargs+=(--since "$SEED_SINCE")
  journalctl "${jargs[@]}" 2>/dev/null \
    | sed -n 's/.*sshd\[\([0-9]\+\)\].*Accepted [^ ]* for \([^ ]\+\) from \([^ ]\+\) port \([0-9]\+\).*/\1 \2 \3 \4/p' \
    > "$TMP_JOURNAL" || true
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

declare -A db_user db_ip db_port db_start db_total
map_established dropbear

if [ "${#LIVE_PEER[@]}" -eq 0 ]; then
  echo "(No User Login Detected)"
else
  if [ "$HAS_JOURNALCTL" -eq 1 ]; then
    journal_dropbear
    while IFS=' ' read -r pid user ip port; do
      [ -z "${pid:-}" ] && continue
      [ -n "${user:-}" ] && db_user["$pid"]="$user"
      [ -n "${ip:-}" ]   && db_ip["$pid"]="$ip"
      [ -n "${port:-}" ] && db_port["$pid"]="$port"
    done < "$TMP_JOURNAL"
  fi

  show_pids=()
  for pid in "${!LIVE_PEER[@]}"; do
    user="${db_user[$pid]:-}"
    if [ -z "$user" ]; then
      debug "dropbear pid $pid: tiada rekod auth (pra-auth/belum login) — langkau"
      continue
    fi

    jip="${db_ip[$pid]:-}"; jport="${db_port[$pid]:-}"
    if [ -n "$jip" ] && ! peer_matches "$jip" "$jport" "${LIVE_PEER[$pid]}"; then
      debug "dropbear pid $pid: journal ${jip}:${jport} != socket ${LIVE_PEER[$pid]} (PID diguna semula) — langkau"
      continue
    fi

    [ "$(lower "$user")" = "root" ] && [ "$SKIP_ROOT" -eq 1 ] && continue

    show_pids+=("$pid")
    db_start["$pid"]="$(pid_start_epoch "$pid")"
    db_total["$user"]=$(( ${db_total["$user"]:-0} + 1 ))
  done

  db_rows=0
  if [ "${#show_pids[@]}" -eq 0 ]; then
    echo "(No User Login Detected)"
  else
    # Susun ikut masa mula (lama dulu)
    ordered=()
    while IFS=' ' read -r _ts p; do ordered+=("$p"); done < <(
      for p in "${show_pids[@]}"; do printf '%s %s\n' "${db_start[$p]:-0}" "$p"; done | sort -n
    )

    print_table_header
    for pid in "${ordered[@]}"; do
      user="${db_user[$pid]}"
      read -r ip port <<<"$(parse_peer "${LIVE_PEER[$pid]}")"
      # Fallback: jika IPv6 tanpa port, guna nilai journal
      [ -z "$ip" ] && ip="${db_ip[$pid]:-unknown}"
      [ -z "$port" ] && port="${db_port[$pid]:-}"
      ipport="$ip"; [ -n "$port" ] && ipport="${ip}:${port}"
      print_row "$pid" "$user" "$ipport" "$(epoch_to_hm "${db_start[$pid]:-0}")" "${db_total[$user]:-1}"
      db_rows=$((db_rows + 1))
    done
  fi
fi

echo
if [ "${db_rows:-0}" -gt 0 ]; then
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
map_established sshd

if [ "${#LIVE_PEER[@]}" -eq 0 ]; then
  echo "(No User Login Detected)"
  ssh_rows=0
else
  if [ "$HAS_JOURNALCTL" -eq 1 ]; then
    journal_sshd
    while IFS=' ' read -r pid user ip port; do
      [ -z "${pid:-}" ] && continue
      [ -n "${user:-}" ] && s_user["$pid"]="$user"
      [ -n "${ip:-}" ]   && s_ip["$pid"]="$ip"
      [ -n "${port:-}" ] && s_port["$pid"]="$port"
    done < "$TMP_JOURNAL"
  fi

  show_pids=()
  for pid in "${!LIVE_PEER[@]}"; do
    user="${s_user[$pid]:-}"

    # Tolak rekod journal yang tidak padan dengan socket sebenar
    if [ -n "$user" ] && [ -n "${s_ip[$pid]:-}" ] \
       && ! peer_matches "${s_ip[$pid]}" "${s_port[$pid]:-}" "${LIVE_PEER[$pid]}"; then
      debug "sshd pid $pid: journal ${s_ip[$pid]}:${s_port[$pid]:-} != socket ${LIVE_PEER[$pid]} (PID diguna semula) — buang rekod journal"
      user=""
    fi

    # Fallback 1: nama dari cmd proses (sshd: user@pts/N)
    if [ -z "$user" ]; then
      cmd="$(ps -p "$pid" -o cmd= 2>/dev/null || true)"
      if [[ "$cmd" =~ sshd:[[:space:]]+([^@[:space:]]+)@ ]]; then
        user="${BASH_REMATCH[1]}"
      fi
    fi

    # Fallback 2: pemilik proses (monitor sshd = root, jadi hanya jika bukan root)
    if [ -z "$user" ]; then
      owner="$(ps -p "$pid" -o user= 2>/dev/null | tr -d ' ' || true)"
      s_owner["$pid"]="$owner"
      user="$owner"
    fi

    [ -z "$user" ] && { debug "sshd pid $pid: tiada user — langkau"; continue; }
    user_lc="$(lower "$user")"
    [ "$user_lc" = "root" ] && [ "$SKIP_ROOT" -eq 1 ] && continue
    { [ "$user_lc" = "sshd" ] || [ "$user_lc" = "unknown" ]; } && continue

    show_pids+=("$pid")
    s_start["$pid"]="$(pid_start_epoch "$pid")"
    s_total["$user"]=$(( ${s_total["$user"]:-0} + 1 ))
  done

  ssh_rows=0
  if [ "${#show_pids[@]}" -eq 0 ]; then
    echo "(No User Login Detected)"
  else
    ordered=()
    while IFS=' ' read -r _ts p; do ordered+=("$p"); done < <(
      for p in "${show_pids[@]}"; do printf '%s %s\n' "${s_start[$p]:-0}" "$p"; done | sort -rn
    )

    print_table_header
    for pid in "${ordered[@]}"; do
      user="${s_user[$pid]:-${s_owner[$pid]:-unknown}}"
      read -r ip port <<<"$(parse_peer "${LIVE_PEER[$pid]}")"
      [ -z "$ip" ] && ip="${s_ip[$pid]:-unknown}"
      [ -z "$port" ] && port="${s_port[$pid]:-}"
      ipport="$ip"; [ -n "$port" ] && ipport="${ip}:${port}"
      print_row "$pid" "$user" "$ipport" "$(epoch_to_hm "${s_start[$pid]:-0}")" "${s_total[$user]:-1}"
      ssh_rows=$((ssh_rows + 1))
    done
  fi
fi

echo
if [ "${ssh_rows:-0}" -gt 0 ]; then
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
