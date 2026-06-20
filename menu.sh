#!/bin/bash

GitUser="RedHawk70"

# Detail VPS
IPVPS=$(curl -sS ipv4.icanhazip.com)
domain=$(cat /usr/local/etc/xray/domain)
ISP=$(curl -s ipinfo.io/org | cut -d " " -f 2-10 )
OS=$(hostnamectl 2>/dev/null | awk -F': ' '/Operating System/ {print $2; exit}')
OS2=$(lsb_release -ds)
CITY=$(curl -s ipinfo.io/city)
WKT=$(curl -s ipinfo.io/timezone)
IPV6=$(curl -s -6 ipv6.icanhazip.com)
clear

# detail cpu ram
cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo)
#cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
freq=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo)
tram=$(free -m | awk 'NR==2 {print $2}')
uram=$(free -m | awk 'NR==2 {print $3}')
fram=$(free -m | awk 'NR==2 {print $4}')
clear

# Dapatkan jumlah CPU cores
cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)

# Tentukan nama berdasarkan jumlah cores
case $cores in
  1)
    name="Single-Core"
    ;;
  2)
    name="Dual-Core"
    ;;
  4)
    name="Quad-Core"
    ;;
  *)
    name="$cores-Core"
    ;;
esac

echo "$name"
clear

# OS Uptime
uptime="$(uptime -p | cut -d " " -f 2-10)"

clear

# Getting CPU Information
cpu_usage1="$(ps aux | awk 'BEGIN {sum=0} {sum+=$3}; END {print sum}')"
cpu_usage="$((${cpu_usage1/\.*/} / ${corediilik:-1}))"
cpu_usage+=" %"

clear

# Xray-Core Version
xrays_path=$(which xray)
xrays_version=$("$xrays_path" --version 2>&1)
current_version=$(echo "$xrays_version" | awk '/Xray/{print $2}')
# CERTIFICATE STATUS
d1=$(date -d "$valid" +%s)
d2=$(date -d "$today" +%s)
certifacate=$(((d1 - d2) / 86400))
# TOTAL ACC CREATE VMESS WS
vmess=$(grep -c -E "^#vms " "/usr/local/etc/xray/vmess.json")
# TOTAL ACC CREATE  VLESS WS
vless=$(grep -c -E "^#vls " "/usr/local/etc/xray/vless.json")
# TOTAL ACC CREATE  VLESS TCP XTLS
xtls=$(grep -c -E "^#vxtls " "/usr/local/etc/xray/config.json")
# TOTAL ACC CREATE  TROJAN
trtls=$(grep -c -E "^#trx " "/usr/local/etc/xray/tcp.json")
# TOTAL ACC CREATE  TROJAN WS TLS
trws=$(grep -c -E "^#trws " "/usr/local/etc/xray/trojan.json")
# TOTAL ACC CREATE OVPN SSH
total_ssh="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
# PROVIDED
creditt=$(cat /root/provided)
# BANNER COLOUR
banner_colour=$(cat /etc/banner)
# TEXT ON BOX COLOUR
box=$(cat /etc/box)
# LINE COLOUR
line=$(cat /etc/line)
# TEXT COLOUR ON TOP
text=$(cat /etc/text)
# TEXT COLOUR BELOW
below=$(cat /etc/below)
# BACKGROUND TEXT COLOUR
back_text=$(cat /etc/back)
# NUMBER COLOUR
number=$(cat /etc/number)
# BANNER
banner=$(cat /usr/bin/bannerku)
ascii=$(cat /usr/bin/test)
clear

# ==============================
# Detect interface (atau paksa: IFACE=ens3)
# ==============================
iface="${IFACE:-}"
if [ -z "$iface" ]; then
  iface="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
fi
if [ -z "$iface" ]; then
  iface="$(ip -o link show 2>/dev/null | awk -F': ' '$2!="lo"{print $2; exit}')"
fi

# Paksa vnstat update (kalau boleh)
vnstat -u -i "$iface" >/dev/null 2>&1 || true

