#!/bin/bash
GitUser="RedHawk70"

# // IZIN SCRIPT
export MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -s ipinfo.io/ip )
MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -sS ifconfig.me )
clear

# // PROVIDED && MY IP
export MYIP=$(wget -qO- ifconfig.me/ip);
source /var/lib/premium-script/ipvps.conf
export creditt=$(cat /root/provided)

# // BANNER COLOUR
export banner_colour=$(cat /etc/banner)

# // TEXT ON BOX COLOUR
export box=$(cat /etc/box)

# // LINE COLOUR
export line=$(cat /etc/line)

# // TEXT COLOUR ON TOP
export text=$(cat /etc/text)

# // TEXT COLOUR BELOW
export below=$(cat /etc/below)

# // BACKGROUND TEXT COLOUR
export back_text=$(cat /etc/back)

# // NUMBER COLOUR
export number=$(cat /etc/number)

# // TOTAL ACC CREATE  TROJAN
export total=$(grep -c -E "^#trx " "/usr/local/etc/xray/config.json")

# // TOTAL ACC CREATE  TROJAN WS TLS
export total2=$(grep -c -E "^#trws " "/usr/local/etc/xray/config.json")
if [[ "$IP" = "" ]]; then
    domain=$(cat /usr/local/etc/xray/domain)
else
    domain=$IP
fi

# ============================================================
# LIMIT IP & LIMIT QUOTA — DATABASE, ENGINE & HELPER
# ============================================================
LIMIT_DB="/etc/xray/limit.db"
LIMIT_BIN="/usr/local/bin/xray-limit"
LIMIT_CRON="/etc/cron.d/xray-limit"

limit_db_init() {
    mkdir -p "$(dirname "$LIMIT_DB")"
    [ -f "$LIMIT_DB" ] || : > "$LIMIT_DB"
    chmod 600 "$LIMIT_DB" 2>/dev/null
}

# limit_db_set <user> <ip_limit> <quota_gb> <proto>
limit_db_set() {
    local u="$1" ip="${2:-0}" q="${3:-0}" pr="${4:-vless}"
    local used=0 blocked=0 reason="" row tmp
    limit_db_init
    row="$(grep -m1 "^${u}|" "$LIMIT_DB" 2>/dev/null)"
    if [ -n "$row" ]; then
        used="$(printf '%s' "$row" | cut -d'|' -f4)"; [ -z "$used" ] && used=0
        blocked="$(printf '%s' "$row" | cut -d'|' -f5)"; [ -z "$blocked" ] && blocked=0
        reason="$(printf '%s' "$row" | cut -d'|' -f7)"
    fi
    tmp="$(mktemp)"
    grep -v "^${u}|" "$LIMIT_DB" > "$tmp" 2>/dev/null
    printf '%s|%s|%s|%s|%s|%s|%s\n' "$u" "$ip" "$q" "$used" "$blocked" "$pr" "$reason" >> "$tmp"
    mv "$tmp" "$LIMIT_DB"
    chmod 600 "$LIMIT_DB" 2>/dev/null
}

