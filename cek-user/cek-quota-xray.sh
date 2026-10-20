#!/bin/bash
#
# cek-quota — Senarai user Xray mengikut Quota Used
#             (urutan: paling banyak guna -> paling sedikit)
#
# Sumber data : /etc/xray/limit.db  (user|ip_limit|quota_gb|used_bytes|blocked|proto|reason)
# Paparan     : menyesuaikan lebar ikut saiz terminal (tput cols)
#

clear
LIMIT_DB="${LIMIT_DB:-/etc/xray/limit.db}"
CFG1="${XRAY_CFG:-/usr/local/etc/xray/config.json}"
CFG2="${XRAY_CFG_NONE:-/usr/local/etc/xray/none.json}"
STATE_DIR="${XRAY_LIMIT_STATE_DIR:-/var/lib/xray-limit}"
LOCK_FILE="${XRAY_LIMIT_LOCK:-/var/run/xray-limit.lock}"
CLEANED_COUNT=0

# Senarai username yang masih wujud dalam config Xray
existing_users() {
    local files=()
    [ -s "$CFG1" ] && files+=("$CFG1")
    [ -s "$CFG2" ] && files+=("$CFG2")
    [ ${#files[@]} -eq 0 ] && return 0

    {
        # marker akaun: #vms / #vls / #vls-http / #vls-xhttp / #vxtls / #trws
        grep -ohE '^#(vls-http|vls-xhttp|vxtls|trws|vms|vls) [A-Za-z0-9_]+' "${files[@]}" 2>/dev/null | awk '{print $2}'
        # email client (buang prefix blocked-)
        grep -ohE '"email"[[:space:]]*:[[:space:]]*"[^"]+"' "${files[@]}" 2>/dev/null \
            | sed -E 's/.*"([^"]+)"$/\1/' | sed 's/^blocked-//'
    } | sort -u
}

# Buang rekod limit untuk user yang tiada lagi dalam config
apply_cleanup() {
    local existing list tmp removed u f
    existing="$(existing_users)"
    [ -z "$existing" ] && return 0

    list="$(printf '%s' "$existing" | tr '\n' ' ')"
    tmp="$(mktemp)" || return 0

    awk -F'|' -v list="$list" '
        BEGIN { n=split(list, a, " "); for (i=1; i<=n; i++) keep[a[i]]=1 }
        $1 == "" || ($1 in keep) { print }
    ' "$LIMIT_DB" > "$tmp" || { rm -f "$tmp"; return 0; }

    removed="$(awk -F'|' -v list="$list" '
        BEGIN { n=split(list, a, " "); for (i=1; i<=n; i++) keep[a[i]]=1 }
        $1 != "" && !($1 in keep) { print $1 }
    ' "$LIMIT_DB")"

    mv "$tmp" "$LIMIT_DB"
    chmod 600 "$LIMIT_DB" 2>/dev/null

    while IFS= read -r u; do
        [ -z "$u" ] && continue
        [ -f "$STATE_DIR/breach" ] && sed -i "/^${u}|/d" "$STATE_DIR/breach" 2>/dev/null
        for f in "$STATE_DIR"/*.snap; do
            [ -f "$f" ] && sed -i "/^${u}|/d" "$f" 2>/dev/null
        done
    done <<< "$removed"

    CLEANED_COUNT="$(printf '%s\n' "$removed" | grep -c .)"
}

# ============================================================
# LEBAR TERMINAL
# ============================================================
TERM_W="$(tput cols 2>/dev/null)"
if ! [[ "${TERM_W:-}" =~ ^[0-9]+$ ]] || [ "${TERM_W:-0}" -lt 20 ]; then
    TERM_W="$(stty size 2>/dev/null | awk '{print $2}')"
fi
if ! [[ "${TERM_W:-}" =~ ^[0-9]+$ ]] || [ "${TERM_W:-0}" -lt 20 ]; then
    TERM_W="${COLUMNS:-80}"
fi
[[ "$TERM_W" =~ ^[0-9]+$ ]] || TERM_W=80
[ "$TERM_W" -lt 40 ] && TERM_W=40

# Tahap lajur ikut lebar terminal
if [ "$TERM_W" -ge 86 ]; then
    # LEBAR — dengan lajur Proto, bar 10
    UW=17; DW=11; LW=9; BAR=10; SW=8; SHOW_PROTO=1; PW=7; NOBAR=0
elif [ "$TERM_W" -ge 70 ]; then
    # SEDERHANA — tanpa Proto, bar 8
    UW=14; DW=10; LW=7; BAR=8;  SW=8; SHOW_PROTO=0; PW=0; NOBAR=0
elif [ "$TERM_W" -ge 62 ]; then
    # SEMPIT — tanpa Proto, bar 5
    UW=10; DW=9;  LW=7; BAR=5;  SW=8; SHOW_PROTO=0; PW=0; NOBAR=0
else
    # ULTRA SEMPIT — tiada bar, peratus selepas Used
    UW=10; DW=14; LW=7; BAR=0;  SW=8; SHOW_PROTO=0; PW=0; NOBAR=1
fi
USGW=$(( BAR + 9 ))
COMPACT=0
[ "$TERM_W" -lt 62 ] && COMPACT=1

# ============================================================
# WARNA PANEL (buang 'm' di hujung supaya escape sentiasa sah)
# ============================================================
line=$(cat /etc/line 2>/dev/null);      line=${line:-0};      line=${line%m}
box=$(cat /etc/box 2>/dev/null);        box=${box:-0};        box=${box%m}
below=$(cat /etc/below 2>/dev/null);    below=${below:-0};    below=${below%m}
back_text=$(cat /etc/back 2>/dev/null); back_text=${back_text:-0}; back_text=${back_text%m}

R=$'\e[0m'
GRN=$'\e[1;32m'
YEL=$'\e[1;33m'
RED=$'\e[1;31m'
CYA=$'\e[1;36m'

# Kotak ikut lebar terminal (maks 63, min 30)
BOXW=$(( TERM_W - 4 ))
[ "$BOXW" -gt 63 ] && BOXW=63
[ "$BOXW" -lt 30 ] && BOXW=30
printf -v BOXL '%*s' "$BOXW" ''
BOXL="${BOXL// /═}"

TITLE="[ ALL USER QUOTA USAGE XRAY ]"
TPAD=$(( (BOXW - ${#TITLE}) / 2 ))
[ "$TPAD" -lt 1 ] && TPAD=1
printf -v TPADSTR '%*s' "$TPAD" ''

echo -e ""
echo -e "  \e[${line}m${BOXL}${R}"
echo -e "  ${TPADSTR}\e[${back_text}m\e[30m[\e[${box}m ALL USER QUOTA USAGE XRAY \e[30m]\e[0m"
echo -e "  \e[${line}m${BOXL}${R}"
echo -e "  ${CYA}Urutan: paling banyak guna -> paling sedikit${R}"
echo ""

if [[ ! -f "$LIMIT_DB" ]]; then
    echo -e "  Fail limit tidak dijumpai: $LIMIT_DB"
    if [ "$COMPACT" = "1" ]; then
        echo -e "  Cipta akaun dengan limit dahulu."
    else
        echo -e "  Cipta akaun dengan limit dahulu (VMess / VLESS / XTLS / Trojan)."
    fi
    echo ""
    read -n 1 -s -r -p " Press any key to back on main menu"
    command -v menu >/dev/null 2>&1 && exec menu
    exit 0
fi

# ============================================================
# AUTO-BUANG REKOD USER YANG TIADA LAGI DALAM CONFIG XRAY
# (expired/deleted) — supaya DB tidak berlambak
# ============================================================
if [ -s "$LIMIT_DB" ]; then
    CNT_FILE="$(mktemp)"
    if ( : >>"$LOCK_FILE" ) 2>/dev/null; then
        # subshell: redirection fd9/stderr terkurung, TIDAK bocor ke shell utama
        (
            if command -v flock >/dev/null 2>&1; then
                flock -w 5 9 2>/dev/null || true
            fi
            apply_cleanup
            printf '%s' "${CLEANED_COUNT:-0}" > "$CNT_FILE"
        ) 9>"$LOCK_FILE" 2>/dev/null
        CLEANED_COUNT="$(cat "$CNT_FILE" 2>/dev/null)"
    else
        apply_cleanup
    fi
    rm -f "$CNT_FILE"
    [[ "${CLEANED_COUNT:-}" =~ ^[0-9]+$ ]] || CLEANED_COUNT=0
fi

# Normalisasi used (elak notasi saintifik lama) -> sort menurun -> format ikut lebar
awk -F'|' 'NF>=4 && $1 !~ /^#/ { printf "%s|%s|%s|%.0f|%s|%s|%s\n", $1, $2, $3, $4+0, $5, $6, $7 }' "$LIMIT_DB" \
| LC_ALL=C sort -t'|' -k4,4nr \
| awk -F'|' \
    -v R="$R" -v GRN="$GRN" -v YEL="$YEL" -v RED="$RED" -v CYA="$CYA" \
    -v uw="$UW" -v dw="$DW" -v lw="$LW" -v sw="$SW" -v pw="$PW" \
    -v bar_len="$BAR" -v usgw="$USGW" -v show_proto="$SHOW_PROTO" -v nobar="$NOBAR" -v compact="$COMPACT" '
function rep(ch, n,   s, i) { s = ""; for (i = 0; i < n; i++) s = s ch; return s }

BEGIN {
    U = "%-" uw "s"; D = "%-" dw "s"; L = "%-" lw "s"
    G = "%-" usgw "s"; S = "%-" sw "s"; P = "%-" pw "s"
    if (nobar) {
        FMT = "  %-4s " U " " D " " L " %s\n"
    } else if (show_proto) {
        FMT = "  %-4s " U " " P " " D " " L " " G " %s\n"
    } else {
        FMT = "  %-4s " U " " D " " L " " G " %s\n"
    }

    if (nobar)
        printf FMT, "No", "User", "Used / %", "Limit", "Status"
    else if (show_proto)
        printf FMT, "No", "User", "Proto", "Used", "Limit", "Usage", "Status"
    else
        printf FMT, "No", "User", "Used", "Limit", "Usage", "Status"

    if (nobar)
        printf FMT, "---", rep("-", uw), rep("-", dw), rep("-", lw), rep("-", sw)
    else if (show_proto)
        printf FMT, "---", rep("-", uw), rep("-", pw), rep("-", dw), rep("-", lw), rep("-", usgw), rep("-", sw)
    else
        printf FMT, "---", rep("-", uw), rep("-", dw), rep("-", lw), rep("-", usgw), rep("-", sw)

    n = 0; tused = 0; nblocked = 0
}
{
    user = $1; q = $3+0; used = $4+0; blocked = $5; proto = $6

    if (user == "" || user ~ /^#/) next
    if (user in seen) next
    seen[user] = 1

    n++
    tused += used

    # ----- Used -----
    if (used >= 1073741824)   uh = sprintf("%.2f GB", used/1073741824)
    else if (used >= 1048576) uh = sprintf("%.2f MB", used/1048576)
    else if (used > 0)        uh = sprintf("%.0f KB", used/1024)
    else                      uh = "0 KB"

    # ----- Limit + peratus -----
    if (q > 0) {
        qh = sprintf("%g GB", q)
        qb = q * 1073741824
        pct = used * 100 / qb
        p = (pct > 100) ? 100 : pct
        pctstr = sprintf("%3.0f%%", p)
        if (pct > 100) pctstr = pctstr "!"
    } else {
        qh = "UNLIMIT"
        pctstr = "-"
    }

    if (nobar) {
        uhh = (q > 0) ? uh " " pctstr : uh
    } else if (q > 0) {
        filled = int(p * bar_len / 100 + 0.5)
        if (filled > bar_len) filled = bar_len
        b = ""
        for (i = 0; i < bar_len; i++) b = b ((i < filled) ? "#" : "-")

        btxt = "[" b "] " pctstr
        while (length(btxt) < usgw) btxt = btxt " "

        if (pct >= 100)     bc = RED
        else if (pct >= 80) bc = YEL
        else                bc = GRN
        usage = bc btxt R
    } else {
        blank = "-"
        while (length(blank) < usgw) blank = blank " "
        usage = CYA blank R
    }

    # ----- Status -----
    if (blocked == "1") { st = RED "BLOCKED" R; nblocked++ }
    else                { st = GRN "ACTIVE" R }

    un = user
    if (length(un) > uw) un = substr(un, 1, uw-1) "~"
    pr = (proto == "") ? "-" : proto

    if (nobar)
        printf FMT, n, un, uhh, qh, st
    else if (show_proto)
        printf FMT, n, un, pr, uh, qh, usage, st
    else
        printf FMT, n, un, uh, qh, usage, st
}
END {
    print ""
    if (n == 0) {
        print "  Tiada rekod limit."
        if (compact) print "  User lama tiada rekod quota."
        else print "  User yang dicipta sebelum feature limit tiada rekod quota."
    } else {
        if (tused >= 1073741824)   th = sprintf("%.2f GB", tused/1073741824)
        else if (tused >= 1048576) th = sprintf("%.2f MB", tused/1048576)
        else                       th = sprintf("%.0f KB", tused/1024)
        if (compact)
            printf "  Total : %d user | %d blk | %s\n", n, nblocked, th
        else
            printf "  Total : %d user | %d blocked | Quota terpakai : %s\n", n, nblocked, th
    }
}'

if [ "${CLEANED_COUNT:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "  ${YEL}Nota: ${CLEANED_COUNT} rekod user lama/expired dibuang.${R}"
fi

echo ""
echo -e "  \e[${line}m${BOXL}${R}"
echo ""
read -n 1 -s -r -p " Press any key to back on main menu"
command -v menu >/dev/null 2>&1 && exec menu
exit 0
