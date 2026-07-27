#!/bin/bash
# XRAY WARP / FREEDOM / SOCKS5 MENU (+preset +auto DNS/QUIC fulltunnel +exclude bypass)
# no jq | keep #comments | anchor = FIRST multi-line rule containing "domain": [
set -euo pipefail

XRAY_DIR="/usr/local/etc/xray"
CFG_LIST=("$XRAY_DIR/none.json" "$XRAY_DIR/config.json")
WARP_ADDR="127.0.0.1"
WARP_PORT="40000"
FLUSH_PLACEHOLDER="domain:example.net"
SOCKS5_TAG="socks5"
SOCKS5_ADDR=""; SOCKS5_PORT=""; SOCKS5_USER=""; SOCKS5_PASS=""

RESET="\e[0m"; BOLD="\e[1m"; DIM="\e[2m"; WHITE="\e[97m"
GREEN="\e[92m"; YELLOW="\e[93m"; ORANGE="\e[38;5;208m"
RED="\e[91m"; CYAN="\e[96m"; PINK="\e[38;5;213m"
BLUE="\e[38;5;39m"; TEAL="\e[38;5;44m"; LIME="\e[38;5;154m"
VIOLET="\e[38;5;141m"; GOLD="\e[38;5;220m"; GREY="\e[38;5;245m"

die(){ echo -e "\n${RED}[ERROR]${RESET} $*\n"; exit 1; }
ok(){  echo -e "${GREEN}[OK]${RESET} $*"; }
info(){ echo -e "${CYAN}[INFO]${RESET} $*"; }
backup(){ cp -a "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"; }

need_targets(){ local any=0; for f in "${CFG_LIST[@]}"; do [ -f "$f" ] && { any=1; break; }; done; [ "$any" -eq 1 ] || die "No target JSON found."; }

preset_domains_raw() {
cat <<'EOF'
# ===== TEST / SEMAK IP =====
example.net
check-host.net
speedtestcustom.com
fireprobe.net
whatismyip.com
# ===== PINTEREST =====
pinterest.com
pinimg.com
pin.it
# ===== KERAJAAN MALAYSIA =====
gov.my
mil.my
myeg.com.my
digital-id.my
myid.my
# ===== NETFLIX =====
netflix.com
netflix.net
nflxext.com
nflximg.net
nflxso.net
nflxvideo.net
# ===== YOUTUBE =====
youtube.com
youtu.be
ytimg.com
googlevideo.com
ggpht.com
# ===== DISNEY+ / HOTSTAR =====
disneyplus.com
disney-plus.net
dssott.com
hotstar.com
hotstarext.com
# ===== PRIME VIDEO =====
primevideo.com
amazonvideo.com
aiv-cdn.net
pv-cdn.net
# ===== HBO MAX / MAX =====
hbo.com
hbomax.com
max.com
hbomaxcdn.com
# ===== APPLE TV+ =====
tv.apple.com
# ===== HULU =====
hulu.com
hulustream.com
# ===== OTT ASIA =====
viu.com
viu.tv
iq.com
iqiyi.com
wetv.vip
bahamut.com.tw
gamer.com.tw
bilibili.com
bilivideo.com
# ===== ANIME =====
crunchyroll.com
crunchyroll.net
vrv.co
viki.com
rakuten.tv
vidio.com
# ===== LIVE / VIDEO =====
twitch.tv
ttvnw.net
jtvnw.net
dailymotion.com
vimeo.com
# ===== SPORTS =====
dazn.com
beinsports.com
beinconnect.com.my
# ===== US OTT =====
paramountplus.com
peacocktv.com
bbc.co.uk
# ===== MUZIK =====
spotify.com
scdn.co
spotifycdn.com
joox.com
music.apple.com
tidal.com
deezer.com
# ===== ASTRO =====
astro.com.my
astro.com
astrogo.astro.com.my
sooka.my
njoi.com.my
astronetworks.com.my
astro-cdn.com
# ===== RTMKLIK / RTM =====
rtmklik.rtm.gov.my
rtmklik.my
rtm.gov.my
# ===== OTT MALAYSIA =====
tonton.com.my
dimsum.my
# ===== IMVU =====
imvu.com
imvu.net
im.vu
# ===== BANK - MAYBANK =====
maybank.com
maybank.com.my
maybank2u.com.my
maybank2e.net
mae.com.my
# ===== BANK - CIMB =====
cimb.com.my
cimbbank.com.my
cimbclicks.com.my
cimbocto.com.my
# ===== BANK - PUBLIC BANK =====
publicbank.com.my
pbebank.com
# ===== BANK - RHB =====
rhbgroup.com
rhb.com.my
rhbnow.com
# ===== BANK - HONG LEONG =====
hlb.com.my
hongleongconnect.my
hongleong.com.my
# ===== BANK - AMBANK =====
ambank.com.my
ambankgroup.com
amonline.com.my
# ===== BANK - ALLIANCE =====
alliancebank.com.my
allianceonline.com.my
# ===== BANK - AFFIN =====
affinbank.com.my
affinalways.com
affinonline.com
# ===== BANK - BANK ISLAM =====
bankislam.com
bankislam.com.my
# ===== BANK - MUAMALAT =====
muamalat.com.my
# ===== BANK - BANK RAKYAT =====
bankrakyat.com.my
irakyat.com.my
# ===== BANK - BSN =====
bsn.com.my
mybsn.com.my
# ===== BANK - AGROBANK =====
agrobank.com.my
agronet.com.my
# ===== BANK - LAIN =====
mbsbbank.com
alrajhibank.com.my
kfh.com.my
# ===== BANK ASING =====
hsbc.com.my
sc.com
ocbc.com
ocbc.com.my
uob.com.my
uob.com
citibank.com.my
bankofchina.com
# ===== FPX / PAYNET =====
paynet.my
duitnow.my
jompay.com.my
mepsfpx.com.my
fpx.com.my
# ===== CLOUD =====
amazonaws.com
# ===== CDN AKAMAI =====
akamai.net
akamaized.net
akamaihd.net
akamaiedge.net
akamaitechnologies.com
edgekey.net
edgesuite.net
# ===== CDN CLOUDFRONT =====
cloudfront.net
# ===== CDN FASTLY =====
fastly.net
fastlylb.net
fastly.com
# ===== CDN GOOGLE =====
googleusercontent.com
gstatic.com
googleapis.com
1e100.net
EOF
}

is_listening(){ ss -lnt 2>/dev/null | awk -v p=":$2" '$1=="LISTEN" && index($4,p)>0 {f=1} END{exit(f?0:1)}'; }
get_global_socks(){ if is_listening "$WARP_ADDR" "$WARP_PORT"; then echo "$WARP_PORT"; else echo "OFF"; fi; }