limit_db_del() {
    local u="$1" tmp f
    [ -f "$LIMIT_DB" ] || return 0
    tmp="$(mktemp)"
    grep -v "^${u}|" "$LIMIT_DB" > "$tmp" 2>/dev/null
    mv "$tmp" "$LIMIT_DB"
    chmod 600 "$LIMIT_DB" 2>/dev/null
    # bersihkan state enjin untuk user ini
    [ -f /var/lib/xray-limit/breach ] && sed -i "/^${u}|/d" /var/lib/xray-limit/breach 2>/dev/null
    for f in /var/lib/xray-limit/*.snap; do
        [ -f "$f" ] && sed -i "/^${u}|/d;/^blocked-${u}|/d" "$f" 2>/dev/null
    done
}

# limit_db_get <user> -> user|ip|quota|used|blocked|proto|reason
limit_db_get() {
    [ -f "$LIMIT_DB" ] || return 1
    grep -m1 "^${1}|" "$LIMIT_DB" 2>/dev/null
}

limit_db_reset_usage() {
    local u="$1"
    [ -f "$LIMIT_DB" ] || return 0
    awk -F'|' -v u="$u" 'BEGIN{OFS="|"} $1==u{$4=0;$5=0;$7=""} {print}' "$LIMIT_DB" > "${LIMIT_DB}.tmp" && mv "${LIMIT_DB}.tmp" "$LIMIT_DB"
}

limit_unblock() {
    local u="$1" f
    for f in /usr/local/etc/xray/config.json /usr/local/etc/xray/none.json; do
        [ -f "$f" ] || continue
        sed -i "s/\"email\": \"blocked-${u}\"/\"email\": \"${u}\"/g" "$f"
    done
    limit_db_reset_usage "$u"
    # reset breach counter supaya user dapat 2 semakan baru
    [ -f /var/lib/xray-limit/breach ] && sed -i "/^${u}|/d" /var/lib/xray-limit/breach 2>/dev/null
    for f in /var/lib/xray-limit/*.snap; do
        [ -f "$f" ] && sed -i "/^blocked-${u}|/d" "$f" 2>/dev/null
    done
}

limit_human() {
    awk -v b="${1:-0}" 'BEGIN{
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else printf "%.0f KB", b/1024;
    }'
}

# limit_print_info <user> [lebar_kolom]
# Papar maklumat limit sejajar dengan format panel (VMess/XTLS=15, VLESS=22)
limit_print_info() {
    local u="$1" pad="${2:-20}" row ip q used blocked reason
    ip=0; q=0; used=0; blocked=0; reason=""
    row="$(limit_db_get "$u")"
    if [ -n "$row" ]; then
        ip="$(printf '%s' "$row" | cut -d'|' -f2)"
        q="$(printf '%s' "$row" | cut -d'|' -f3)"
        used="$(printf '%s' "$row" | cut -d'|' -f4)"
        blocked="$(printf '%s' "$row" | cut -d'|' -f5)"
        reason="$(printf '%s' "$row" | cut -d'|' -f7)"
    fi
    [ -z "$ip" ] && ip=0
    [ -z "$q" ] && q=0
    [ -z "$used" ] && used=0
    [ -z "$blocked" ] && blocked=0

    local ip_txt="$ip"
    [ "$ip" = "0" ] && ip_txt="0 (unlimited)"
    local q_txt="${q} GB"
    [ "$q" = "0" ] && q_txt="0 GB (unlimited)"
    local st="ACTIVE"
    [ "$blocked" = "1" ] && st="BLOCKED"
    [ -n "$reason" ] && st="${st} (${reason})"

    awk -v pad="$pad" -v ip="$ip_txt" -v q="$q_txt" \
        -v used="$(limit_human "$used")" -v st="$st" 'BEGIN{
        fmt = "%-" pad "s: %s\n"
        printf fmt, "Limit IP", ip
        printf fmt, "Limit Quota", q
        printf fmt, "Quota Used", used
        printf fmt, "Status", st
    }'
}

# limit_change_menu <user> <proto> <pad>
# Tukar Limit IP & Limit Quota user sedia ada
limit_change_menu() {
    local u="$1" pr="${2:-vless}" pad="${3:-20}"
    local row ip q blocked cur_pr new_ip new_q ans

    ip=0; q=0; blocked=0; cur_pr="$pr"
    row="$(limit_db_get "$u")"
    if [ -n "$row" ]; then
        ip="$(printf '%s' "$row" | cut -d'|' -f2)"
        q="$(printf '%s' "$row" | cut -d'|' -f3)"
        blocked="$(printf '%s' "$row" | cut -d'|' -f5)"
        cur_pr="$(printf '%s' "$row" | cut -d'|' -f6)"
    fi
    [ -z "$ip" ] && ip=0
    [ -z "$q" ] && q=0
    [ -z "$blocked" ] && blocked=0
    [ -z "$cur_pr" ] && cur_pr="$pr"

    clear
    echo -e ""
    echo -e "\e[$line══════════════════════════════════════════\e[m"
    echo -e "\e[$back_text  \e[30m[\e[$box CHANGE LIMIT IP & QUOTA\e[30m ]\e[1m  \e[m"
    echo -e "\e[$line══════════════════════════════════════════\e[m"
    echo -e "User       : $u"
    echo ""
    limit_print_info "$u" "$pad"
    echo -e "\e[$line══════════════════════════════════════════\e[m"
    echo ""

    read -rp "   Limit IP baru (Enter = kekal ${ip}) : " new_ip
    read -rp "   Limit Quota GB baru (Enter = kekal ${q}) : " new_q

    [ -z "$new_ip" ] && new_ip="$ip"
    [ -z "$new_q" ] && new_q="$q"

    if ! [[ "$new_ip" =~ ^[0-9]+$ ]]; then
        echo ""
        echo "Limit IP tak sah - mesti nombor."
        sleep 2
        return 1
    fi

    if ! [[ "$new_q" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo ""
        echo "Limit Quota tak sah - mesti nombor."
        sleep 2
        return 1
    fi

    limit_db_set "$u" "$new_ip" "$new_q" "$cur_pr"

    # kalau user blocked, tawarkan unblock serta-merta
    if [ "$blocked" = "1" ]; then
        echo ""
        read -rp "   User ini BLOCKED. Unblock sekarang? (y/n) : " ans
        case "$ans" in
            y|Y)
                limit_unblock "$u"
                systemctl stop xray >/dev/null 2>&1
                systemctl stop xray@config >/dev/null 2>&1
                systemctl start xray >/dev/null 2>&1
                systemctl start xray@config >/dev/null 2>&1
                systemctl restart xray@none >/dev/null 2>&1
                echo "   User di-unblock, quota & breach di-reset."
                ;;
            *)
                echo "   Kekal BLOCKED."
                ;;
        esac
    fi

    echo ""
    echo " Limit berjaya dikemaskini :"
    limit_print_info "$u" "$pad"
    echo ""
    read -n 1 -s -r -p " Press any key to back on menu Trojan"
    echo ""
}

limit_engine_ensure() {
    limit_db_init
    if ! grep -q "XRAY_LIMIT_VERSION=6" "$LIMIT_BIN" 2>/dev/null; then
        cat > "$LIMIT_BIN" <<'XRAYLIMITENGINE'
#!/bin/bash
# ============================================================
# xray-limit v2 — enforcement Limit IP + Limit Quota
# Dijana automatik oleh xraay2.sh (jangan edit manual)
#
# Guna:
#   xray-limit                 -> run enforcement (cron)
#   xray-limit debug           -> diagnostik (log, IP, stats API, DB)
#   xray-limit status          -> senarai limit & penggunaan
#   xray-limit unblock <user>  -> buka blok + reset quota
# ============================================================
XRAY_LIMIT_VERSION=6

DB="${XRAY_LIMIT_DB:-/etc/xray/limit.db}"
ACCESS="${XRAY_LIMIT_ACCESS:-/var/log/xray/access.log}"
CFG_TLS="${XRAY_LIMIT_CFG_TLS:-/usr/local/etc/xray/config.json}"
CFG_NON="${XRAY_LIMIT_CFG_NON:-/usr/local/etc/xray/none.json}"
XRAY_BIN="${XRAY_LIMIT_XRAY:-xray}"
SYSTEMCTL="${XRAY_LIMIT_SYSTEMCTL:-systemctl}"
LOCK="${XRAY_LIMIT_LOCK:-/var/run/xray-limit.lock}"
STATE_DIR="${XRAY_LIMIT_STATE_DIR:-/var/lib/xray-limit}"
LOG="/var/log/xray-limit.log"
IP_WINDOW="${XRAY_LIMIT_IP_WINDOW:-90}"
BREACH_STREAK="${XRAY_LIMIT_BREACH_STREAK:-2}"

SNAP_TLS="$STATE_DIR/stats-tls.snap"
SNAP_NON="$STATE_DIR/stats-none.snap"
BREACH="$STATE_DIR/breach"
CUR_TMP="$STATE_DIR/cur.tmp"
DELTA_TMP="$STATE_DIR/delta.tmp"

# ---------- util ----------
log_msg() { logger -t xray-limit "$*" 2>/dev/null; }
dbg() { [ "${XRAY_LIMIT_DEBUG:-0}" = "1" ] && printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

human() {
    awk -v b="${1:-0}" 'BEGIN{
        if (b >= 1073741824) printf "%.2f GB", b/1073741824;
        else if (b >= 1048576) printf "%.2f MB", b/1048576;
        else printf "%.0f KB", b/1024;
    }'
}

# port API (dokodemo-door) diambil terus dari config — tak hardcode
api_port() {
    awk '
        /"port"[[:space:]]*:/ { p=$0 }
        /dokodemo-door/ { if (match(p, /[0-9]+/)) { print substr(p, RSTART, RLENGTH); exit } }
    ' "$1" 2>/dev/null
}

API_TLS="${XRAY_LIMIT_API_TLS:-127.0.0.1:$(api_port "$CFG_TLS")}"
API_NON="${XRAY_LIMIT_API_NON:-127.0.0.1:$(api_port "$CFG_NON")}"
[ "$API_TLS" = "127.0.0.1:" ] && API_TLS="127.0.0.1:10085"
[ "$API_NON" = "127.0.0.1:" ] && API_NON="127.0.0.1:10086"

mkdir -p "$STATE_DIR" 2>/dev/null
touch "$SNAP_TLS" "$SNAP_NON" 2>/dev/null

# ---------- quota: statistik ----------
# Output: "user|bytes" (jumlah uplink+downlink semasa, bukan delta)

# Format protobuf text:
#   name: "user>>>utut>>>traffic>>>uplink"
#   value: 12237
parse_stats_text() {
    awk '
        /^[[:space:]]*name:/ {
            line=$0
            if (line !~ /user>>>/) { cur=""; next }
            sub(/.*user>>>/, "", line)
            split(line, a, ">>>")
            cur=a[1]
            next
        }
        /^[[:space:]]*value:/ {
            if (cur != "") total[cur]+=$2
        }
        END { for (u in total) printf "%s|%d\n", u, total[u] }
    '
}

# Format JSON (pretty atau compact):
#   { "stat": [ { "name": "user>>>utut>>>traffic>>>uplink", "value": 12237 } ] }
parse_stats_json() {
    grep -oE '"(name|value)"[[:space:]]*:[[:space:]]*("[^"]*"|[0-9]+)' | awk '
        /^"name"/ {
            line=$0
            sub(/^"name"[[:space:]]*:[[:space:]]*"/, "", line)
            sub(/".*$/, "", line)
            if (line !~ /user>>>/) { cur=""; next }
            sub(/.*user>>>/, "", line)
            split(line, a, ">>>")
            cur=a[1]
            next
        }
        /^"value"/ {
            if (cur == "") next
            line=$0
            gsub(/[^0-9]/, "", line)
            if (line != "") total[cur]+=line
        }
        END { for (u in total) printf "%s|%d\n", u, total[u] }
    '
}

parse_stats() {
    local data
    data="$(cat)"
    if printf '%s' "$data" | grep -q '"stat"'; then
        printf '%s\n' "$data" | parse_stats_json
    else
        printf '%s\n' "$data" | parse_stats_text
    fi
}

stats_raw() {
    local api="$1" out rc
    out="$(timeout 15 "$XRAY_BIN" api statsquery --server="$api" -pattern 'user>>>' 2>/dev/null)"; rc=$?
    if [ $rc -ne 0 ]; then
        # fallback: sesetengah build tak terima -pattern
        out="$(timeout 15 "$XRAY_BIN" api statsquery --server="$api" 2>/dev/null)"; rc=$?
    fi
    printf '%s\n' "$out"
    return $rc
}

# Bandingkan nilai semasa dengan snapshot; pulangkan delta penggunaan.
quota_update_api() {
    local api="$1" snap="$2" raw rc
    raw="$(stats_raw "$api")"; rc=$?
    if [ $rc -ne 0 ]; then
        dbg "statsquery gagal api=$api rc=$rc"
        return 1
    fi
    if [ -z "$raw" ] && [ -s "$snap" ]; then
        dbg "statsquery kosong api=$api — snapshot dikekalkan"
        return 0
    fi

    printf '%s\n' "$raw" | parse_stats > "$CUR_TMP"

    : > "$DELTA_TMP"
    awk -F'|' -v snap="$snap" -v dfile="$DELTA_TMP" '
        FILENAME == snap { if (NF>=2) prev[$1]=$2; next }
        NF>=2 { cur[$1]=$2 }
        END {
            for (u in cur) {
                if (u in prev) {
                    p = prev[u]
                    d = (cur[u] >= p) ? cur[u]-p : cur[u]
                    if (d > 0) print u "|" d >> dfile
                }
                new[u] = cur[u]
            }
            # kekalkan snapshot user yang idle (tiada trafik baru)
            for (u in prev) if (!(u in new)) new[u] = prev[u]
            for (u in new) print u "|" sprintf("%.0f", new[u]) > snap
        }
    ' "$snap" "$CUR_TMP"

    cat "$DELTA_TMP"
}

add_usage() {
    local u="$1" b="$2"
    grep -q "^${u}|" "$DB" 2>/dev/null || return 0
    awk -F'|' -v u="$u" -v b="$b" 'BEGIN{OFS="|"} $1==u{$4=sprintf("%.0f", $4+b)} {print}' "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
}

# ---------- IP ----------
ip_counts() {
    [ -f "$ACCESS" ] || return 0
    local cuts cutd
    cuts="$(date -d "$IP_WINDOW seconds ago" '+%Y/%m/%d %H:%M:%S')"
    cutd="$(date -d "$IP_WINDOW seconds ago" '+%Y-%m-%d %H:%M:%S')"
    tail -n 20000 "$ACCESS" 2>/dev/null | awk -v cuts="$cuts" -v cutd="$cutd" '
        function clean(s) {
            sub(/^tcp:/, "", s)
            sub(/^udp:/, "", s)
            if (s ~ /^\[/) { sub(/^\[/, "", s); sub(/\].*/, "", s); return s }
            if (s ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/) sub(/:[0-9]+$/, "", s)
            return s
        }
        function isip(s) {
            if (s ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) return 1
            if (s ~ /^[0-9a-fA-F:]+$/ && s ~ /:/) return 1
            return 0
        }
        {
            # hanya baris yang ada timestamp sahaja
            if ($1 !~ /^[0-9][0-9][0-9][0-9][\/-][0-9][0-9][\/-][0-9][0-9]$/) next
            ts=$1" "$2
            if ($1 ~ /\//) { if (ts < cuts) next }
            else { if (ts < cutd) next }

            user=""
            for (i=1; i<=NF; i++) {
                if ($i == "email:" && i < NF) { user=$(i+1); break }
                if ($i ~ /^email:/) { user=$i; sub(/^email:/, "", user); break }
            }
            if (user == "") next
            gsub(/[",]/, "", user)

            # utamakan IP selepas perkataan "from"
            ip=""
            for (i=1; i<NF; i++) if ($i == "from") { ip=$(i+1); break }

            # fallback format: DATE TIME IP:PORT accepted ...
            if (ip == "") {
                ip=$3
                if (ip == "from" || ip == "accepted") ip=""
            }
            if (ip == "") next

            ip=clean(ip)
            if (!isip(ip)) next
            # abaikan IP dalaman (API/fallback) — bukan IP client sebenar
            if (ip == "127.0.0.1" || ip == "::1" || ip ~ /^127\./) next

            k=user SUBSEP ip
            if (!(k in seen)) { seen[k]=1; count[user]++ }
        }
        END { for (u in count) printf "%s %d\n", u, count[u] }
    '
}

# ---------- breach streak ----------
breach_get() {
    [ -f "$BREACH" ] || { echo 0; return; }
    awk -F'|' -v u="$1" -v t="$2" '$1==u && $2==t {print $3; f=1; exit} END{if(!f)print 0}' "$BREACH"
}

breach_set() {
    local u="$1" t="$2" c="${3:-0}" tmp
    tmp="$(mktemp)"
    [ -f "$BREACH" ] && grep -v "^${u}|${t}|" "$BREACH" > "$tmp" 2>/dev/null
    if [ "${c:-0}" -gt 0 ] 2>/dev/null; then
        printf '%s|%s|%s\n' "$u" "$t" "$c" >> "$tmp"
    fi
    mv "$tmp" "$BREACH" 2>/dev/null
}

# ---------- block / unblock ----------
block_user() {
    local u="$1" reason="$2" changed=0 f
    for f in "$CFG_TLS" "$CFG_NON"; do
        [ -f "$f" ] || continue
        if grep -q "\"email\": \"${u}\"" "$f"; then
            sed -i "s/\"email\": \"${u}\"/\"email\": \"blocked-${u}\"/g" "$f"
            changed=1
        fi
    done
    if [ "$changed" -eq 1 ]; then
        "$SYSTEMCTL" stop xray >/dev/null 2>&1
        "$SYSTEMCTL" stop xray@config >/dev/null 2>&1
        "$SYSTEMCTL" start xray >/dev/null 2>&1
        "$SYSTEMCTL" start xray@config >/dev/null 2>&1
        "$SYSTEMCTL" restart xray@none >/dev/null 2>&1
    fi
    awk -F'|' -v u="$u" -v r="$reason" 'BEGIN{OFS="|"} $1==u{$5=1;$7=r} {print}' "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
    log_msg "BLOCK user=${u} reason=${reason} (changed=${changed})"
}

limit_unblock() {
    local u="$1" f
    for f in "$CFG_TLS" "$CFG_NON"; do
        [ -f "$f" ] || continue
        sed -i "s/\"email\": \"blocked-${u}\"/\"email\": \"${u}\"/g" "$f"
    done
    if [ -f "$DB" ]; then
        awk -F'|' -v u="$u" 'BEGIN{OFS="|"} $1==u{$4=0;$5=0;$7=""} {print}' "$DB" > "${DB}.tmp" && mv "${DB}.tmp" "$DB"
    fi
    breach_set "$u" ip 0
    breach_set "$u" quota 0
    for f in "$SNAP_TLS" "$SNAP_NON"; do
        [ -f "$f" ] && sed -i "/^blocked-${u}|/d" "$f" 2>/dev/null
    done
    "$SYSTEMCTL" stop xray >/dev/null 2>&1
    "$SYSTEMCTL" stop xray@config >/dev/null 2>&1
    "$SYSTEMCTL" start xray >/dev/null 2>&1
    "$SYSTEMCTL" start xray@config >/dev/null 2>&1
    "$SYSTEMCTL" restart xray@none >/dev/null 2>&1
    echo "User ${u} di-unblock, quota di-reset."
}

# ---------- enforcement ----------
run_enforcement() {
    [ -s "$DB" ] || exit 0

    exec 9>"$LOCK" 2>/dev/null || exit 0
    flock -n 9 2>/dev/null || exit 0

    # 1) quota — kumpul delta
    local d1 d2 r1 r2
    d1="$(quota_update_api "$API_TLS" "$SNAP_TLS")"; r1=$?
    d2="$(quota_update_api "$API_NON" "$SNAP_NON")"; r2=$?

    if [ $r1 -eq 0 ] || [ $r2 -eq 0 ]; then
        {
            [ -n "$d1" ] && printf '%s\n' "$d1"
            [ -n "$d2" ] && printf '%s\n' "$d2"
        } | awk -F'|' 'NF>=2 { s[$1]+=$2 } END { for (u in s) if (s[u]>0) print u "|" s[u] }' \
        | while IFS='|' read -r u b; do
            [ -n "$u" ] && add_usage "$u" "$b"
        done
    fi

    # 2) IP aktif
    declare -A IPCNT=()
    while read -r u c; do
        [ -n "$u" ] && IPCNT["$u"]="$c"
    done < <(ip_counts)

    # 3) semak setiap user
    local user ip_limit quota_gb used blocked proto reason breach cur c qbytes
    while IFS='|' read -r user ip_limit quota_gb used blocked proto reason; do
        [ -z "$user" ] && continue
        case "$user" in \#*) continue ;; esac
        [ "$blocked" = "1" ] && continue
        [ -z "$used" ] && used=0

        breach=""
        if [ -n "$quota_gb" ] && awk -v q="$quota_gb" 'BEGIN{exit !(q>0)}'; then
            qbytes="$(awk -v q="$quota_gb" 'BEGIN{printf "%.0f", q*1073741824}')"
            if [ "$used" -ge "$qbytes" ] 2>/dev/null; then
                breach="quota"
            fi
        fi

        if [ -z "$breach" ] && [ -n "$ip_limit" ] && [ "$ip_limit" -gt 0 ] 2>/dev/null; then
            cur="${IPCNT[$user]:-0}"
            if [ "$cur" -gt "$ip_limit" ]; then
                breach="ip"
            fi
        fi

        if [ -n "$breach" ]; then
            c="$(breach_get "$user" "$breach")"
            c=$(( ${c:-0} + 1 ))
            breach_set "$user" "$breach" "$c"
            dbg "breach user=$user type=$breach count=$c limit_ip=$ip_limit used=$used quota=$quota_gb"
            if [ "$c" -ge "$BREACH_STREAK" ]; then
                if [ "$breach" = "quota" ]; then
                    block_user "$user" "quota ${quota_gb}GB"
                else
                    block_user "$user" "ip ${cur}/${ip_limit}"
                fi
            fi
        else
            breach_set "$user" ip 0
            breach_set "$user" quota 0
        fi
    done < "$DB"

    exit 0
}

# ---------- CLI ----------
cmd_status() {
    echo "DB: $DB"
    echo "USER | IP_LIMIT | QUOTA | USED | STATUS | REASON"
    [ -f "$DB" ] && while IFS='|' read -r u ip q used b pr r; do
        [ -z "$u" ] && continue
        if [ "$b" = "1" ]; then st=BLOCKED; else st=ACTIVE; fi
        echo "$u | IP:${ip:-0} | Quota:${q:-0}GB | Used:$(human "${used:-0}") | $st${r:+ | $r}"
    done < "$DB"
}

cmd_debug() {
    echo "=== xray-limit debug ==="
    echo "Versi         : $XRAY_LIMIT_VERSION"
    echo "DB            : $DB"
    echo "Access log    : $ACCESS"
    echo "API TLS       : $API_TLS   (port dari config: $(api_port "$CFG_TLS"))"
    echo "API non-TLS   : $API_NON   (port dari config: $(api_port "$CFG_NON"))"
    echo "IP window     : ${IP_WINDOW}s | breach streak: ${BREACH_STREAK}"
    echo
    echo "--- DB ---"
    [ -f "$DB" ] && cat "$DB" || echo "(tiada DB)"
    echo
    echo "--- 10 baris terakhir access.log ---"
    tail -n 10 "$ACCESS" 2>/dev/null || echo "(tiada log)"
    echo
    echo "--- IP dikira dalam window ---"
    ip_counts || true
    echo
    echo "--- statsquery TLS (mentah) ---"
    raw1="$(stats_raw "$API_TLS")"; echo "rc=$?"; printf '%s\n' "$raw1" | head -40
    echo
    echo "--- statsquery non-TLS (mentah) ---"
    raw2="$(stats_raw "$API_NON")"; echo "rc=$?"; printf '%s\n' "$raw2" | head -40
    echo
    echo "--- statistik diparse (TLS) ---"
    printf '%s\n' "$raw1" | parse_stats
    echo "--- statistik diparse (non-TLS) ---"
    printf '%s\n' "$raw2" | parse_stats
    echo
    echo "--- snapshot ---"
    echo "[TLS]";  cat "$SNAP_TLS" 2>/dev/null
    echo "[NON]";  cat "$SNAP_NON" 2>/dev/null
    echo
    echo "--- breach counter ---"
    cat "$BREACH" 2>/dev/null || echo "(tiada)"
}

case "${1:-run}" in
    run)     run_enforcement ;;
    debug)   cmd_debug ;;
    status)  cmd_status ;;
    unblock) [ -n "${2:-}" ] && limit_unblock "$2" || echo "Guna: xray-limit unblock <user>" ;;
    *)       echo "Guna: xray-limit [run|debug|status|unblock <user>]" ;;
