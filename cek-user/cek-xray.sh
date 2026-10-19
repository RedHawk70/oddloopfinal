#!/bin/bash

clear
LOGFILE="${LOGFILE:-/var/log/xray/access.log}"
LOGLINES="${LOGLINES:-50000}"
CONFIGS="${CONFIGS:-/usr/local/etc/xray/config.json /usr/local/etc/xray/none.json}"

echo -e "\033[0;34m------------------------------------------\033[0m"
echo -e "\E[0;44;37m  ALL USER LOGIN XRAY VLESS/VMESS/TROJAN  \E[0m"
echo -e "\033[0;34m------------------------------------------\033[0m"

if [[ ! -f "$LOGFILE" ]]; then
  echo "Log file tak jumpa: $LOGFILE"
  echo ""
  read -n 1 -s -r -p "Press any key to back on main menu"
  exec menu
fi

# ============================================================
# SENARAI USER YANG SEDANG BLOCKED
# Sumber: config (email: blocked-xxx) + log
# ============================================================
HAVE_CONFIG=0
BLOCKED=""
for cfg in $CONFIGS; do
  [ -f "$cfg" ] || continue
  HAVE_CONFIG=1
  BLOCKED="$BLOCKED $(grep -oE '"email"[[:space:]]*:[[:space:]]*"blocked-[A-Za-z0-9_]+"' "$cfg" 2>/dev/null | sed -E 's/.*"blocked-([A-Za-z0-9_]+)"/\1/')"
done
# Fallback: kalau config tiada, anggap blocked berdasarkan log
if [ "$HAVE_CONFIG" -eq 0 ]; then
  BLOCKED="$(tail -n "$LOGLINES" "$LOGFILE" 2>/dev/null | grep -oE 'email:[[:space:]]*blocked-[A-Za-z0-9_]+' | sed -E 's/.*blocked-//')"
fi
BLOCKED="$(printf '%s\n' $BLOCKED | sort -u | tr '\n' ' ')"

tail -n "$LOGLINES" "$LOGFILE" 2>/dev/null | \
awk -v blocked_list="$BLOCKED" -v have_config="$HAVE_CONFIG" '
function clean_ip(s) {
  sub(/^tcp:/, "", s)
  sub(/^udp:/, "", s)
  gsub(/[",]/, "", s)
  # IPv6 dalam bracket: [2001:db8::1]:port
  if (s ~ /^\[/) { sub(/^\[/, "", s); sub(/\].*/, "", s); return s }
  # IPv4:port
  if (s ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/) { sub(/:[0-9]+$/, "", s); return s }
  return s
}
function clean_user(s) {
  sub(/^email:/, "", s)
  gsub(/^[[:space:]]+/, "", s)
  gsub(/[[:space:]]+$/, "", s)
  gsub(/[",]/, "", s)
  return s
}
function looks_like_ip(s) {
  # IPv4
  if (s ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) return 1
  # IPv6
  if (s ~ /^[0-9a-fA-F:]+$/ && s ~ /:/) return 1
  # IPv4-mapped IPv6
  if (s ~ /^[0-9a-fA-F:.]+$/ && s ~ /:/ && s ~ /\./) return 1
  return 0
}
BEGIN {
  n = split(blocked_list, b, " ")
  for (i = 1; i <= n; i++) if (b[i] != "") blocked[b[i]] = 1
}
{
  ip=""; user="";

  # username/email (support "email: USER" & "email:USER")
  for (i=1; i<=NF; i++) {
    if ($i=="email:" && (i+1)<=NF) { user=$(i+1); break }
    if ($i ~ /^email:/)            { user=clean_user($i); break }
  }
  if (user=="") next

  # ========================================================
  # NORMALISASI BLOCKED:
  #   luffy + blocked-luffy  ->  blocked-luffy (satu entri)
  # ========================================================
  if (user ~ /^blocked-/) {
    u=user
    sub(/^blocked-/, "", u)
    if (have_config == 1) {
      # status semasa ikut config: jika sudah unblock, papar nama asal
      if (u in blocked) user="blocked-" u
      else user=u
    } else {
      blocked[u]=1
      user="blocked-" u
    }
  } else if (user in blocked) {
    user="blocked-" user
  }

  # Ambil client IP selepas perkataan "from" (format log: from IP:PORT)
  for (i=1; i<=NF; i++) {
    if ($i=="from" && (i+1)<=NF) {
      ip = clean_ip($(i+1))
      break
    }
  }

  # fallback: sesetengah format letak IP di field ke-4
  if (ip=="" && NF>=4) ip = clean_ip($4)

  if (!looks_like_ip(ip)) next

  key = user SUBSEP ip
  if (!(key in seen)) {
    seen[key]=1
    ips[user] = ips[user] ip "|"
  }
}

END {
  for (u in ips) {
    printf "%s\t%s\n", u, ips[u]
  }
}' | \
sort -t $'\t' -k1,1 | \
awk -F'\t' '
BEGIN { user_idx=0 }
{
  user=$1
  ipstr=$2

  user_idx++
  printf "%d) user : %s\n", user_idx, user

  n = split(ipstr, a, /\|/)
  idx=0
  for (i=1; i<=n; i++) {
    if (a[i] != "") {
      idx++
      printf "%d. %s\n", idx, a[i]
    }
  }
  print ""
  print "------------------------------------------"
}
END {
  if (user_idx==0) {
    print "No User Login Detected."
    print "------------------------------------------"
  }
}'

echo ""
read -n 1 -s -r -p "Press any key to back on main menu"
exec menu