get_mode_file() {
  awk '
    BEGIN{inRule=0;brace=0;hasDom=0}
    function trim(s){sub(/^[ \t]+/,"",s);sub(/[ \t]+$/,"",s);return s}
    {
      line=$0
      if(line ~ /{[ \t]*$/){inRule=1;brace=1;hasDom=0}
      else if(inRule==1){if(index(line,"{")>0)brace++;if(index(line,"}")>0)brace--}
      if(inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/) hasDom=1
      if(inRule==1 && hasDom==1 && line ~ /"outboundTag"[ \t]*:/){
        v=line;gsub(/.*"outboundTag"[ \t]*:[ \t]*"/,"",v);gsub(/".*/,"",v);print trim(v);exit
      }
      if(inRule==1 && brace<=0){inRule=0;brace=0;hasDom=0}
    }' "$1" 2>/dev/null || true
}

get_global_mode() {
  local w=0 d=0 s=0 u=0 m="" f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    m="$(get_mode_file "$f")"
    case "$m" in warp) w=1;; direct) d=1;; socks5) s=1;; *) u=1;; esac
  done
  if   [ $w -eq 1 ] && [ $d -eq 0 ] && [ $s -eq 0 ] && [ $u -eq 0 ]; then echo warp
  elif [ $d -eq 1 ] && [ $w -eq 0 ] && [ $s -eq 0 ] && [ $u -eq 0 ]; then echo direct
  elif [ $s -eq 1 ] && [ $w -eq 0 ] && [ $d -eq 0 ] && [ $u -eq 0 ]; then echo socks5
  else echo mixed; fi
}