# ==============================
# Helpers
# ==============================
first_nonempty() {
  for v in "$@"; do
    [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  done
  printf '%s' "N/A"
}

trim() { awk '{$1=$1;print}' <<EOF
$*
EOF
}

# ==============================
# Init vars
# ==============================
dtoday=""; utoday=""; ttoday=""
dyest="";  uyest="";  tyest=""
dmon="";   umon="";   tmon=""

# ==============================
# DAILY (Today + Yesterday)
# Ambil dari vnstat -d (pipe table) atau legacy
# ==============================
d_out="$(vnstat -i "$iface" -d 2>/dev/null)"

if printf '%s\n' "$d_out" | grep -q '|'; then
  # ---- PIPE TABLE daily ----
  daily_kv="$(printf '%s\n' "$d_out" | awk -F'|' '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function last2(s,   n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[n-1]" "a[n]:"" }
    function first2(s,  n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[1]" "a[2]:"" }

    # data row contoh: 12/13/25  246.57 MiB | 211.25 MiB | 457.82 MiB | ...
    NF>=4 && $0 !~ /estimated/ && $0 !~ /avg\. rate/ && $0 ~ /^[ \t]*[0-9]/ {
      rx = last2($1); tx = first2($2); tt = first2($3);
      lines[++c] = rx "|" tx "|" tt;
    }
    END{
      if(c>=1) print "T=" lines[c];
      if(c>=2) print "Y=" lines[c-1];
    }')"

  tline="$(printf '%s\n' "$daily_kv" | awk -F= '$1=="T"{print $2; exit}')"
  yline="$(printf '%s\n' "$daily_kv" | awk -F= '$1=="Y"{print $2; exit}')"

  dtoday="$(printf '%s' "$tline" | awk -F'|' '{print $1}')"
  utoday="$(printf '%s' "$tline" | awk -F'|' '{print $2}')"
  ttoday="$(printf '%s' "$tline" | awk -F'|' '{print $3}')"

  dyest="$(printf '%s' "$yline" | awk -F'|' '{print $1}')"
  uyest="$(printf '%s' "$yline" | awk -F'|' '{print $2}')"
  tyest="$(printf '%s' "$yline" | awk -F'|' '{print $3}')"

else
  # ---- LEGACY daily (today/yesterday atau slash) ----
  today_line="$(printf '%s\n' "$d_out" | awk 'tolower($1)=="today"{print; exit}')"
  yest_line="$(printf '%s\n' "$d_out" | awk 'tolower($1)=="yesterday"{print; exit}')"

  # parse slash line: label RX UNIT / TX UNIT / TOTAL UNIT / ...
  parse_slash() {
    awk -F'/' '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      function last2(s,   n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[n-1]" "a[n]:"" }
      function first2(s,  n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[1]" "a[2]:"" }
      { print last2($1) "|" first2($2) "|" first2($3) }'
  }

  if [ -n "$today_line" ]; then
    tline="$(printf '%s\n' "$today_line" | parse_slash)"
    dtoday="$(printf '%s' "$tline" | awk -F'|' '{print $1}')"
    utoday="$(printf '%s' "$tline" | awk -F'|' '{print $2}')"
    ttoday="$(printf '%s' "$tline" | awk -F'|' '{print $3}')"
  fi

  if [ -n "$yest_line" ]; then
    yline="$(printf '%s\n' "$yest_line" | parse_slash)"
    dyest="$(printf '%s' "$yline" | awk -F'|' '{print $1}')"
    uyest="$(printf '%s' "$yline" | awk -F'|' '{print $2}')"
    tyest="$(printf '%s' "$yline" | awk -F'|' '{print $3}')"
  fi
fi

# ==============================
# MONTHLY (detect format untuk -m berasingan)
# ==============================
m_out="$(vnstat -i "$iface" -m 2>/dev/null)"

if printf '%s\n' "$m_out" | grep -q '|'; then
  # ---- PIPE TABLE monthly ----
  mline="$(printf '%s\n' "$m_out" | awk -F'|' '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function last2(s,   n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[n-1]" "a[n]:"" }
    function first2(s,  n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[1]" "a[2]:"" }

    NF>=4 && $0 !~ /estimated/ && $0 !~ /avg\. rate/ && $0 !~ /month[ \t]+rx/ && $0 !~ /----/ {
      rx = last2($1); tx = first2($2); tt = first2($3);
      line = rx "|" tx "|" tt;
    }
    END{ print line }')"

  dmon="$(printf '%s' "$mline" | awk -F'|' '{print $1}')"
  umon="$(printf '%s' "$mline" | awk -F'|' '{print $2}')"
  tmon="$(printf '%s' "$mline" | awk -F'|' '{print $3}')"

else
  # ---- SLASH STYLE monthly ----
  month_key="$(date +"%b '%y")"
  month_line="$(printf '%s\n' "$m_out" | awk -v m="$month_key" 'index($0,m){print; exit}')"

  if [ -n "$month_line" ]; then
    mline="$(printf '%s\n' "$month_line" | awk -F'/' '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      function last2(s,   n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[n-1]" "a[n]:"" }
      function first2(s,  n,a){ s=trim(s); n=split(s,a,/[ \t]+/); return (n>=2)?a[1]" "a[2]:"" }
      { print last2($1) "|" first2($2) "|" first2($3) }')"

    dmon="$(printf '%s' "$mline" | awk -F'|' '{print $1}')"
    umon="$(printf '%s' "$mline" | awk -F'|' '{print $2}')"
    tmon="$(printf '%s' "$mline" | awk -F'|' '{print $3}')"
  fi
fi

# ==============================
# Trim + fallback
# ==============================
dtoday="$(first_nonempty "$(trim "$dtoday")")"
utoday="$(first_nonempty "$(trim "$utoday")")"
ttoday="$(first_nonempty "$(trim "$ttoday")")"

dyest="$(first_nonempty "$(trim "$dyest")")"
uyest="$(first_nonempty "$(trim "$uyest")")"
tyest="$(first_nonempty "$(trim "$tyest")")"

dmon="$(first_nonempty "$(trim "$dmon")")"
umon="$(first_nonempty "$(trim "$umon")")"
tmon="$(first_nonempty "$(trim "$tmon")")"

clear
echo -e "\e[$banner_colour"
figlet -f $ascii "$banner"
echo -e "\e[$text VPS Script"
GREEN=$'\e[32m'
RED=$'\e[31m'
NC=$'\e[0m'
# ================== PREP DATA ==================
cname_clean=$(echo "$cname" | sed 's/^[[:space:]]*//')
freq_clean="$(echo "$freq" | sed 's/^[[:space:]]*//') MHz"
os_raw=$(hostnamectl | awk -F ': ' '/Operating System/ {print $2}')
os=$(echo "$os_raw" | sed 's/ GNU\/Linux//')
# Expired text
if [ "$exp" = "LIFETIME" ]; then
  expired_display="$exp ${GREEN}(Active)${NC}"
else
  expired_display="$exp ${RED}(Expired)${NC}"
fi
# ================== LEBAR BOX ==================
# BOXW = lebar ruang teks di dalam di antara dua │ │
BOXW=59          # <-- UBAH NILAI INI UNTUK KECIL/BESAR BOX
LABELW=11        # lebar label (supaya ":" sejajar)
BORDER=$(printf '═%.0s' $(seq 1 $((BOXW+2))))
row_info() {
  local label="$1"
  local value="$2"
  local raw plain plen pad
  printf -v raw "%-*s : %s" "$LABELW" "$label" "$value"
  plain=$(printf '%s' "$raw" | sed -r 's/\x1B\[[0-9;]*m//g')
  plen=${#plain}

  pad=$((BOXW - plen))
  if [ "$pad" -lt 0 ]; then
    pad=0
  fi
  printf " \e[$line│\e[m \e[$text%s%*s\e[m \e[$line│\e[m\n" "$raw" "$pad" ""
}
# ================== HEADER BOX ==================
echo -e " \e[$line╒${BORDER}╕\e[m"
echo -e "  \e[$back_text                    \e[30m[\e[$box SERVER INFORMATION\e[30m ]\e[1m                   \e[m"
echo -e " \e[$line╞${BORDER}╡\e[m"
# ================== ISI BOX ==================
row_info "CPU Model"   "$cname_clean"
row_info "CPU Freq"    "$freq_clean"
row_info "CPU Cores"   "$cores"
row_info "CPU Usage"   "$cpu_usage"
row_info "OS"          "$os"
row_info "Kernel"      "$(uname -r)"
row_info "RAM"         "$uram MB / $tram MB"
row_info "Uptime"      "$uptime"
row_info "IP Address"  "$IPVPS"
row_info "Domain"      "$domain"
row_info "XrayCore"    "$current_version"
row_info "Provider"    "$creditt"
echo -e " \e[$line╘${BORDER}╛\e[m"
# --- kemaskan output table (ANSI color betul) ---

# pastikan $text boleh jadi "1;37" atau "1;37m"
if [ -n "${text:-}" ]; then
  textc="${text%m}"               # buang trailing 'm' kalau ada
  C1="$(printf '\033[%sm' "$textc")"
  C0="$(printf '\033[0m')"
else
  C1=""; C0=""
fi

# fallback kalau kosong
dtoday="${dtoday:-N/A}"; dyest="${dyest:-N/A}"; dmon="${dmon:-N/A}"
utoday="${utoday:-N/A}"; uyest="${uyest:-N/A}"; umon="${umon:-N/A}"
ttoday="${ttoday:-N/A}"; tyest="${tyest:-N/A}"; tmon="${tmon:-N/A}"

# trim whitespace (bash)
trim() { local s="$*"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
dtoday="$(trim "$dtoday")"; dyest="$(trim "$dyest")"; dmon="$(trim "$dmon")"
utoday="$(trim "$utoday")"; uyest="$(trim "$uyest")"; umon="$(trim "$umon")"
ttoday="$(trim "$ttoday")"; tyest="$(trim "$tyest")"; tmon="$(trim "$tmon")"

# widths
wlabel=10
wcol=14

printf "  %s%-*s%s %s%*s %*s %*s%s\n" \
  "$C1" "$wlabel" "Traffic" "$C0" \
  "$C1" "$wcol" "Today" "$wcol" "Yesterday" "$wcol" "Month" "$C0"

printf "  %s%-*s%s %s%*s %*s %*s%s\n" \
  "$C1" "$wlabel" "Download" "$C0" \
  "$C1" "$wcol" "$dtoday" "$wcol" "$dyest" "$wcol" "$dmon" "$C0"

printf "  %s%-*s%s %s%*s %*s %*s%s\n" \
  "$C1" "$wlabel" "Upload" "$C0" \
  "$C1" "$wcol" "$utoday" "$wcol" "$uyest" "$wcol" "$umon" "$C0"

GREEN="$(printf '\033[1;32m')"
RESET="$(printf '\033[0m')"
tmon_br="${GREEN}[$tmon]${RESET}"

br="[$tmon]"
len=${#br}
pad=$((wcol - len))
[ "$pad" -lt 0 ] && pad=0
padsp="$(printf "%*s" "$pad" "")"

month_col="${padsp}${GREEN}${br}${RESET}"

printf "  %s%-*s%s %s%*s %*s %s%*s\033[0m%s\n" \
  "$C1" "$wlabel" "Total" "$C0" \
  "$C1" "$wcol" "$ttoday" \
  "$wcol" "$tyest" \
  "$GREEN" "$wcol" "[$tmon]" \
  "$RESET"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e " \e[$text Ssh/Ovpn   V2ray   Vless   Vlessxtls   Trojan-Ws   Trojan-Tls \e[0m "    
echo -e " \e[$below    $total_ssh         $vmess       $vless        $xtls           $trws           $trtls \e[0m "
echo -e " \e[$line╒═════════════════════════════════════════════════════════════╕\e[m"
echo -e "  \e[$back_text                        \e[30m[\e[$box PANEL MENU\e[30m ]\e[1m                       \e[m"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e "  \e[$number (•1)\e[m \e[$below XRAY VMESS & VLESS\e[m"
echo -e "  \e[$number (•2)\e[m \e[$below TROJAN XRAY & WS\e[m"
echo -e "  \e[$number (•3)\e[m \e[$below SSHWS & OPENVPN\e[m" 
echo -e "  \e[$number (•4)\e[m \e[$below NOOBZVPN MENU\e[m" 
echo -e " \e[$line╒═════════════════════════════════════════════════════════════╕\e[m"
echo -e "  \e[$back_text                        \e[30m[\e[$box VPS MENU\e[30m ]\e[1m                         \e[m"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e "  \e[$number (•5)\e[m \e[$below SYSTEM MENU\e[m          \e[$number (•9)\e[m \e[$below INFO ALL PORT\e[m"
echo -e "  \e[$number (•6)\e[m \e[$below THEMES MENU\e[m          \e[$number (10)\e[m \e[$below CLEAR EXPIRED USER\e[m"
echo -e "  \e[$number (•7)\e[m \e[$below CHANGE PORT\e[m          \e[$number (11)\e[m \e[$below CLEAR LOG VPS\e[m"
echo -e "  \e[$number (•8)\e[m \e[$below CHECK RUNNING\e[m        \e[$number (12)\e[m \e[$below REBOOT VPS\e[m"
echo -e ""
echo -e "  \e[$below[Ctrl + C] For exit from main menu\e[m"
echo -e " \e[$line╒═════════════════════════════════════════════════════════════╕\e[m"
echo -e "  \e[$below Version Name         : SSH XRAY WEBSOCKET MULTIPORT V3.0"
echo -e "  \e[$below Autoscript Mod By    : NiLphreakz"
echo -e " \e[$line╘═════════════════════════════════════════════════════════════╛\e[m"
echo -e "\e[$below "
read -p " Select menu :  " menu
echo -e ""
case $menu in
1)
    xraay
    ;;
2)
    trojaan
    ;;
3)
    ssh2
    ;;
4)
    menu-noobzvpn
    ;;	
5)
    system
    ;;
6)
    themes
    ;;
7)
    change-port
    ;;
8)
    check-sc
    ;;
9)
    cat log-install.txt
    ;;
10)
    xp
    ;;
11)
    clear-log
    ;;
12)
    reboot
    ;;  
x)
    clear
    exit
    echo -e "\e[1;31mPlease Type menu For More Option, Thank You\e[0m"
    ;;
*)
    clear
    echo -e "\e[1;31mPlease enter an correct number\e[0m"
    sleep 1
    exec menu
    ;;
esac
