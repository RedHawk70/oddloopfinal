#!/bin/bash
# XRAY WARP / FREEDOM / SOCKS5 MENU  (full-fix, auto-restart)
# - TARGET JSON LIST ONLY (no jq), KEEP #COMMENTS
# - Domain list managed from FIRST rule that contains: "domain": [ ... ]
# - MODE switch (warp/direct/socks5) only changes that rule's outboundTag
# - Marker comment auto-follows mode (WARP / FREEDOM / SOCKS5), letak atas "domain": [
# - SELF-HEAL: 'direct' (freedom) sentiasa jadi outbound PERTAMA (default)
# - SOCKS5 mode: auto-insert outbound "tag":"socks5" kalau belum ada
# - Status SOCKS rujuk WARP local (127.0.0.1:40000) sahaja
# - AUTO-RESTART xray@none + xray@config selepas setiap perubahan config
# - Only domains in the list route via warp/socks5; everything else = direct
# NOTA: routing domain perlukan "sniffing" enabled pada inbounds (uruskan di config, bukan script ni)
set -euo pipefail

XRAY_DIR="/usr/local/etc/xray"

CFG_LIST=(
  "$XRAY_DIR/none.json"
  "$XRAY_DIR/config.json"
)

WARP_ADDR="127.0.0.1"
WARP_PORT="40000"
FLUSH_PLACEHOLDER="domain:example.net"

# SOCKS5 outbound (auto-managed)
SOCKS5_TAG="socks5"
SOCKS5_ADDR=""
SOCKS5_PORT=""
SOCKS5_USER=""
SOCKS5_PASS=""

# ===== Colors =====
RESET="\e[0m"; BOLD="\e[1m"; DIM="\e[2m"; WHITE="\e[97m"
GREEN="\e[92m"; YELLOW="\e[93m"; ORANGE="\e[38;5;208m"
RED="\e[91m"; CYAN="\e[96m"; PINK="\e[38;5;213m"

die(){ echo -e "\n${RED}[ERROR]${RESET} $*\n"; exit 1; }
ok(){  echo -e "${GREEN}[OK]${RESET} $*"; }
info(){ echo -e "${CYAN}[INFO]${RESET} $*"; }

backup(){ cp -a "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"; }

need_targets() {
  local any=0
  for f in "${CFG_LIST[@]}"; do [ -f "$f" ] && { any=1; break; }; done
  [ "$any" -eq 1 ] || die "No target JSON found in the configured list."
}

# --------- SOCKS listen check ---------
is_listening() {
  local addr="$1" port="$2"
  ss -lnt 2>/dev/null | awk -v p=":$port" '$1=="LISTEN" && index($4,p)>0 {found=1} END{exit(found?0:1)}'
}

# Status SOCKS = WARP local proxy (127.0.0.1:40000) sahaja
get_global_socks() {
  if is_listening "$WARP_ADDR" "$WARP_PORT"; then echo "$WARP_PORT"; else echo "OFF"; fi
}

# --------- MODE detect ---------
get_mode_file() {
  local f="$1"
  awk '
    BEGIN{inRule=0; brace=0; hasDom=0}
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    {
      line=$0
      if(line ~ /{[ \t]*$/){ inRule=1; brace=1; hasDom=0 }
      else if(inRule==1){ if(index(line,"{")>0) brace++; if(index(line,"}")>0) brace-- }
      if(inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){ hasDom=1 }
      if(inRule==1 && hasDom==1 && line ~ /"outboundTag"[ \t]*:/){
        v=line; gsub(/.*"outboundTag"[ \t]*:[ \t]*"/,"",v); gsub(/".*/,"",v); print trim(v); exit
      }
      if(inRule==1 && brace<=0){ inRule=0; brace=0; hasDom=0 }
    }
  ' "$f" 2>/dev/null || true
}

get_global_mode() {
  local w=0 d=0 s=0 u=0 m="" f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    m="$(get_mode_file "$f")"
    case "$m" in
      warp) w=1 ;; direct) d=1 ;; socks5) s=1 ;; "") u=1 ;; *) u=1 ;;
    esac
  done
  if   [ "$w" -eq 1 ] && [ "$d" -eq 0 ] && [ "$s" -eq 0 ] && [ "$u" -eq 0 ]; then echo "warp"
  elif [ "$d" -eq 1 ] && [ "$w" -eq 0 ] && [ "$s" -eq 0 ] && [ "$u" -eq 0 ]; then echo "direct"
  elif [ "$s" -eq 1 ] && [ "$w" -eq 0 ] && [ "$d" -eq 0 ] && [ "$u" -eq 0 ]; then echo "socks5"
  else echo "mixed"; fi
}