get_first_outbound_file() {
  awk '
    BEGIN{inOut=0;done=0}
    { if(done)next
      if(inOut==0){if($0 ~ /"outbounds"[ \t]*:[ \t]*\[/)inOut=1;next}
      if($0 ~ /"tag"[ \t]*:[ \t]*"[^"]*"/){t=$0;gsub(/.*"tag"[ \t]*:[ \t]*"/,"",t);gsub(/".*/,"",t);print t;done=1}
    }' "$1" 2>/dev/null || true
}

get_global_scope() {
  local f first
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    first="$(get_first_outbound_file "$f")"
    if [ "$first" = "direct" ] || [ -z "$first" ]; then echo "list"; else echo "all"; fi
    return
  done
  echo "list"
}

get_fulltunnel_applied(){ local f; for f in "${CFG_LIST[@]}"; do [ -f "$f" ] && grep -q 'XRAYMENU-FULLTUNNEL' "$f" && { echo yes; return; }; done; echo no; }

domains_list_file_raw() {
  awk '
    BEGIN{inRule=0;brace=0;hasDom=0;inDom=0}
    function clean(s){gsub(/[",]/,"",s);sub(/^[ \t]+/,"",s);sub(/[ \t]+$/,"",s);return s}
    {
      line=$0
      if(line ~ /{[ \t]*$/){inRule=1;brace=1;hasDom=0;inDom=0}
      else if(inRule==1){if(index(line,"{")>0)brace++;if(index(line,"}")>0)brace--}
      if(inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){hasDom=1;inDom=1;next}
      if(inRule==1 && hasDom==1 && inDom==1){
        if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/) exit
        if(line ~ /domain:/) print clean(line)
        next
      }
      if(inRule==1 && brace<=0){inRule=0;brace=0;hasDom=0;inDom=0}
    }' "$1" 2>/dev/null || true
}

apply_domains_file() {
  local f="$1" action="$2" param="${3:-}"
  awk -v ACTION="$action" -v PARAM="$param" '
    BEGIN{inRule=0;brace=0;hasDom=0;inDom=0;dn=0;hn=0;indent="";targetDone=0}
    function push_dom(s){if(s=="")return;for(i=1;i<=dn;i++)if(dom[i]==s)return;dom[++dn]=s}
    function clean(s){gsub(/[",]/,"",s);sub(/^[ \t]+/,"",s);sub(/[ \t]+$/,"",s);return s}
    function flush_block(closeLine){
      if(ACTION=="add"){push_dom(PARAM)}
      else if(ACTION=="del"){k=PARAM+0;if(k>=1&&k<=dn){for(i=k;i<dn;i++)dom[i]=dom[i+1];dn--}}
      else if(ACTION=="flush"){dn=0;push_dom(PARAM)}
      if(indent=="")indent="          "
      for(j=1;j<=hn;j++)print hdr[j]
      for(i=1;i<=dn;i++){if(i<dn)printf "%s\"%s\",\n",indent,dom[i];else printf "%s\"%s\"\n",indent,dom[i]}
      print closeLine; targetDone=1
    }
    {
      line=$0
      if(line ~ /{[ \t]*$/){inRule=1;brace=1;hasDom=0;inDom=0;dn=0;hn=0;indent=""}
      else if(inRule==1){if(index(line,"{")>0)brace++;if(index(line,"}")>0)brace--}
      if(targetDone==0 && inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){hasDom=1;inDom=1;print line;next}
      if(targetDone==0 && inRule==1 && hasDom==1 && inDom==1){
        if(indent=="" && match(line,/^[ \t]*/))indent=substr(line,RSTART,RLENGTH)
        if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/){flush_block(line);inDom=0;next}
        if(line ~ /^[ \t]*#/){hdr[++hn]=line;next}
        if(line ~ /domain:/)push_dom(clean(line))
        next
      }
      print line
      if(inRule==1 && brace<=0){inRule=0;brace=0;hasDom=0;inDom=0}
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

replace_domain_block_file() {
  local f="$1" blk="$2"
  awk -v BLK="$blk" '
    BEGIN{inRule=0;brace=0;inDom=0;done=0}
    {
      line=$0
      if(line ~ /{[ \t]*$/){inRule=1;brace=1}
      else if(inRule==1){if(index(line,"{")>0)brace++;if(index(line,"}")>0)brace--}
      if(done==0 && inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){
        print line
        while((getline l < BLK)>0) print l
        close(BLK); inDom=1; next
      }
      if(done==0 && inDom==1){
        if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/){print line;inDom=0;done=1;next}
        next
      }
      print line
      if(inRule==1 && brace<=0){inRule=0;brace=0}
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

build_global_domains() {
  local f d
  GLOBAL_DOMAINS=(); declare -gA _SEEN=()
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      if [ -z "${_SEEN[$d]+x}" ]; then _SEEN["$d"]=1; GLOBAL_DOMAINS+=("$d"); fi
    done < <(domains_list_file_raw "$f" || true)
  done
}

show_domains_all() {
  local idx=0 f i
  echo; echo -e "${ORANGE}--------------------------------------${RESET}"
  echo -e "${WHITE}${BOLD}Current Domains (ANCHOR RULE)${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"
  for f in "${CFG_LIST[@]}"; do
    idx=$((idx+1)); [ -f "$f" ] || continue
    echo -e "${PINK}File #${idx}:${RESET} ${DIM}$(basename "$f")${RESET}"
    mapfile -t arr < <(domains_list_file_raw "$f" | sed '/^$/d' || true)
    if [ "${#arr[@]}" -eq 0 ]; then echo "  - (empty)"
    else for i in "${!arr[@]}"; do printf "  %3d) %s\n" $((i+1)) "${arr[$i]}"; done; fi
    echo
  done
  echo -e "${ORANGE}--------------------------------------${RESET}"; echo
}

show_domains_global() {
  build_global_domains
  echo; echo -e "${ORANGE}--------------------------------------${RESET}"
  echo -e "${WHITE}${BOLD}Domains (GLOBAL LIST)${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"
  if [ "${#GLOBAL_DOMAINS[@]}" -eq 0 ]; then echo "  - (empty)"
  else local i; for i in "${!GLOBAL_DOMAINS[@]}"; do printf "  %3d) %s\n" $((i+1)) "${GLOBAL_DOMAINS[$i]}"; done; fi
  echo -e "${ORANGE}--------------------------------------${RESET}"; echo
}

marker_text_for_mode() {
  case "$1" in
    warp)   echo "/* ===== DOMAIN WARP (MUDAH BUANG) ===== */" ;;
    socks5) echo "/* ===== DOMAIN LALU SOCKS5 (TAMBAH / BUANG DI SINI) ===== */" ;;
    direct) echo "/* ===== DOMAIN FREEDOM (MUDAH BUANG) ===== */" ;;
    *)      echo "/* ===== DOMAIN LIST ===== */" ;;
  esac
}

set_marker_file() {
  local f="$1" mode="$2" mark
  mark="$(marker_text_for_mode "$mode")"
  awk -v MARK="$mark" '
    BEGIN{done=0}
    {
      if($0 ~ /\/\*.*DOMAIN.*\*\//) next
      if(done==0 && $0 ~ /"domain"[ \t]*:[ \t]*\[[ \t]*$/){
        match($0,/^[ \t]*/); ind=substr($0,RSTART,RLENGTH)
        print ind MARK; print $0; done=1; next
      }
      print $0
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

ensure_first_outbound_file() {
  local f="$1" want="$2"
  awk -v WANT="$want" '
    BEGIN{inOut=0;collecting=0;nobj=0;depth=0}
    {
      if(inOut==0){print $0; if($0 ~ /"outbounds"[ \t]*:[ \t]*\[/){inOut=1;collecting=1} next}
      if(collecting==1){
        if(depth==0 && $0 ~ /^[ \t]*\][ \t]*,?[ \t]*$/){
          di=0; for(i=1;i<=nobj;i++){if(tag[i]==WANT){di=i;break}}
          on=0; if(di>0) order[++on]=di
          for(i=1;i<=nobj;i++) if(i!=di) order[++on]=i
          for(k=1;k<=on;k++){
            idx=order[k]; m=split(buf[idx],L,"\n")
            for(j=1;j<=m;j++){cur=L[j]; if(j==m){sub(/,[ \t]*$/,"",cur); if(k<on)cur=cur ","} print cur}
          }
          print $0; inOut=0; collecting=0; next
        }
        line=$0
        o=gsub(/[{]/,"&",line); c=gsub(/[}]/,"&",line)
        if(depth==0 && o>0){nobj++;buf[nobj]=$0;tag[nobj]=""} else {buf[nobj]=buf[nobj] "\n" $0}
        if($0 ~ /"tag"[ \t]*:[ \t]*"[^"]*"/){t=$0;gsub(/.*"tag"[ \t]*:[ \t]*"/,"",t);gsub(/".*/,"",t);tag[nobj]=t}
        depth += o - c; next
      }
      print $0
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

set_domain_strategy_file() {
  local f="$1" strat="$2"
  awk -v STRAT="$strat" '
    BEGIN{inR=0;done=0}
    {
      line=$0
      if(inR==0 && line ~ /"routing"[ \t]*:[ \t]*\{/) inR=1
      if(inR==1 && done==0 && line ~ /"domainStrategy"[ \t]*:/){
        sub(/"domainStrategy"[ \t]*:[ \t]*"[^"]*"/,"\"domainStrategy\": \"" STRAT "\"",line); done=1
      }
      print line
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

remove_fulltunnel_rules_file() {
  awk '
    /#[ \t]*XRAYMENU-FULLTUNNEL/ {next}
    /"type"[ \t]*:[ \t]*"field".*"port"[ \t]*:[ \t]*53[ ,].*"outboundTag"[ \t]*:[ \t]*"direct"/ {next}
    /"type"[ \t]*:[ \t]*"field".*"network"[ \t]*:[ \t]*"udp".*"port"[ \t]*:[ \t]*443.*"outboundTag"[ \t]*:[ \t]*"blocked"/ {next}
    {print}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

add_fulltunnel_rules_file() {
  local f="$1"
  remove_fulltunnel_rules_file "$f"
  awk '
    BEGIN{done=0}
    {
      print $0
      if(done==0 && $0 ~ /"rules"[ \t]*:[ \t]*\[/){
        match($0,/^[ \t]*/); ind=substr($0,RSTART,RLENGTH) "  "
        print ind "# XRAYMENU-FULLTUNNEL (auto: DNS direct + block QUIC)"
        print ind "{ \"type\": \"field\", \"port\": 53, \"outboundTag\": \"direct\" },"
        print ind "{ \"type\": \"field\", \"network\": \"udp\", \"port\": 443, \"outboundTag\": \"blocked\" },"
        done=1
      }
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

apply_dns_tweak_file() {
  local f="$1" scope="$2"
  if [ "$scope" = "all" ]; then
    set_domain_strategy_file "$f" "AsIs"; add_fulltunnel_rules_file "$f"
  else
    set_domain_strategy_file "$f" "IPIfNonMatch"; remove_fulltunnel_rules_file "$f"
  fi
}

# ===== EXCLUDE / BYPASS (rule 1-baris, di ATAS array rules) =====
get_exclude_domains_file() {
  awk '
    BEGIN{arm=0}
    {
      line=$0
      if(arm==0){ if(line ~ /XRAYMENU-EXCLUDE/) arm=1; next }
      if(line ~ /{/ && line ~ /}/){
        n=split(line,a,"\""); for(i=1;i<=n;i++) if(a[i] ~ /^domain:/) print a[i]
        arm=0; next
      }
      if(line ~ /^[ \t]*}[ \t]*,?[ \t]*$/){arm=0;next}
      n=split(line,a,"\""); for(i=1;i<=n;i++) if(a[i] ~ /^domain:/) print a[i]
    }' "$1" 2>/dev/null || true
}

remove_exclude_rule_file() {
  awk '
    BEGIN{skip=0;started=0}
    {
      line=$0
      if(skip==0){
        if(line ~ /XRAYMENU-EXCLUDE/){skip=1;started=0;next}
        print line; next
      }
      if(started==0){
        if(line ~ /{/ && line ~ /}/){skip=0;next}
        if(line ~ /{/){started=1;next}
        skip=0; print line; next
      } else {
        if(line ~ /^[ \t]*}[ \t]*,?[ \t]*$/){skip=0;started=0}
        next
      }
    }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

insert_exclude_rule_file() {
  local f="$1" ruleline="$2"
  awk -v RL="$ruleline" '
    BEGIN{done=0}
    {
      print $0
      if(done==0 && $0 ~ /"rules"[ \t]*:[ \t]*\[/){
        match($0,/^[ \t]*/); ind=substr($0,RSTART,RLENGTH) "  "
        print ind "# XRAYMENU-EXCLUDE (bypass -> direct)"
        print ind RL
        done=1
      }
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

exclude_global_list() {
  local f d; declare -A seen=()
  EXCLUDE_GLOBAL=()
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      if [ -z "${seen[$d]+x}" ]; then seen["$d"]=1; EXCLUDE_GLOBAL+=("$d"); fi
    done < <(get_exclude_domains_file "$f" || true)
  done
}

write_exclude_all() {
  local doms=("$@") f i list=""
  for i in "${!doms[@]}"; do
    if [ -z "$list" ]; then list="\"${doms[$i]}\""; else list="$list, \"${doms[$i]}\""; fi
  done
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    backup "$f"
    remove_exclude_rule_file "$f"
    if [ "${#doms[@]}" -gt 0 ]; then
      insert_exclude_rule_file "$f" "{ \"type\": \"field\", \"outboundTag\": \"direct\", \"domain\": [$list] },"
    fi
  done
}

manage_exclude() {
  while true; do
    clear
    exclude_global_list
    echo -e "${RED}${BOLD}EXCLUDE / BYPASS LIST${RESET} ${DIM}${GREY}(sentiasa lalu DIRECT)${RESET}"
    echo -e "${DIM}${GREY}Berguna masa mode WARP/SOCKS5 = SEMUA trafik.${RESET}"; echo
    if [ "${#EXCLUDE_GLOBAL[@]}" -eq 0 ]; then echo -e "  ${GREY}(kosong)${RESET}"
    else local i; for i in "${!EXCLUDE_GLOBAL[@]}"; do printf "  %3d) %s\n" $((i+1)) "${EXCLUDE_GLOBAL[$i]}"; done; fi
    echo
    echo -e "  ${GREEN}${BOLD}a${RESET}) Tambah   ${YELLOW}${BOLD}d${RESET}) Buang no.   ${RED}${BOLD}c${RESET}) Clear semua   ${GREY}${BOLD}0${RESET}) Back"
    read -rp "$(echo -e "  ${CYAN}Pilih:${RESET} ")" ex
    case "$ex" in
      a|A)
        echo; echo -e "${YELLOW}Masukkan domain (1 baris 1). ENTER kosong = tamat.${RESET}"; echo
        local input=() line
        while true; do read -rp "> " line || true; line="${line// /}"; [ -z "$line" ] && break; input+=("$line"); done
        [ "${#input[@]}" -gt 0 ] || { info "Tiada input."; sleep 1; continue; }
        local merged=() d; declare -A seen2=()
        for d in "${EXCLUDE_GLOBAL[@]}"; do seen2["$d"]=1; merged+=("$d"); done
        for d in "${input[@]}"; do
          d="${d// /}"; [ -n "$d" ] || continue
          [[ "$d" != domain:* ]] && d="domain:$d"
          if [ -z "${seen2[$d]+x}" ]; then seen2["$d"]=1; merged+=("$d"); fi
        done
        write_exclude_all "${merged[@]}"
        ok "Exclude dikemas kini (${#merged[@]} domain)"
        restart_xray_all
        read -rp "$(echo -e "  ${DIM}${GREY}Enter...${RESET}")" _
        ;;
      d|D)
        [ "${#EXCLUDE_GLOBAL[@]}" -gt 0 ] || { info "Kosong."; sleep 1; continue; }
        read -rp "Nombor nak buang 1..${#EXCLUDE_GLOBAL[@]} (0 batal): " n
        [[ "$n" =~ ^[0-9]+$ ]] || { info "Mesti nombor."; sleep 1; continue; }
        [ "$n" -eq 0 ] && continue
        { [ "$n" -ge 1 ] && [ "$n" -le "${#EXCLUDE_GLOBAL[@]}" ]; } || { info "Tak sah."; sleep 1; continue; }
        local remaining=() i
        for i in "${!EXCLUDE_GLOBAL[@]}"; do [ "$i" -ne "$((n-1))" ] && remaining+=("${EXCLUDE_GLOBAL[$i]}"); done
        if [ "${#remaining[@]}" -gt 0 ]; then write_exclude_all "${remaining[@]}"; else write_exclude_all; fi
        ok "Dibuang. Baki ${#remaining[@]} domain"
        restart_xray_all
        read -rp "$(echo -e "  ${DIM}${GREY}Enter...${RESET}")" _
        ;;
      c|C)
        read -rp "CONFIRM clear SEMUA exclude? type YES: " ans
        [ "$ans" = "YES" ] || { info "Cancelled."; sleep 1; continue; }
        write_exclude_all
        ok "Exclude list dikosongkan."
        restart_xray_all
        read -rp "$(echo -e "  ${DIM}${GREY}Enter...${RESET}")" _
        ;;
      0) return ;;
      *) info "Invalid"; sleep 1 ;;
    esac
  done
}

socks5_outbound_exists_file(){ grep -Eq '"tag"[[:space:]]*:[[:space:]]*"socks5"' "$1"; }

prompt_socks5_details() {
  echo; echo -e "${YELLOW}Isi maklumat server SOCKS5:${RESET}"
  read -rp "  Address (IP/host): " SOCKS5_ADDR
  read -rp "  Port             : " SOCKS5_PORT
  read -rp "  User (kosong=skip): " SOCKS5_USER
  read -rp "  Pass (kosong=skip): " SOCKS5_PASS
  SOCKS5_ADDR="${SOCKS5_ADDR// /}"; SOCKS5_PORT="${SOCKS5_PORT// /}"
  [ -n "$SOCKS5_ADDR" ] || die "Address kosong."
  [[ "$SOCKS5_PORT" =~ ^[0-9]+$ ]] || die "Port mesti nombor."
}

insert_socks5_outbound_file() {
  local f="$1" blk; blk="$(mktemp)"
  {
    echo "    {"
    echo "      \"protocol\": \"socks\","
    echo "      \"tag\": \"${SOCKS5_TAG}\","
    echo "      \"settings\": {"
    echo "        \"servers\": ["
    echo "          {"
    if [ -n "$SOCKS5_USER" ] || [ -n "$SOCKS5_PASS" ]; then
      echo "            \"address\": \"${SOCKS5_ADDR}\","
      echo "            \"port\": ${SOCKS5_PORT},"
      echo "            \"users\": ["
      echo "              { \"user\": \"${SOCKS5_USER}\", \"pass\": \"${SOCKS5_PASS}\" }"
      echo "            ]"
    else
      echo "            \"address\": \"${SOCKS5_ADDR}\","
      echo "            \"port\": ${SOCKS5_PORT}"
    fi
    echo "          }"
    echo "        ]"
    echo "      }"
    echo "    },"
  } > "$blk"
  awk -v BLK="$blk" '
    BEGIN{inOut=0;inObj=0;brace=0;done=0}
    {
      line=$0; print line
      if(done==1) next
      if(inOut==0){if(line ~ /"outbounds"[ \t]*:[ \t]*\[/)inOut=1;next}
      if(inObj==0 && line ~ /^[ \t]*{[ \t]*$/){inObj=1;brace=1;next}
      if(inObj==1){
        o=gsub(/[{]/,"&",line); c=gsub(/[}]/,"&",line); brace += o - c
        if(brace<=0){while((getline l < BLK)>0)print l; close(BLK); done=1}
        next
      }
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  rm -f "$blk"
}

update_socks5_outbound_file() {
  awk -v ADDR="$SOCKS5_ADDR" -v PORT="$SOCKS5_PORT" -v USER="$SOCKS5_USER" -v PASS="$SOCKS5_PASS" '
    BEGIN{inOut=0;inObj=0;brace=0;n=0;istag=0}
    {
      line=$0
      if(inOut==0){print line; if(line ~ /"outbounds"[ \t]*:[ \t]*\[/)inOut=1; next}
      if(inObj==0 && line ~ /^[ \t]*{[ \t]*$/){inObj=1;brace=1;n=1;buf[n]=line;istag=0;next}
      if(inObj==1){
        n++; buf[n]=line
        o=gsub(/[{]/,"&",line); c=gsub(/[}]/,"&",line); brace += o - c
        if(line ~ /"tag"[ \t]*:[ \t]*"socks5"/) istag=1
        if(brace<=0){
          for(i=1;i<=n;i++){
            l=buf[i]
            if(istag==1){
              if(l ~ /"address"[ \t]*:/) sub(/"address"[ \t]*:[ \t]*"[^"]*"/,"\"address\": \"" ADDR "\"",l)
              else if(l ~ /"port"[ \t]*:/) sub(/"port"[ \t]*:[ \t]*[0-9]+/,"\"port\": " PORT,l)
              else if(l ~ /"user"[ \t]*:/) sub(/"user"[ \t]*:[ \t]*"[^"]*"/,"\"user\": \"" USER "\"",l)
              else if(l ~ /"pass"[ \t]*:/) sub(/"pass"[ \t]*:[ \t]*"[^"]*"/,"\"pass\": \"" PASS "\"",l)
            }
            print l
          }
          inObj=0;brace=0;n=0;istag=0;delete buf; next
        }
        next
      }
      print line
      if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/) inOut=0
    }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

set_mode_file() {
  local f="$1" mode="$2"
  awk -v MODE="$mode" '
    BEGIN{inRule=0;brace=0;hasDom=0;done=0}
    {
      line=$0
      if(line ~ /{[ \t]*$/){inRule=1;brace=1;hasDom=0}
      else if(inRule==1){if(index(line,"{")>0)brace++;if(index(line,"}")>0)brace--}
      if(done==0 && inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/) hasDom=1
      if(done==0 && inRule==1 && hasDom==1 && line ~ /"outboundTag"[ \t]*:/){
        sub(/"(warp|direct|socks5)"/,"\"" MODE "\"",line); done=1
      }
      print line
      if(inRule==1 && brace<=0){inRule=0;brace=0;hasDom=0}
    }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

prompt_scope() {
  local title="$1" a
  {
    echo -e ""
    echo -e "${YELLOW}${BOLD}Pilih skop untuk mode ${title}:${RESET}"
    echo -e "   ${GREEN}${BOLD}1${RESET}) Hanya ${WHITE}DOMAIN LIST${RESET} lalu ${title}"
    echo -e "   ${RED}${BOLD}2${RESET}) ${WHITE}SEMUA trafik${RESET} lalu ${title} ${DIM}${GREY}(auto DNS/QUIC fix)${RESET}"
    echo -e "   ${DIM}${GREY}(Exclude list tetap DIRECT dalam kedua-dua skop)${RESET}"
  } >&2
  read -rp "$(echo -e "  ${CYAN}Skop [1/2] (default 1):${RESET} ")" a
  case "$a" in 2) echo "all";; *) echo "list";; esac
}

apply_mode_all() {
  local mode="$1" scope="$2" changed=0 skipped=0 f firsttag
  if [ "$scope" = "all" ]; then firsttag="$mode"; else firsttag="direct"; fi
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    set_mode_file "$f" "$mode"
    set_marker_file "$f" "$mode"
    ensure_first_outbound_file "$f" "$firsttag"
    apply_dns_tweak_file "$f" "$scope"
    changed=$((changed+1))
  done
  if [ "$scope" = "all" ]; then ok "Mode: ${mode} | Skop: SEMUA trafik + DNS/QUIC fix (changed=$changed skipped=$skipped)"
  else ok "Mode: ${mode} | Skop: domain list sahaja (changed=$changed skipped=$skipped)"; fi
  restart_xray_all
}

do_warp(){ local scope; scope="$(prompt_scope "WARP")"; apply_mode_all "warp" "$scope"; }
do_freedom(){ apply_mode_all "direct" "list"; }

enable_socks5_mode() {
  local f need=0
  for f in "${CFG_LIST[@]}"; do [ -f "$f" ] || continue; socks5_outbound_exists_file "$f" || { need=1; break; }; done
  [ "$need" -eq 1 ] && { info "Outbound 'socks5' belum wujud — sila isi."; prompt_socks5_details; }
  local scope; scope="$(prompt_scope "SOCKS5")"
  local firsttag; if [ "$scope" = "all" ]; then firsttag="socks5"; else firsttag="direct"; fi
  local changed=0 skipped=0
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    socks5_outbound_exists_file "$f" || insert_socks5_outbound_file "$f"
    set_marker_file "$f" "socks5"
    set_mode_file "$f" "socks5"
    ensure_first_outbound_file "$f" "$firsttag"
    apply_dns_tweak_file "$f" "$scope"
    changed=$((changed+1))
  done
  if [ "$scope" = "all" ]; then ok "SOCKS5 | Skop: SEMUA trafik + DNS/QUIC fix (changed=$changed skipped=$skipped)"
  else ok "SOCKS5 | Skop: domain list sahaja (changed=$changed skipped=$skipped)"; fi
  restart_xray_all
}

edit_socks5_server() {
  prompt_socks5_details
  local changed=0 skipped=0 f keep
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    keep="$(get_first_outbound_file "$f")"; [ -n "$keep" ] || keep="direct"
    backup "$f"
    if socks5_outbound_exists_file "$f"; then update_socks5_outbound_file "$f"; else insert_socks5_outbound_file "$f"; fi
    ensure_first_outbound_file "$f" "$keep"
    changed=$((changed+1))
  done
  ok "SOCKS5 server updated (changed=$changed skipped=$skipped)"
  restart_xray_all
}

load_preset_all() {
  echo
  echo -e "${GOLD}${BOLD}Muat PRESET domain${RESET} ${DIM}${GREY}(streaming, bank MY, Astro, RTMklik, CDN)${RESET}"
  echo -e "${DIM}${GREY}Domain custom sedia ada dikekalkan di bawah (CUSTOM).${RESET}"
  read -rp "$(echo -e "  ${CYAN}Teruskan? type YES:${RESET} ")" ans
  [ "$ans" = "YES" ] || { info "Cancelled."; return 0; }

  local ptype=() pval=() line
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [ -z "${line//[[:space:]]/}" ] && continue
    if [[ "$line" == \#* ]]; then ptype+=("c"); pval+=("$line")
    else
      line="${line//[[:space:]]/}"
      [[ "$line" != domain:* ]] && line="domain:$line"
      ptype+=("d"); pval+=("$line")
    fi
  done < <(preset_domains_raw)

  declare -A pset=(); local i
  for i in "${!ptype[@]}"; do [ "${ptype[$i]}" = "d" ] && pset["${pval[$i]}"]=1; done

  local changed=0 skipped=0 f d
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    local cval=() has_custom=0
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      if [ -z "${pset[$d]+x}" ]; then has_custom=1; cval+=("$d"); fi
    done < <(domains_list_file_raw "$f" || true)

    local atype=() aval=()
    for i in "${!ptype[@]}"; do atype+=("${ptype[$i]}"); aval+=("${pval[$i]}"); done
    if [ "$has_custom" -eq 1 ]; then
      atype+=("c"); aval+=("# ===== CUSTOM (KEKAL) =====")
      for i in "${!cval[@]}"; do atype+=("d"); aval+=("${cval[$i]}"); done
    fi

    local last=-1
    for i in "${!atype[@]}"; do [ "${atype[$i]}" = "d" ] && last=$i; done

    local ind
    ind="$(awk '/"domain"[ \t]*:[ \t]*\[[ \t]*$/{match($0,/^[ \t]*/); print substr($0,RSTART,RLENGTH) "  "; exit}' "$f")"
    [ -n "$ind" ] || ind="          "

    local blk; blk="$(mktemp)"
    for i in "${!atype[@]}"; do
      if [ "${atype[$i]}" = "c" ]; then printf '%s%s\n' "$ind" "${aval[$i]}" >> "$blk"
      else
        if [ "$i" -eq "$last" ]; then printf '%s"%s"\n' "$ind" "${aval[$i]}" >> "$blk"
        else printf '%s"%s",\n' "$ind" "${aval[$i]}" >> "$blk"; fi
      fi
    done
    replace_domain_block_file "$f" "$blk"
    rm -f "$blk"
    changed=$((changed+1))
  done
  ok "Preset dimuat (changed=$changed skipped=$skipped)"
  show_domains_all
  restart_xray_all
}

add_domain_all() {
  show_domains_global
  echo; echo -e "${YELLOW}Masukkan domain (1 baris 1). ENTER kosong = tamat.${RESET}"; echo
  local input=() line
  while true; do read -rp "> " line || true; line="${line// /}"; [ -z "$line" ] && break; input+=("$line"); done
  [ "${#input[@]}" -gt 0 ] || die "Tiada domain dimasukkan."
  local new_domains=() d; declare -A seen=()
  for d in "${input[@]}"; do
    d="${d// /}"; [ -n "$d" ] || continue
    [[ "$d" != domain:* ]] && d="domain:$d"
    if [ -z "${seen[$d]+x}" ]; then seen["$d"]=1; new_domains+=("$d"); fi
  done
  [ "${#new_domains[@]}" -gt 0 ] || die "Tiada domain valid."
  local changed_files=0 skipped=0 total_added=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    local need=0
    for d in "${new_domains[@]}"; do domains_list_file_raw "$f" | grep -qxF "$d" || { need=1; break; }; done
    [ "$need" -eq 1 ] || continue
    backup "$f"; local added=0
    for d in "${new_domains[@]}"; do
      domains_list_file_raw "$f" | grep -qxF "$d" && continue
      apply_domains_file "$f" "add" "$d"; added=$((added+1))
    done
    apply_domains_file "$f" "normalize" ""
    [ "$added" -gt 0 ] && { changed_files=$((changed_files+1)); total_added=$((total_added+added)); }
  done
  [ "$total_added" -eq 0 ] && { info "Semua domain dah wujud."; return 0; }
  ok "Domain added: $total_added (files=$changed_files skipped=$skipped)"
  show_domains_all
  restart_xray_all
}

delete_domain_global_number() {
  show_domains_global; build_global_domains
  [ "${#GLOBAL_DOMAINS[@]}" -gt 0 ] || die "GLOBAL domain list kosong."
  read -rp "Nombor domain nak buang 1..${#GLOBAL_DOMAINS[@]} (0 batal): " n
  [[ "$n" =~ ^[0-9]+$ ]] || die "Mesti nombor."
  [ "$n" -eq 0 ] && return 0
  { [ "$n" -ge 1 ] && [ "$n" -le "${#GLOBAL_DOMAINS[@]}" ]; } || die "Nombor tak sah."
  local target="${GLOBAL_DOMAINS[$((n-1))]}" changed=0 skipped=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    mapfile -t arr < <(domains_list_file_raw "$f" | sed '/^$/d' || true)
    local idx=-1 i
    for i in "${!arr[@]}"; do [ "${arr[$i]}" = "$target" ] && { idx=$((i+1)); break; }; done
    [ "$idx" -eq -1 ] && continue
    backup "$f"; apply_domains_file "$f" "del" "$idx"; apply_domains_file "$f" "normalize" ""
    changed=$((changed+1))
  done
  ok "Domain removed: $target (changed=$changed skipped=$skipped)"
  show_domains_all
  restart_xray_all
}

flush_domains_all() {
  echo -e "${YELLOW}NOTE:${RESET} Flush kekalkan placeholder: ${PINK}${FLUSH_PLACEHOLDER}${RESET}"
  read -rp "CONFIRM flush ALL files? type YES: " ans
  [ "$ans" = "YES" ] || { info "Cancelled."; return 0; }
  local donec=0 skipped=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"; apply_domains_file "$f" "flush" "$FLUSH_PLACEHOLDER"; donec=$((donec+1))
  done
  ok "Flush done (changed=$donec skipped=$skipped)"
  show_domains_all
  restart_xray_all
}

restart_one_service() {
  local svc="${1:-}"
  [ -n "$svc" ] || { echo -e "${RED}[FAIL]${RESET} restart_one_service tanpa nama servis"; return 1; }
  local cfg="$XRAY_DIR/${svc}.json"
  info "Restarting xray@${svc}..."
  systemctl reset-failed "xray@${svc}" 2>/dev/null || true
  if command -v xray >/dev/null 2>&1 && [ -f "$cfg" ]; then
    if ! xray -test -config "$cfg" >"/tmp/xray_test_${svc}.log" 2>&1; then
      echo -e "${RED}[FAIL]${RESET} config xray@${svc} TAK VALID — restart dibatalkan:"
      tail -n 15 "/tmp/xray_test_${svc}.log"; return 1
    fi
  fi
  if systemctl restart "xray@${svc}"; then
    sleep 1
    if systemctl is-active --quiet "xray@${svc}"; then ok "xray@${svc} aktif"
    else
      echo -e "${RED}[FAIL]${RESET} xray@${svc} tak aktif:"
      journalctl -u "xray@${svc}" -n 15 --no-pager 2>/dev/null || true; return 1
    fi
  else
    echo -e "${RED}[FAIL]${RESET} systemctl restart xray@${svc} gagal:"
    systemctl status "xray@${svc}" --no-pager -l 2>/dev/null | tail -n 15 || true; return 1
  fi
  return 0
}

restart_xray_all(){ restart_one_service "config" || true; sleep 3; restart_one_service "none" || true; }

cleanup_backups_all() {
  local total=0 f base c b deleted=0
  echo; echo -e "${YELLOW}NOTE:${RESET} DELETE semua backup (*.bak.*) dalam ${PINK}${XRAY_DIR}${RESET}"; echo
  for f in "${CFG_LIST[@]}"; do
    base="$(basename "$f")"
    c="$(find "$XRAY_DIR" -maxdepth 1 -type f -name "${base}.bak.*" 2>/dev/null | wc -l | tr -d ' ')"
    [ "${c:-0}" -gt 0 ] && { echo -e "${PINK}${base}${RESET}: ${c} backup(s)"; total=$((total+c)); }
  done
  [ "$total" -eq 0 ] && { info "No backup files found."; return 0; }
  echo; echo -e "${RED}Total:${RESET} $total backup(s) akan dipadam."
  read -rp "CONFIRM cleanup? type YES: " ans
  [ "$ans" = "YES" ] || { info "Cancelled."; return 0; }
  for f in "${CFG_LIST[@]}"; do
    base="$(basename "$f")"
    while IFS= read -r b; do [ -n "$b" ] && { rm -f -- "$b"; deleted=$((deleted+1)); }; done \
      < <(find "$XRAY_DIR" -maxdepth 1 -type f -name "${base}.bak.*" 2>/dev/null)
  done
  ok "Backup cleanup done. Deleted=$deleted"
}

import_domains_file_all() {
  local file=""
  echo; echo -e "${YELLOW}Path file domain list (1 baris 1 domain).${RESET}"
  read -rp "File path [/root/domainlist.txt]: " file
  file="${file// /}"; [ -z "$file" ] && file="/root/domainlist.txt"
  [ -f "$file" ] || die "File not found: $file"
  local raw=() line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"; line="${line// /}"; [ -z "$line" ] && continue; raw+=("$line")
  done < "$file"
  [ "${#raw[@]}" -gt 0 ] || die "File kosong."
  local new_domains=() d; declare -A seen=()
  for d in "${raw[@]}"; do
    [[ "$d" != domain:* ]] && d="domain:$d"
    if [ -z "${seen[$d]+x}" ]; then seen["$d"]=1; new_domains+=("$d"); fi
  done
  local changed_files=0 skipped=0 total_added=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    local need=0
    for d in "${new_domains[@]}"; do domains_list_file_raw "$f" | grep -qxF "$d" || { need=1; break; }; done
    [ "$need" -eq 1 ] || continue
    backup "$f"; local added=0
    for d in "${new_domains[@]}"; do
      domains_list_file_raw "$f" | grep -qxF "$d" && continue
      apply_domains_file "$f" "add" "$d"; added=$((added+1))
    done
    apply_domains_file "$f" "normalize" ""
    [ "$added" -gt 0 ] && { changed_files=$((changed_files+1)); total_added=$((total_added+added)); }
  done
  [ "$total_added" -eq 0 ] && { info "Semua domain dah wujud."; return 0; }
  ok "Imported: $total_added domain(s) (files=$changed_files skipped=$skipped)"
  show_domains_all
  restart_xray_all
}

repeat(){ local n="$1" s="$2" out=""; while [ "$n" -gt 0 ]; do out="$out$s"; n=$((n-1)); done; printf '%s' "$out"; }

ui_width() {
  local c; c="$(tput cols 2>/dev/null)"
  case "$c" in ''|*[!0-9]*) c="${COLUMNS:-48}";; esac
  case "$c" in ''|*[!0-9]*) c=48;; esac
  local w=$((c-2)); [ "$w" -gt 54 ] && w=54; [ "$w" -lt 30 ] && w=30
  printf '%s' "$w"
}

hr(){ echo -e "${1}$(repeat "$UIW" '─')${RESET}"; }
hrh(){ echo -e "${1}$(repeat "$UIW" '━')${RESET}"; }

mode_badge() {
  case "$1" in
    warp)   echo -e "${GREEN}${BOLD}WARP${RESET}" ;;
    direct) echo -e "${ORANGE}${BOLD}FREEDOM${RESET}" ;;
    socks5) echo -e "${CYAN}${BOLD}SOCKS5${RESET}" ;;
    *)      echo -e "${YELLOW}${BOLD}MIXED${RESET}" ;;
  esac
}
socks_badge(){ if [ "$1" = "OFF" ]; then echo -e "${RED}${BOLD}OFF${RESET}"; else echo -e "${LIME}${BOLD}${1}${RESET}"; fi; }
scope_badge(){ if [ "$1" = "all" ]; then echo -e "${RED}${BOLD}SEMUA trafik${RESET}"; else echo -e "${LIME}${BOLD}List sahaja${RESET}"; fi; }
section(){ echo -e "  ${1}| ${BOLD}${WHITE}${2}${RESET}"; }

print_header() {
  hrh "$1"
  echo -e "  ${BOLD}${WHITE}XRAY ROUTING ENGINE${RESET}"
  echo -e "  ${DIM}${GREY}warp . freedom . socks5 . router${RESET}"
  hrh "$1"
}

need_targets

while true; do
  clear
  UIW="$(ui_width)"
  gm="$(get_global_mode)"; sk="$(get_global_socks)"; sc="$(get_global_scope)"
  exclude_global_list; xc="${#EXCLUDE_GLOBAL[@]}"
  case "$gm" in warp) BAR="$GREEN";; direct) BAR="$ORANGE";; socks5) BAR="$CYAN";; *) BAR="$YELLOW";; esac

  print_header "$BAR"
  echo
  section "$VIOLET" "STATUS"
  echo -e "   ${GREY}Mode  :${RESET} $(mode_badge "$gm")"
  if [ "$gm" = "warp" ] || [ "$gm" = "socks5" ]; then
    echo -e "   ${GREY}Scope :${RESET} $(scope_badge "$sc")"
    if [ "$sc" = "all" ]; then
      ft="$(get_fulltunnel_applied)"
      if [ "$ft" = "yes" ]; then echo -e "   ${GREY}DNSfx :${RESET} ${GREEN}${BOLD}OK (AsIs + DNS direct + block QUIC)${RESET}"
      else echo -e "   ${GREY}DNSfx :${RESET} ${RED}${BOLD}belum patch${RESET}"; fi
    fi
  fi
  [ "$xc" -gt 0 ] && echo -e "   ${GREY}Bypass:${RESET} ${RED}${BOLD}${xc} domain${RESET} ${DIM}${GREY}-> direct${RESET}"
  echo -e "   ${GREY}Socks :${RESET} $(socks_badge "$sk")  ${DIM}${GREY}(${WARP_ADDR}:${WARP_PORT})${RESET}"
  echo -e "   ${GREY}Files :${RESET} ${PINK}${BOLD}${#CFG_LIST[@]}${RESET} ${GREY}config${RESET}"
  hr "$VIOLET"

  echo
  section "$TEAL" "MODE"
  echo -e "   ${GREEN}${BOLD}1${RESET}  ${WHITE}Enable WARP${RESET}    ${DIM}${GREY}pilih skop${RESET}"
  echo -e "   ${ORANGE}${BOLD}2${RESET}  ${WHITE}Set FREEDOM${RESET}    ${DIM}${GREY}semua direct${RESET}"
  echo -e "   ${CYAN}${BOLD}3${RESET}  ${WHITE}Set SOCKS5${RESET}     ${DIM}${GREY}pilih skop${RESET}"
  hr "$TEAL"

  echo
  section "$BLUE" "DOMAIN"
  echo -e "   ${GOLD}${BOLD}p${RESET}  ${WHITE}Load preset${RESET}    ${DIM}${GREY}streaming/bank/Astro/RTM/CDN${RESET}"
  echo -e "   ${GOLD}${BOLD}4${RESET}  ${WHITE}Add domain${RESET}     ${DIM}${GREY}multi${RESET}"
  echo -e "   ${GOLD}${BOLD}5${RESET}  ${WHITE}Delete domain${RESET}  ${DIM}${GREY}by no.${RESET}"
  echo -e "   ${RED}${BOLD}6${RESET}  ${WHITE}Flush domains${RESET}  ${DIM}${GREY}keep placeholder${RESET}"
  echo -e "   ${WHITE}${BOLD}7${RESET}  ${WHITE}Show domains${RESET}   ${DIM}${GREY}per file${RESET}"
  echo -e "   ${VIOLET}${BOLD}i${RESET}  ${WHITE}Import file${RESET}    ${DIM}${GREY}txt list${RESET}"
  echo -e "   ${RED}${BOLD}x${RESET}  ${WHITE}Exclude bypass${RESET} ${DIM}${GREY}sentiasa direct${RESET}"
  hr "$BLUE"

  echo
  section "$PINK" "SYSTEM"
  echo -e "   ${CYAN}${BOLD}e${RESET}  ${WHITE}Edit SOCKS5 server${RESET}"
  echo -e "   ${LIME}${BOLD}8${RESET}  ${WHITE}Restart Xray${RESET}   ${DIM}${GREY}config -> none${RESET}"
  echo -e "   ${YELLOW}${BOLD}9${RESET}  ${WHITE}Cleanup backup${RESET}"
  echo -e "   ${GREY}${BOLD}0${RESET}  ${WHITE}Kembali ke menu utama${RESET}"
  hr "$PINK"

  echo
  echo -e "  ${DIM}${GREY}Tip: 'p' = preset besar . 'x' = domain yang TAK NAK lalu warp/socks5${RESET}"
  echo

  read -rp "$(echo -e "  ${CYAN}${BOLD}Pilih:${RESET} ")" c
  case "$c" in
    1)   do_warp ;;
    2)   do_freedom ;;
    3)   enable_socks5_mode ;;
    p|P) load_preset_all ;;
    4)   add_domain_all ;;
    5)   delete_domain_global_number ;;
    6)   flush_domains_all ;;
    7)   show_domains_all ;;
    i|I) import_domains_file_all ;;
    x|X) manage_exclude ;;
    e|E) edit_socks5_server ;;
    8)   restart_xray_all ;;
    9)   cleanup_backups_all ;;
    0)   exec menu ;;
    *)   info "Invalid option" ;;
  esac

  echo
  read -rp "$(echo -e "  ${DIM}${GREY}Tekan Enter untuk kembali...${RESET}")" _
done