esac
XRAYLIMITENGINE
        chmod +x "$LIMIT_BIN"
    fi
    if [ ! -f "$LIMIT_CRON" ] || ! grep -q "xray-limit" "$LIMIT_CRON" 2>/dev/null; then
        {
            echo 'SHELL=/bin/bash'
            echo 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
            echo '* * * * * root /usr/local/bin/xray-limit >/dev/null 2>&1'
        } > "$LIMIT_CRON"
        chmod 644 "$LIMIT_CRON"
    fi
}

limit_engine_ensure

# // FUCTION CREATE USER TROJAN
function menu1 () {
clear
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line-------------------------------------------------------\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box CREATE USER XRAY TROJAN WS\e[30m ]\e[1m          \e[m"
echo -e   "  \e[$line-------------------------------------------------------\e[m"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
		read -rp "   Password: " -e user
		user_EXISTS=$(grep -w $user /usr/local/etc/xray/config.json | wc -l)

		if [[ ${user_EXISTS} == '1' ]]; then
			echo ""
			echo "A client with the specified name was already created, please choose another name."
			exit 1
		fi
	done
export patchtls=/trojanwstls
export patchnone=/trojanwsntls
read -p "   Bug Address (Example: www.google.com) : " address
read -p "   Bug SNI (Example : m.facebook.com) : " sni
read -p "   Expired (days) : " masaaktif

# ============================================================
# LIMIT IP & LIMIT QUOTA
# ============================================================
read -p "   Limit IP (0 = unlimited) : " limit_ip
read -p "   Limit Quota (GB, 0 = unlimited) : " limit_quota

# Validasi input — fallback 0 (unlimited)
[[ "$limit_ip" =~ ^[0-9]+$ ]] || limit_ip=0
[[ "$limit_quota" =~ ^[0-9]+([.][0-9]+)?$ ]] || limit_quota=0

bug_addr=${address}.
bug_addr2=$address
if [[ $address == "" ]]; then
sts=$bug_addr2
else
sts=$bug_addr
fi

export harini=`date -d "0 days" +"%Y-%m-%d"`
export exp=`date -d "$masaaktif days" +"%Y-%m-%d"`

# ============================================================
# SIMPAN LIMIT IP & LIMIT QUOTA
# ============================================================
limit_db_set "$user" "$limit_ip" "$limit_quota" "trojan"


sed -i '/#xray-trojan-tls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/config.json
sed -i '/#xray-trojan-nontls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/none.json

systemctl restart xray@config
systemctl restart xray@none

export trojanlink="trojan://${user}@${sts}${domain}:$trnone?host=$sni&security=none&type=ws&path=${patchnone}#${user}";
export trojanlink1="trojan://${user}@${sts}${domain}:$trws?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"

cat > /home/vps/public_html/trojanws-$user.txt <<-END

====================================================================
             P R O J E C T  O F  N I L P H R E A K Z V P N
                       [Freedom Internet]
====================================================================
             https://github.com/NiL070/oddloop
====================================================================
             Format Trojan WS - SPv2
====================================================================

             Link Trojan Account
====================================================================
Remarks       : ${user}
Domain        : ${domain}
IP/Host       : ${MYIP}
Port Tls      : ${trws}
Port None     : ${trnone}
Key           : ${user}
Security      : Auto
Network       : Websocket
Path Tls      : $patchtls
Path Ntls     : $patchnone
allowInsecure : True/allow
====================================================================
Link Trojan TLS : ${trojanlink1}
====================================================================
Link Trojan NTLS : ${trojanlink}
====================================================================
Expired On : $exp
====================================================================

END

clear
echo -e ""
echo -e "\e[$line--------[XRAY TROJAN WS TLS]--------\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port Tls      : ${trws},8443,2083,2096"
echo -e "Port None     : ${trnone},8080,2052,2082,2095"
echo -e "Key           : ${user}"
echo -e "Security      : Auto"
echo -e "Network       : Websocket"
echo -e "Path Tls      : $patchtls"
echo -e "Path Ntls     : $patchnone"
echo -e "allowInsecure : True/allow"
limit_print_info "$user" 14
echo -e "\e[$line---------------------------------\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -rsn1 -p "Press any key to back on menu Trojan or ctrl+x to see config list" keypress
if [[ "$keypress" == $'\x18' ]]; then
CFGMODE="trojan"
config_list_menu
fi
trojaan
}

# FUCTION TRIAL USER TROJAN
function menu2 () {
clear
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line-------------------------------------------------------\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box TRIAL USER XRAY TROJAN WS TLS\e[30m ]\e[1m           \e[m"
echo -e   "  \e[$line-------------------------------------------------------\e[m"

# // Make Random Username && Date
export masaaktif="1"
export exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
export user=Trial`</dev/urandom tr -dc X-Z0-9 | head -c4`

export patchtls=/trojanwstls
export patchnone=/trojanwsntls

read -p "   Bug Address (Example: www.google.com) : " address
read -p "   Bug SNI (Example : m.facebook.com) : " sni

bug_addr=${address}.
bug_addr2=$address
if [[ $address == "" ]]; then
sts=$bug_addr2
else
sts=$bug_addr
fi

export harini=`date -d "0 days" +"%Y-%m-%d"`

sed -i '/#xray-trojan-tls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/config.json
sed -i '/#xray-trojan-nontls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/none.json

systemctl restart xray@config
systemctl restart xray@none

export trojanlink="trojan://${user}@${sts}${domain}:$trnone?path=$patchnone&security=none&host=$sni&type=ws#${user}"
export trojanlink1="trojan://${user}@${sts}${domain}:$trws?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"

clear
echo -e ""
echo -e "\e[$line-----[TRIAL XRAY TROJAN WS TLS]-----\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port Tls      : ${trws}"
echo -e "Port None     : ${trnone}"
echo -e "Key           : ${user}"
echo -e "Security      : Auto"
echo -e "Network       : Websocket"
echo -e "Path Tls      : $patchtls"
echo -e "Path Ntls     : $patchnone"
echo -e "allowInsecure : True/allow"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -rsn1 -p "Press any key to back on menu Trojan or ctrl+x to see config list" keypress
if [[ "$keypress" == $'\x18' ]]; then
CFGMODE="trojan"
config_list_menu
fi
trojaan
}

function menu3 () {
clear
CONFIG="/usr/local/etc/xray/config.json"
NONE="/usr/local/etc/xray/none.json"

# Senarai user unik berdasarkan #trws SAHAJA
mapfile -t TROJAN_USERS < <(
awk '
/^#trws / {
    user=$2
    if (!(user in seen)) {
        seen[user]=1
        print $0
    }
}
' "$CONFIG"
)

NUMBER_OF_CLIENTS=${#TROJAN_USERS[@]}

if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    echo ""
    echo "You have no existing clients!"
    exit 1
fi

echo ""
echo " DELETE XRAY TROJAN WS TLS"
echo " Select the existing client you want to remove"
echo " Press CTRL+C to return"
echo " ==============================="
echo "     No  Expired   User"

# Paparkan #trws sahaja, 1 nama = 1 user
for ((i=0; i<NUMBER_OF_CLIENTS; i++)); do
    echo "${TROJAN_USERS[$i]}" | cut -d ' ' -f 2-3
done | nl -s ') '

CLIENT_NUMBER=""

until [[ ${CLIENT_NUMBER} =~ ^[0-9]+$ ]] && \
      [[ ${CLIENT_NUMBER} -ge 1 ]] && \
      [[ ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do

    if [[ ${NUMBER_OF_CLIENTS} == '1' ]]; then
        read -rp "Select one client [1]: " CLIENT_NUMBER
    else
        read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
    fi

done

# Ambil baris user yang dipilih
CLIENT_LINE="${TROJAN_USERS[$((CLIENT_NUMBER-1))]}"

if [[ -z "$CLIENT_LINE" ]]; then
    echo "User tidak dijumpai."
    exit 1
fi

harini=$(echo "$CLIENT_LINE" | awk '{print $4}')
uuid=$(echo "$CLIENT_LINE" | awk '{print $5}')
CLIENT_NAME=$(echo "$CLIENT_LINE" | awk '{print $2" "$3}')
user=$(echo "$CLIENT_LINE" | awk '{print $2}')
exp=$(echo "$CLIENT_LINE" | awk '{print $3}')

# Pastikan tag betul-betul wujud sebelum padam
if ! grep -qF "#trws $user $exp $harini $uuid" "$CONFIG"; then
    echo ""
    echo "Tag akaun tidak dijumpai. Padam dibatalkan."
    exit 1
fi

sed -i "/^#trws $user $exp $harini $uuid/,/^},{/d" "$CONFIG"
sed -i "/^#trws $user $exp $harini $uuid/,/^},{/d" "$NONE"

limit_db_del "$user"

systemctl restart xray@none
systemctl restart xray@config
service cron restart

clear
echo " Xray Trojan WS TLS Account Deleted Successfully"
echo " =========================="
echo " Client Name : $user"
echo " Expired On  : $exp"
echo " =========================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
trojaan
}


function menu4 () {
clear
CONFIG="/usr/local/etc/xray/config.json"
NONE="/usr/local/etc/xray/none.json"

# Senarai user unik berdasarkan #trws SAHAJA
mapfile -t TROJAN_USERS < <(
awk '
/^#trws / {
    user=$2
    if (!(user in seen)) {
        seen[user]=1
        print $0
    }
}
' "$CONFIG"
)

NUMBER_OF_CLIENTS=${#TROJAN_USERS[@]}

if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    clear
    echo ""
    echo "You have no existing clients!"
    exit 1
fi

clear
echo ""
echo "Renew User Xray Trojan Ws Tls"
echo "Select the existing client you want to renew"
echo " Press CTRL+C to return"
echo -e "==============================="

# Paparkan #trws sahaja, 1 nama = 1 user
for ((i=0; i<NUMBER_OF_CLIENTS; i++)); do
    echo "${TROJAN_USERS[$i]}" | cut -d ' ' -f 2-3
done | nl -s ') '

echo ""

CLIENT_NUMBER=""

# ============================================================
# PILIH CLIENT (nombor) ATAU SEARCH (tekan 's')
# ============================================================

until [[ ${CLIENT_NUMBER} =~ ^[0-9]+$ ]] && \
      [[ ${CLIENT_NUMBER} -ge 1 ]] && \
      [[ ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do

    if [[ ${NUMBER_OF_CLIENTS} == '1' ]]; then
        read -rp "Select one client [1] (or 's' to search): " CLIENT_NUMBER
    else
        read -rp "Select one client [1-${NUMBER_OF_CLIENTS}] (or 's' to search): " CLIENT_NUMBER
    fi

    # ---------- SEARCH MODE (SEPARA / PARTIAL) ----------
    if [[ ${CLIENT_NUMBER} == 's' || ${CLIENT_NUMBER} == 'S' ]]; then
        read -rp "   Masukkan username yang nak dicari: " SEARCH_USER

        if [[ -z "$SEARCH_USER" ]]; then
            continue
        fi

        MATCHES=()
        for ((i=0; i<NUMBER_OF_CLIENTS; i++)); do
            u="$(echo "${TROJAN_USERS[$i]}" | awk '{print $2}')"
            if [[ "${u,,}" == *"${SEARCH_USER,,}"* ]]; then
                MATCHES+=("$i")
            fi
        done

        if [[ ${#MATCHES[@]} -eq 0 ]]; then
            echo ""
            echo "User not found : $SEARCH_USER"
            sleep 3
            menu4

        elif [[ ${#MATCHES[@]} -eq 1 ]]; then
            CLIENT_NUMBER=$((MATCHES[0] + 1))
            break

        else
            echo ""
            echo "Jumpa ${#MATCHES[@]} user yang sepadan:"
            for ((m=0; m<${#MATCHES[@]}; m++)); do
                echo "  $((m+1))) $(echo "${TROJAN_USERS[${MATCHES[$m]}]}" | cut -d ' ' -f 2-3)"
            done
            read -rp "   Pilih nombor [1-${#MATCHES[@]}] (atau 's' cari semula): " MATCH_PICK

            if [[ ${MATCH_PICK} == 's' || ${MATCH_PICK} == 'S' ]]; then
                continue
            fi

            if [[ ${MATCH_PICK} =~ ^[0-9]+$ ]] && \
               [[ ${MATCH_PICK} -ge 1 ]] && \
               [[ ${MATCH_PICK} -le ${#MATCHES[@]} ]]; then
                CLIENT_NUMBER=$(( ${MATCHES[$((MATCH_PICK-1))]} + 1 ))
                break
            else
                echo "Pilihan tidak sah."
                sleep 1
                continue
            fi
        fi
    fi
    # ---------- END SEARCH MODE ----------

done

# Ambil baris user yang dipilih
CLIENT_LINE="${TROJAN_USERS[$((CLIENT_NUMBER-1))]}"

if [[ -z "$CLIENT_LINE" ]]; then
    echo "User tidak dijumpai."
    exit 1
fi

harini=$(echo "$CLIENT_LINE" | awk '{print $4}')
uuid=$(echo "$CLIENT_LINE" | awk '{print $5}')
user=$(echo "$CLIENT_LINE" | awk '{print $2}')
exp=$(echo "$CLIENT_LINE" | awk '{print $3}')

echo ""
echo "================================="
echo "Client Name : $user"
echo "Current Exp : $exp"
echo "Key         : $user"
echo "================================="
echo ""

read -p "Expired (days): " masaaktif

if ! [[ "$masaaktif" =~ ^-?[0-9]+$ ]]; then
    echo "Expired days mesti nombor."
    exit 1
fi

now=$(date +%Y-%m-%d)
d1=$(date -d "$exp" +%s)
d2=$(date -d "$now" +%s)
exp2=$(( (d1 - d2) / 86400 ))

if [[ $exp2 -lt 0 ]]; then
    exp2=0
fi

exp3=$((exp2 + masaaktif))
exp4=$(date -d "$exp3 days" +"%Y-%m-%d")

echo ""
echo "Old Expiry : $exp"
echo "New Expiry : $exp4"
echo ""

sed -i "s|^#trws $user $exp $harini $uuid$|#trws $user $exp4 $harini $uuid|" /usr/local/etc/xray/config.json
sed -i "s|^#trws $user $exp $harini $uuid$|#trws $user $exp4 $harini $uuid|" /usr/local/etc/xray/none.json

# buka blok + reset penggunaan quota (jika user pernah di-block)
WAS_BLOCKED=0
grep -q "\"email\": \"blocked-${user}\"" "$CONFIG" "$NONE" 2>/dev/null && WAS_BLOCKED=1
limit_unblock "$user"
if [ "$WAS_BLOCKED" = "1" ]; then
    systemctl restart xray@config
    systemctl restart xray@none
fi

service cron restart

clear
echo ""
echo " XRAY TROJAN WS TLS Account Was Successfully Renewed"
echo " =========================="
echo " Client Name : $user"
echo " Expired On  : $exp4"
echo " =========================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
trojaan
}

# paparan maklumat akaun menu5 (boleh dilukis semula)
function menu5_info () {
clear
echo -e ""
echo -e "\e[$line--------[XRAY TROJAN WS TLS]--------\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port Tls      : ${trws},8443,2083,2096"
echo -e "Port None     : ${trnone},8080,2052,2082,2095"
echo -e "Key           : ${user}"
echo -e "Security      : Auto"
echo -e "Network       : Websocket"
echo -e "Path Tls      : $patchtls"
echo -e "Path Ntls     : $patchnone"
echo -e "allowInsecure : True/allow"
limit_print_info "$user" 14
echo -e "\e[$line---------------------------------\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
}

function menu5 () {
clear
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
CONFIG="/usr/local/etc/xray/config.json"
NONE="/usr/local/etc/xray/none.json"

# Senarai user unik berdasarkan #trws SAHAJA
mapfile -t TROJAN_USERS < <(
awk '
/^#trws / {
    user=$2
    if (!(user in seen)) {
        seen[user]=1
        print $0
    }
}
' "$CONFIG"
)

NUMBER_OF_CLIENTS=${#TROJAN_USERS[@]}

if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
    clear
    echo ""
    echo "You have no existing clients!"
    exit 1
fi

clear
echo ""
echo "SHOW USER XRAY TROJAN TCP TLS"
echo "Select the existing client you want to renew"
echo " Press CTRL+C to return"
echo -e "==============================="

# Paparkan #trws sahaja, 1 nama = 1 user
for ((i=0; i<NUMBER_OF_CLIENTS; i++)); do
    echo "${TROJAN_USERS[$i]}" | cut -d ' ' -f 2-3
done | nl -s ') '

echo ""

CLIENT_NUMBER=""

# ============================================================
# PILIH CLIENT (nombor) ATAU SEARCH (tekan 's')
# ============================================================

until [[ ${CLIENT_NUMBER} =~ ^[0-9]+$ ]] && \
      [[ ${CLIENT_NUMBER} -ge 1 ]] && \
      [[ ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do

    if [[ ${NUMBER_OF_CLIENTS} == '1' ]]; then
        read -rp "Select one client [1] (or 's' to search): " CLIENT_NUMBER
    else
        read -rp "Select one client [1-${NUMBER_OF_CLIENTS}] (or 's' to search): " CLIENT_NUMBER
    fi

    # ---------- SEARCH MODE (SEPARA / PARTIAL) ----------
    if [[ ${CLIENT_NUMBER} == 's' || ${CLIENT_NUMBER} == 'S' ]]; then
        read -rp "   Masukkan username yang nak dicari: " SEARCH_USER

        if [[ -z "$SEARCH_USER" ]]; then
            continue
        fi

        MATCHES=()
        for ((i=0; i<NUMBER_OF_CLIENTS; i++)); do
            u="$(echo "${TROJAN_USERS[$i]}" | awk '{print $2}')"
            if [[ "${u,,}" == *"${SEARCH_USER,,}"* ]]; then
                MATCHES+=("$i")
            fi
        done

        if [[ ${#MATCHES[@]} -eq 0 ]]; then
            echo ""
            echo "User not found : $SEARCH_USER"
            sleep 3
            menu5

        elif [[ ${#MATCHES[@]} -eq 1 ]]; then
            CLIENT_NUMBER=$((MATCHES[0] + 1))
            break

        else
            echo ""
            echo "Jumpa ${#MATCHES[@]} user yang sepadan:"
            for ((m=0; m<${#MATCHES[@]}; m++)); do
                echo "  $((m+1))) $(echo "${TROJAN_USERS[${MATCHES[$m]}]}" | cut -d ' ' -f 2-3)"
            done
            read -rp "   Pilih nombor [1-${#MATCHES[@]}] (atau 's' cari semula): " MATCH_PICK

            if [[ ${MATCH_PICK} == 's' || ${MATCH_PICK} == 'S' ]]; then
                continue
            fi

            if [[ ${MATCH_PICK} =~ ^[0-9]+$ ]] && \
               [[ ${MATCH_PICK} -ge 1 ]] && \
               [[ ${MATCH_PICK} -le ${#MATCHES[@]} ]]; then
                CLIENT_NUMBER=$(( ${MATCHES[$((MATCH_PICK-1))]} + 1 ))
                break
            else
                echo "Pilihan tidak sah."
                sleep 1
                continue
            fi
        fi
    fi
    # ---------- END SEARCH MODE ----------

done
export patchtls=/trojanwstls
export patchnone=/trojanwsntls
CLIENT_LINE="${TROJAN_USERS[$((CLIENT_NUMBER-1))]}"

if [[ -z "$CLIENT_LINE" ]]; then
    echo "User tidak dijumpai."
    exit 1
fi

export user=$(echo "$CLIENT_LINE" | awk '{print $2}')
export harini=$(echo "$CLIENT_LINE" | awk '{print $4}')
export exp=$(echo "$CLIENT_LINE" | awk '{print $3}')
export uuid=$(echo "$CLIENT_LINE" | awk '{print $5}')

export trojanlink1="trojan://${user}@${sts}${domain}:$trws?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"
export trojanlink="trojan://${user}@${sts}${domain}:$trnone?path=$patchnone&security=none&host=$sni&type=ws#${user}"

menu5_info
echo ""
echo -e "\e[$line══════════════════════════════════════════\e[m"
echo -e "  \e[$number (1)\e[m \e[$below Change Limit IP & Quota\e[m"
echo -e "  \e[$number (2)\e[m \e[$below See Config List\e[m"
echo -e "  \e[$number (x)\e[m \e[$below Back to Trojan Menu\e[m"
echo -e "\e[$line══════════════════════════════════════════\e[m"
echo ""
while true; do
read -rp "  Pilih [1/2/x] : " opt || break
case "$opt" in
    1)
        limit_change_menu "$user" "trojan" 14
        break
        ;;
    2)
        CFGMODE="trojan"
        config_list_menu
        break
        ;;
    x|X)
        break
        ;;
    *)
        echo -e "  \e[1;31mPilihan tidak sah, sila cuba lagi.\e[0m"
        sleep 1
        menu5_info
        echo ""
echo -e "\e[$line══════════════════════════════════════════\e[m"
echo -e "  \e[$number (1)\e[m \e[$below Change Limit IP & Quota\e[m"
echo -e "  \e[$number (2)\e[m \e[$below See Config List\e[m"
echo -e "  \e[$number (x)\e[m \e[$below Back to Trojan Menu\e[m"
echo -e "\e[$line══════════════════════════════════════════\e[m"
echo ""
        ;;
esac
done
trojaan
}

# ============ CONFIG LIST FEATURE ============
CONFIGLIST_DIR="/etc/xray/configlist"

config_provider_color () {
	case "$1" in
		1) printf '\033[38;5;208m';;
		2) printf '\033[38;5;93m';;
		3) printf '\033[38;5;226m';;
		4) printf '\033[38;5;33m';;
		5) printf '\033[38;5;196m';;
		6) printf '\033[38;5;51m';;
		7) printf '\033[38;5;46m';;
		8) printf '\033[38;5;197m';;
		9) printf '\033[38;5;44m';;
		10) printf '\033[38;5;160m';;
	esac
}

config_provider_name () {
	case "$1" in
		1) echo "umobile";;
		2) echo "yes";;
		3) echo "digi";;
		4) echo "celcom";;
		5) echo "maxis";;
		6) echo "eastel";;
		7) echo "yoodo";;
		8) echo "tunetalk";;
		9) echo "tonewow";;
		10) echo "redone";;
	esac
}

config_default_path () {
	case "$1" in
		1) echo "/trojanwstls";;
		2) echo "/trojanwsntls";;
	esac
}

config_build_link () {
	local mode="$1" proto="$2" addr="$3" path="$4" extra="$5"
	case "$proto" in
		1) echo "trojan://${user}@${addr}:${trws}?path=${path}&security=tls&host=bug.com&type=ws&sni=${extra}#${user}";;
		2) echo "trojan://${user}@${addr}:${trnone}?path=${path}&security=none&host=${extra}&type=ws#${user}";;
	esac
}

config_edit () {
	local pfile="$1"
	local cname proto addr cpath dpath extra link mode
	mode="${CFGMODE:-trojan}"
	echo ""
	read -rp "   Nama config: " cname
	if [[ -z "$cname" ]]; then echo "   Nama kosong, dibatalkan."; sleep 2; return; fi
	echo ""
	echo "   Pilih protocol:"
	echo "   1) TLS"
	echo "   2) NTLS"
	echo ""
	read -rp "   Protocol [1-2]: " proto
	if ! [[ "$proto" =~ ^[1-2]$ ]]; then echo "   Protocol tidak sah."; sleep 2; return; fi
	read -rp "   Address (Enter untuk ${domain}): " addr
	[[ -z "$addr" ]] && addr="${domain}"
	dpath="$(config_default_path "$proto")"
	read -rp "   Path (Enter untuk ${dpath}): " cpath
	[[ -z "$cpath" ]] && cpath="${dpath}"
	if (( proto % 2 == 1 )); then
		read -rp "   SNI (Enter untuk ${domain}): " extra
		[[ -z "$extra" ]] && extra="${domain}"
	else
		read -rp "   Host (Enter untuk ${domain}): " extra
		[[ -z "$extra" ]] && extra="${domain}"
	fi
	link="$(config_build_link "$mode" "$proto" "$addr" "$cpath" "$extra")"
	mkdir -p "$CONFIGLIST_DIR"
	# Simpan sebagai template (tanpa user) supaya boleh guna semula untuk semua user
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cname" "$mode" "$proto" "$addr" "$cpath" "$extra" >> "$pfile"
	echo ""
	echo "   Config disimpan:"
	echo "   ════════════════════════════════════"
	echo "   Link ${cname}  : ${link}"
	echo "   ════════════════════════════════════"
	echo ""
	read -n 1 -s -r -p "   Press any key to continue"
}

config_list () {
	local pfile="$1"
	local cname mode proto addr cpath extra link found curmode
	clear
	echo ""
	if [[ -z "$user" ]]; then
		echo "   Tiada user semasa. Sila create user dahulu."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	if [[ ! -s "$pfile" ]]; then
		echo "   Tiada config tersimpan."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	curmode="${CFGMODE:-trojan}"
	found=0
	while IFS=$'\t' read -r cname mode proto addr cpath extra; do
		[[ -z "$cname" ]] && continue
		# Sokong format lama tanpa medan mode: anggap trojan.
		# Abaikan template mod lain (vmess/vless/xtls) yang berkongsi folder config.
		if [[ "$mode" != "trojan" && "$mode" != "vmess" && "$mode" != "vless" && "$mode" != "xtls" ]]; then
			extra="$cpath"; cpath="$addr"; addr="$proto"; proto="$mode"; mode="trojan"
		fi
		[[ "$mode" != "$curmode" ]] && continue
		# Bina semula link ikut user semasa
		link="$(config_build_link "$mode" "$proto" "$addr" "$cpath" "$extra")"
		echo "══════════════════════════════════"
		echo "Link ${cname}  : ${link}"
		found=1
	done < "$pfile"
	echo "══════════════════════════════════"
	if [[ "$found" == "0" ]]; then
		echo "   Tiada config tersimpan."
		echo "══════════════════════════════════"
	fi
	echo ""
	read -n 1 -s -r -p "   Press any key to continue"
}

config_delete () {
	local pfile="$1"
	local dnum cname mode proto addr cpath extra curmode lineno i realline
	local -a map names
	clear
	echo ""
	if [[ ! -s "$pfile" ]]; then
		echo "   Tiada config tersimpan."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	curmode="${CFGMODE:-trojan}"
	lineno=0
	map=()
	names=()
	while IFS=$'\t' read -r cname mode proto addr cpath extra; do
		lineno=$((lineno+1))
		[[ -z "$cname" ]] && continue
		if [[ "$mode" != "trojan" && "$mode" != "vmess" && "$mode" != "vless" && "$mode" != "xtls" ]]; then
			mode="trojan"
		fi
		[[ "$mode" != "$curmode" ]] && continue
		map+=("$lineno")
		names+=("$cname")
	done < "$pfile"
	if [[ ${#map[@]} -eq 0 ]]; then
		echo "   Tiada config tersimpan."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	echo "   Senarai config:"
	for i in "${!names[@]}"; do
		printf '%2d) %s\n' "$((i+1))" "${names[$i]}"
	done
	echo ""
	read -rp "   Nombor config untuk delete: " dnum
	[[ -z "$dnum" ]] && return
	if ! [[ "$dnum" =~ ^[0-9]+$ ]] || [[ "$dnum" -lt 1 ]] || [[ "$dnum" -gt ${#map[@]} ]]; then
		echo ""
		echo "   Nombor tidak sah."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	realline="${map[$((dnum-1))]}"
	cname="${names[$((dnum-1))]}"
	sed -i "${realline}d" "$pfile"
	echo ""
	echo "   Config '$cname' telah dipadam."
	echo ""
	read -n 1 -s -r -p "   Press any key to continue"
}

config_provider_submenu () {
	local pnum="$1" provider pfile sub
	local R=$'\e[0m'
	provider="$(config_provider_name "$pnum")"
	pfile="${CONFIGLIST_DIR}/${provider}.conf"
	mkdir -p "$CONFIGLIST_DIR"
	while true; do
		clear
		echo ""
		echo "   Provider: $(config_provider_color "$pnum")${provider^}${R}"
		echo "   a) Edit config"
		echo "   b) List config"
		echo "   c) Delete config"
		echo "   x) Back"
		echo ""
		read -rp "   Pilih [a/b/c/x]: " sub
		case "$sub" in
			a|A) config_edit "$pfile";;
			b|B) config_list "$pfile";;
			c|C) config_delete "$pfile";;
			x|X) break;;
			*) ;;
		esac
	done
}

config_list_menu () {
	local prov
	local R=$'\e[0m'
	while true; do
		clear
		echo ""
		echo "   CONFIG LIST"
		echo "   1. $(config_provider_color 1)Umobile${R}"
		echo "   2. $(config_provider_color 2)Yes${R}"
		echo "   3. $(config_provider_color 3)Digi${R}"
		echo "   4. $(config_provider_color 4)Celcom${R}"
		echo "   5. $(config_provider_color 5)Maxis${R}"
		echo "   6. $(config_provider_color 6)Eastel${R}"
		echo "   7. $(config_provider_color 7)Yoodo${R}"
		echo "   8. $(config_provider_color 8)Tunetalk${R}"
		echo "   9. $(config_provider_color 9)Tonewow${R}"
		echo "   10. $(config_provider_color 10)Redone${R}"
		echo "   x. Back to menu trojan"
		echo ""
		read -rp "   Pilih [1-10, x]: " prov
		case "$prov" in
			1|2|3|4|5|6|7|8|9|10) config_provider_submenu "$prov";;
			x|X) break;;
			*) ;;
		esac
	done
}
# ============ END CONFIG LIST FEATURE ============

# MENU TROJAN
clear
echo -e ""
echo -e "   \e[$line----------------------------------------\e[m"
echo -e "   \e[$back_text          \e[30m-[\e[$box TROJAN WS TLS\e[30m ]-           \e[m"
echo -e "   \e[$line----------------------------------------\e[m"
echo -e "   \e[$number (•1)\e[m \e[$below Create Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•2)\e[m \e[$below Trial Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•3)\e[m \e[$below Deleting Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•4)\e[m \e[$below Renew Xray Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•5)\e[m \e[$below Show Config Trojan WS TLS Account\e[m"
echo -e ""
echo -e "   \e[$number    >> Total :\e[m \e[$below ${total2} Client\e[m"
echo -e "   \e[$line----------------------------------------\e[m"
echo -e "   \e[$back_text \e[$box x)   MENU                             \e[m"
echo -e "   \e[$line----------------------------------------\e[m"
echo -e "\e[$line"
read -rp "      Please Input Number  [1-12 or x] :  "  num
echo -e ""
if [[ "$num" = "1" ]]; then
menu1
elif [[ "$num" = "2" ]]; then
menu2
elif [[ "$num" = "3" ]]; then
menu3
elif [[ "$num" = "4" ]]; then
menu4
elif [[ "$num" = "5" ]]; then
menu5
elif [[ "$num" = "x" ]]; then
menu
else
clear
echo -e "\e[1;31mYou Entered The Wrong Number, Please Try Again!\e[0m"
sleep 1
exec trojaan
fi