status_line() {
  local mode socks color label scol
  mode="$(get_global_mode)"; socks="$(get_global_socks)"
  case "$mode" in
    warp)   color="$GREEN";  label="WARP" ;;
    direct) color="$ORANGE"; label="DIRECT" ;;
    socks5) color="$CYAN";   label="SOCKS5" ;;
    *)      color="$YELLOW"; label="MIXED/UNKNOWN" ;;
  esac
  scol="$CYAN"; [ "$socks" = "OFF" ] && scol="$RED"
  echo -e "${color}${BOLD}MODE:${RESET} ${color}${label}${RESET}  | ${BOLD}SOCKS:${RESET} ${scol}${socks}${RESET}"
}

# --------- DOMAIN helpers ---------
domains_list_file_raw() {
  local f="$1"
  awk '
    BEGIN{inRule=0; brace=0; hasDom=0; inDom=0}
    function clean(s){ gsub(/[",]/,"",s); sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    {
      line=$0
      if(line ~ /{[ \t]*$/){ inRule=1; brace=1; hasDom=0; inDom=0 }
      else if(inRule==1){ if(index(line,"{")>0) brace++; if(index(line,"}")>0) brace-- }
      if(inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){ hasDom=1; inDom=1; next }
      if(inRule==1 && hasDom==1 && inDom==1){
        if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/){ exit }
        if(line ~ /domain:/){ print clean(line) }
        next
      }
      if(inRule==1 && brace<=0){ inRule=0; brace=0; hasDom=0; inDom=0 }
    }
  ' "$f" 2>/dev/null || true
}

apply_domains_file() {
  local f="$1" action="$2" param="${3:-}"
  awk -v ACTION="$action" -v PARAM="$param" '
    BEGIN{inRule=0; brace=0; hasDom=0; inDom=0; dn=0; hn=0; indent=""; targetDone=0}
    function push_dom(s){ if(s=="") return; for(i=1;i<=dn;i++) if(dom[i]==s) return; dom[++dn]=s }
    function clean(s){ gsub(/[",]/,"",s); sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    function flush_domain_block(closeLine){
      if(ACTION=="add"){ push_dom(PARAM) }
      else if(ACTION=="del"){ k=PARAM+0; if(k>=1 && k<=dn){ for(i=k;i<dn;i++) dom[i]=dom[i+1]; dn-- } }
      else if(ACTION=="flush"){ dn=0; push_dom(PARAM) }
      if(indent=="") indent="          "
      for(j=1;j<=hn;j++) print hdr[j]
      for(i=1;i<=dn;i++){ if(i<dn) printf "%s\"%s\",\n", indent, dom[i]; else printf "%s\"%s\"\n", indent, dom[i] }
      print closeLine
      targetDone=1
    }
    {
      line=$0
      if(line ~ /{[ \t]*$/){ inRule=1; brace=1; hasDom=0; inDom=0; dn=0; hn=0; indent="" }
      else if(inRule==1){ if(index(line,"{")>0) brace++; if(index(line,"}")>0) brace-- }
      if(targetDone==0 && inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){ hasDom=1; inDom=1; print line; next }
      if(targetDone==0 && inRule==1 && hasDom==1 && inDom==1){
        if(indent=="" && match(line,/^[ \t]*/)) indent=substr(line,RSTART,RLENGTH)
        if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/){ flush_domain_block(line); inDom=0; next }
        if(line ~ /^[ \t]*#/){ hdr[++hn]=line; next }
        if(line ~ /domain:/){ push_dom(clean(line)) }
        next
      }
      print line
      if(inRule==1 && brace<=0){ inRule=0; brace=0; hasDom=0; inDom=0 }
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
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
  local idx=0 shown=0 f i
  echo; echo -e "${ORANGE}--------------------------------------${RESET}"
  echo -e "${WHITE}${BOLD}Current Domains (ANCHOR RULE)${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"
  for f in "${CFG_LIST[@]}"; do
    idx=$((idx+1)); [ -f "$f" ] || continue
    echo -e "${PINK}File #${idx}:${RESET} ${DIM}$(basename "$f")${RESET}"
    mapfile -t arr < <(domains_list_file_raw "$f" | sed '/^$/d' || true)
    if [ "${#arr[@]}" -eq 0 ]; then echo "  - (empty)"
    else for i in "${!arr[@]}"; do printf "  %2d) %s\n" $((i+1)) "${arr[$i]}"; done; fi
    echo; shown=1
  done
  [ "$shown" -eq 1 ] || echo -e "${YELLOW}No target file found.${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"; echo
}

show_domains_global() {
  build_global_domains
  echo; echo -e "${ORANGE}--------------------------------------${RESET}"
  echo -e "${WHITE}${BOLD}Domains (GLOBAL LIST)${RESET}  ${DIM}- merged, de-duplicated${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"
  if [ "${#GLOBAL_DOMAINS[@]}" -eq 0 ]; then echo "  - (empty)"
  else local i; for i in "${!GLOBAL_DOMAINS[@]}"; do printf "  %2d) %s\n" $((i+1)) "${GLOBAL_DOMAINS[$i]}"; done; fi
  echo -e "${ORANGE}--------------------------------------${RESET}"; echo
}

# --------- MARKER (mode-aware) ---------
marker_text_for_mode() {
  case "$1" in
    warp)   echo "/* ===== DOMAIN WARP (MUDAH BUANG) ===== */" ;;
    socks5) echo "/* ===== DOMAIN LALU SOCKS5 (TAMBAH / BUANG DI SINI) ===== */" ;;
    direct) echo "/* ===== DOMAIN FREEDOM (MUDAH BUANG) ===== */" ;;
    *)      echo "/* ===== DOMAIN LIST ===== */" ;;
  esac
}

# Buang semua marker DOMAIN sedia ada, letak satu marker ikut mode tepat atas "domain": [
set_marker_file() {
  local f="$1" mode="$2" mark
  mark="$(marker_text_for_mode "$mode")"
  awk -v MARK="$mark" '
    BEGIN{done=0}
    {
      if($0 ~ /\/\*.*DOMAIN.*\*\//){ next }
      if(done==0 && $0 ~ /"domain"[ \t]*:[ \t]*\[/){
        match($0, /^[ \t]*/); ind=substr($0,RSTART,RLENGTH)
        print ind MARK; print $0; done=1; next
      }
      print $0
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# --------- OUTBOUND ORDER (self-heal: 'direct' mesti pertama) ---------
ensure_direct_first_file() {
  local f="$1"
  awk '
    BEGIN{inOut=0; collecting=0; nobj=0; depth=0}
    {
      if(inOut==0){
        print $0
        if($0 ~ /"outbounds"[ \t]*:[ \t]*\[/){ inOut=1; collecting=1 }
        next
      }
      if(collecting==1){
        if(depth==0 && $0 ~ /^[ \t]*\][ \t]*,?[ \t]*$/){
          di=0
          for(i=1;i<=nobj;i++){ if(tag[i]=="direct"){ di=i; break } }
          on=0
          if(di>0){ order[++on]=di }
          for(i=1;i<=nobj;i++){ if(i!=di){ order[++on]=i } }
          for(k=1;k<=on;k++){
            idx=order[k]; m=split(buf[idx], L, "\n")
            for(j=1;j<=m;j++){
              cur=L[j]
              if(j==m){ sub(/,[ \t]*$/, "", cur); if(k<on){ cur=cur "," } }
              print cur
            }
          }
          print $0; inOut=0; collecting=0; next
        }
        line=$0
        o=gsub(/[{]/,"&",line); c=gsub(/[}]/,"&",line)
        if(depth==0 && o>0){ nobj++; buf[nobj]=$0; tag[nobj]="" }
        else { buf[nobj]=buf[nobj] "\n" $0 }
        if($0 ~ /"tag"[ \t]*:[ \t]*"[^"]*"/){ t=$0; gsub(/.*"tag"[ \t]*:[ \t]*"/,"",t); gsub(/".*/,"",t); tag[nobj]=t }
        depth += o - c
        next
      }
      print $0
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# --------- SOCKS5 outbound auto-manage ---------
socks5_outbound_exists_file() { grep -Eq '"tag"[[:space:]]*:[[:space:]]*"socks5"' "$1"; }

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

# Insert AFTER the first outbound object (order dikemas semula oleh ensure_direct_first_file)
insert_socks5_outbound_file() {
  local f="$1" blk
  blk="$(mktemp)"
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
      echo "              {"
      echo "                \"user\": \"${SOCKS5_USER}\","
      echo "                \"pass\": \"${SOCKS5_PASS}\""
      echo "              }"
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
    BEGIN{inOut=0; inObj=0; brace=0; done=0}
    {
      line=$0
      print line
      if(done==1) next
      if(inOut==0){ if(line ~ /"outbounds"[ \t]*:[ \t]*\[/) inOut=1; next }
      if(inObj==0 && line ~ /^[ \t]*{[ \t]*$/){ inObj=1; brace=1; next }
      if(inObj==1){
        o=gsub(/[{]/,"&",line); c=gsub(/[}]/,"&",line); brace += o - c
        if(brace<=0){
          while((getline l < BLK) > 0) print l
          close(BLK); done=1
        }
        next
      }
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  rm -f "$blk"
}

update_socks5_outbound_file() {
  local f="$1"
  awk -v ADDR="$SOCKS5_ADDR" -v PORT="$SOCKS5_PORT" -v USER="$SOCKS5_USER" -v PASS="$SOCKS5_PASS" '
    BEGIN{inOut=0; inObj=0; brace=0; n=0; istag=0}
    {
      line=$0
      if(inOut==0){ print line; if(line ~ /"outbounds"[ \t]*:[ \t]*\[/) inOut=1; next }
      if(inObj==0 && line ~ /^[ \t]*{[ \t]*$/){ inObj=1; brace=1; n=1; buf[n]=line; istag=0; next }
      if(inObj==1){
        n++; buf[n]=line
        o=gsub(/[{]/,"&",line); c=gsub(/[}]/,"&",line); brace += o - c
        if(line ~ /"tag"[ \t]*:[ \t]*"socks5"/) istag=1
        if(brace<=0){
          for(i=1;i<=n;i++){
            l=buf[i]
            if(istag==1){
              if(l ~ /"address"[ \t]*:/) sub(/"address"[ \t]*:[ \t]*"[^"]*"/, "\"address\": \"" ADDR "\"", l)
              else if(l ~ /"port"[ \t]*:/) sub(/"port"[ \t]*:[ \t]*[0-9]+/, "\"port\": " PORT, l)
              else if(l ~ /"user"[ \t]*:/) sub(/"user"[ \t]*:[ \t]*"[^"]*"/, "\"user\": \"" USER "\"", l)
              else if(l ~ /"pass"[ \t]*:/) sub(/"pass"[ \t]*:[ \t]*"[^"]*"/, "\"pass\": \"" PASS "\"", l)
            }
            print l
          }
          inObj=0; brace=0; n=0; istag=0; delete buf; next
        }
        next
      }
      print line
      if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/) inOut=0
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# --------- MODE actions ---------
set_mode_file() {
  local f="$1" mode="$2"
  awk -v MODE="$mode" '
    BEGIN{inRule=0; brace=0; hasDom=0; done=0}
    {
      line=$0
      if(line ~ /{[ \t]*$/){ inRule=1; brace=1; hasDom=0 }
      else if(inRule==1){ if(index(line,"{")>0) brace++; if(index(line,"}")>0) brace-- }
      if(done==0 && inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){ hasDom=1 }
      if(done==0 && inRule==1 && hasDom==1 && line ~ /"outboundTag"[ \t]*:/){
        sub(/"(warp|direct|socks5)"/, "\"" MODE "\"", line); done=1
      }
      print line
      if(inRule==1 && brace<=0){ inRule=0; brace=0; hasDom=0 }
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

set_mode_all() {
  local mode="$1" changed=0 skipped=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    set_mode_file "$f" "$mode"
    set_marker_file "$f" "$mode"
    ensure_direct_first_file "$f"
    changed=$((changed+1))
  done
  ok "Mode updated: $mode (changed=$changed, skipped=$skipped)"
  restart_xray_all
}

enable_socks5_mode() {
  local f need_details=0
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    socks5_outbound_exists_file "$f" || { need_details=1; break; }
  done
  if [ "$need_details" -eq 1 ]; then
    info "Outbound 'socks5' belum wujud dalam sebahagian config — sila isi."
    prompt_socks5_details
  fi
  local changed=0 skipped=0
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    socks5_outbound_exists_file "$f" || insert_socks5_outbound_file "$f"
    set_marker_file "$f" "socks5"
    set_mode_file "$f" "socks5"
    ensure_direct_first_file "$f"
    changed=$((changed+1))
  done
  ok "SOCKS5 enabled (default kekal 'direct'; hanya domain list -> socks5) changed=$changed skipped=$skipped"
  restart_xray_all
}

edit_socks5_server() {
  prompt_socks5_details
  local changed=0 skipped=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    if socks5_outbound_exists_file "$f"; then update_socks5_outbound_file "$f"
    else insert_socks5_outbound_file "$f"; fi
    ensure_direct_first_file "$f"
    changed=$((changed+1))
  done
  ok "SOCKS5 server updated (changed=$changed skipped=$skipped)"
  restart_xray_all
}

# --------- DOMAIN actions ---------
add_domain_all() {
  show_domains_global
  echo; echo -e "${YELLOW}Masukkan domain banyak-banyak (1 baris 1 domain).${RESET}"
  echo -e "${YELLOW}Contoh:${RESET} speedtest.net / fb.com / ig.com"
  echo -e "${YELLOW}Tekan ENTER kosong untuk tamat input.${RESET}"; echo
  local input=() line
  while true; do
    read -rp "> " line || true
    line="${line// /}"; [ -z "$line" ] && break
    input+=("$line")
  done
  [ "${#input[@]}" -gt 0 ] || die "Tiada domain dimasukkan."
  local new_domains=() d; declare -A seen=()
  for d in "${input[@]}"; do
    d="${d// /}"; [ -n "$d" ] || continue
    [[ "$d" != domain:* ]] && d="domain:$d"
    if [ -z "${seen[$d]+x}" ]; then seen["$d"]=1; new_domains+=("$d"); fi
  done
  [ "${#new_domains[@]}" -gt 0 ] || die "Tiada domain valid selepas normalize."
  local changed_files=0 skipped=0 total_added=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    local need_backup=0
    for d in "${new_domains[@]}"; do
      if ! domains_list_file_raw "$f" | grep -qxF "$d"; then need_backup=1; break; fi
    done
    [ "$need_backup" -eq 1 ] || continue
    backup "$f"; local added_here=0
    for d in "${new_domains[@]}"; do
      domains_list_file_raw "$f" | grep -qxF "$d" && continue
      apply_domains_file "$f" "add" "$d"; added_here=$((added_here+1))
    done
    apply_domains_file "$f" "normalize" ""
    if [ "$added_here" -gt 0 ]; then changed_files=$((changed_files+1)); total_added=$((total_added+added_here)); fi
  done
  if [ "$total_added" -eq 0 ]; then info "Semua domain dah wujud. Tiada perubahan."; return 0; fi
  ok "Domain(s) added: $total_added (files=$changed_files, skipped=$skipped)"
  echo -e "${CYAN}Added:${RESET}"; for d in "${new_domains[@]}"; do echo "  - $d"; done
  show_domains_all
  restart_xray_all
}

delete_domain_global_number() {
  show_domains_global; build_global_domains
  [ "${#GLOBAL_DOMAINS[@]}" -gt 0 ] || die "GLOBAL domain list is empty."
  read -rp "Nombor domain nak buang 1..${#GLOBAL_DOMAINS[@]} (0 batal): " n
  [[ "$n" =~ ^[0-9]+$ ]] || die "Mesti nombor."
  [ "$n" -eq 0 ] && return 0
  [ "$n" -ge 1 ] && [ "$n" -le "${#GLOBAL_DOMAINS[@]}" ] || die "Nombor tak sah."
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
  ok "Domain removed (ALL): $target (changed=$changed, skipped=$skipped)"
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
  ok "Flush completed (placeholder kept) (changed=$donec, skipped=$skipped)"
  show_domains_all
  restart_xray_all
}

restart_xray_all() {
  systemctl restart xray@none 2>/dev/null || true
  systemctl restart xray@config 2>/dev/null || true
  ok "Restarted all target services (xray@none + xray@config)"
}

cleanup_backups_all() {
  local total=0 f base c b deleted=0
  echo; echo -e "${YELLOW}NOTE:${RESET} DELETE semua backup (*.bak.*) dalam ${PINK}${XRAY_DIR}${RESET}"; echo
  for f in "${CFG_LIST[@]}"; do
    base="$(basename "$f")"
    c="$(find "$XRAY_DIR" -maxdepth 1 -type f -name "${base}.bak.*" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${c:-0}" -gt 0 ]; then echo -e "${PINK}${base}${RESET}: ${c} backup(s)"; total=$((total + c)); fi
  done
  if [ "$total" -eq 0 ]; then info "No backup files found."; return 0; fi
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
  [ "${#raw[@]}" -gt 0 ] || die "File kosong / tiada domain valid."
  local new_domains=() d; declare -A seen=()
  for d in "${raw[@]}"; do
    [[ "$d" != domain:* ]] && d="domain:$d"
    if [ -z "${seen[$d]+x}" ]; then seen["$d"]=1; new_domains+=("$d"); fi
  done
  [ "${#new_domains[@]}" -gt 0 ] || die "Tiada domain valid selepas normalize."
  local changed_files=0 skipped=0 total_added=0 f
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    local need_backup=0
    for d in "${new_domains[@]}"; do
      if ! domains_list_file_raw "$f" | grep -qxF "$d"; then need_backup=1; break; fi
    done
    [ "$need_backup" -eq 1 ] || continue
    backup "$f"; local added_here=0
    for d in "${new_domains[@]}"; do
      domains_list_file_raw "$f" | grep -qxF "$d" && continue
      apply_domains_file "$f" "add" "$d"; added_here=$((added_here+1))
    done
    apply_domains_file "$f" "normalize" ""
    if [ "$added_here" -gt 0 ]; then changed_files=$((changed_files+1)); total_added=$((total_added+added_here)); fi
  done
  if [ "$total_added" -eq 0 ]; then info "Semua domain dalam file dah wujud."; return 0; fi
  ok "Imported: $total_added domain(s) dari $file (files=$changed_files, skipped=$skipped)"
  show_domains_all
  restart_xray_all
}

# ---------- MAIN ----------
need_targets

while true; do
  clear
  gm="$(get_global_mode)"
  case "$gm" in
    warp) BAR="$GREEN" ;; direct) BAR="$ORANGE" ;; socks5) BAR="$CYAN" ;; *) BAR="$YELLOW" ;;
  esac

  echo -e "${BAR}======================================${RESET}"
  echo -e "${WHITE}${BOLD}XRAY WARP / FREEDOM / SOCKS5 MENU${RESET}"
  echo -e "${BAR}======================================${RESET}"
  echo -e " ${WHITE}Targets :${RESET} ${PINK}${#CFG_LIST[@]} config(s)${RESET}"
  echo -e " ${WHITE}Status  :${RESET} $(status_line)"
  echo -e "${BAR}--------------------------------------${RESET}"
  echo -e " ${PINK}1)${RESET} Enable WARP    (domain list -> warp)"
  echo -e " ${PINK}2)${RESET} Set FREEDOM    (domain list -> direct)"
  echo -e " ${PINK}3)${RESET} Set SOCKS5     (domain list -> socks5, auto setup)"
  echo -e " ${PINK}4)${RESET} Add domain (yang nak lalu warp/socks5) [MULTI]"
  echo -e " ${PINK}5)${RESET} Delete domain (by number)"
  echo -e " ${PINK}6)${RESET} Flush domains (keep placeholder)"
  echo -e " ${PINK}7)${RESET} Show domains (GLOBAL list)"
  echo -e " ${PINK}8)${RESET} Restart XRAY (target services)"
  echo -e " ${PINK}9)${RESET} Cleanup backup files (*.bak.*)"
  echo -e " ${PINK}e)${RESET} Edit SOCKS5 server (address/port/user/pass)"
  echo -e " ${PINK}i)${RESET} Import domains from file"
  echo -e ""
  echo -e " ${PINK}0)${RESET} Back to menu"
  echo -e "${BAR}--------------------------------------${RESET}"
  echo -e " ${YELLOW}❇️  Default trafik lain kekal DIRECT. Hanya domain dalam list lalu warp/socks5.${RESET}"
  echo -e " ${YELLOW}❇️  Auto-restart xray@none + xray@config selepas setiap perubahan.${RESET}"
  echo

  read -rp "Select: " c
  case "$c" in
    1) set_mode_all "warp" ;;
    2) set_mode_all "direct" ;;
    3) enable_socks5_mode ;;
    4) add_domain_all ;;
    5) delete_domain_global_number ;;
    6) flush_domains_all ;;
    7) show_domains_global; read -rp "Press Enter..." ;;
    8) restart_xray_all ;;
    9) cleanup_backups_all ;;
    e|E) edit_socks5_server ;;
    i|I) import_domains_file_all ;;
    0) exec menu ;;
    *) info "Invalid option"; sleep 1 ;;
  esac
  read -rp "Press Enter to continue..."
done
