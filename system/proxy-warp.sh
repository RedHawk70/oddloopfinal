#!/bin/bash
# XRAY WARP / FREEDOM MENU
# - TARGET JSON LIST ONLY
# - KEEP #COMMENTS (no jq)
# - DOMAIN list managed from FIRST rule that contains:  "domain": [ ... ]
# - DELETE by NUMBER => remove that domain index from ALL target JSON (no choose file)
# - FLUSH => keep 1 safe placeholder domain to avoid empty list issues
# - SOCKS status (FIX): show port ONLY if it is REALLY LISTENING on the VPS
set -euo pipefail

XRAY_DIR="/usr/local/etc/xray"

CFG_LIST=(
  "$XRAY_DIR/none.json"
  "$XRAY_DIR/config.json"
)

# expected warp socks (used only as reference)
WARP_ADDR="127.0.0.1"
WARP_PORT="40000"

# When flushing, keep 1 placeholder entry (avoid empty domain[] problems)
FLUSH_PLACEHOLDER="domain:example.net"

# ===== Colors =====
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
WHITE="\e[97m"
GREEN="\e[92m"
YELLOW="\e[93m"
ORANGE="\e[38;5;208m"
RED="\e[91m"
CYAN="\e[96m"
PINK="\e[38;5;213m"

die(){ echo -e "\n${RED}[ERROR]${RESET} $*\n"; exit 1; }
ok(){ echo -e "${GREEN}[OK]${RESET} $*"; }
info(){ echo -e "${CYAN}[INFO]${RESET} $*"; }

backup(){ cp -a "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"; }

need_targets() {
  local any=0
  for f in "${CFG_LIST[@]}"; do
    if [ -f "$f" ]; then any=1; break; fi
  done
  [ "$any" -eq 1 ] || die "No target JSON found in the configured list."
}

# ---------------------------------------------------------
# REAL SOCKS LISTEN CHECK (FIX)
# - Parse config to find outbound { tag:"warp", protocol:"socks" }
# - Extract address + port
# - Only show it as ACTIVE if the port is REALLY LISTENING (ss)
# ---------------------------------------------------------

is_listening() {
  # returns 0 if listening, 1 otherwise
  local addr="$1" port="$2"
  ss -lnt 2>/dev/null | awk -v p=":$port" '$1=="LISTEN" && index($4,p)>0 {found=1} END{exit(found?0:1)}'
}

# return "addr port" if config has outbound warp socks, else empty
detect_warp_socks_addr_port_file() {
  local f="$1"
  awk '
    BEGIN{
      inOut=0; inObj=0; brace=0;
      tag=""; proto="";
      addr=""; port="";
      found=0;
    }
    function reset_obj(){ tag=""; proto=""; addr=""; port=""; }
    function emit_if_match(){
      if(tag=="warp" && proto=="socks"){
        if(addr!="" && port!=""){
          print addr " " port
          found=1
        }
      }
    }
    {
      line=$0

      if(inOut==0 && line ~ /"outbounds"[ \t]*:[ \t]*\[/){
        inOut=1
        next
      }

      if(inOut==1){
        # end outbounds array
        if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/){
          if(inObj==1){ emit_if_match() }
          inOut=0
        }

        # start object
        if(inObj==0 && line ~ /{[ \t]*$/){
          inObj=1
          brace=1
          reset_obj()
          next
        }

        if(inObj==1){
          if(index(line,"{")>0) brace++
          if(index(line,"}")>0) brace--

          if(line ~ /"tag"[ \t]*:/){
            v=line
            gsub(/.*"tag"[ \t]*:[ \t]*"/,"",v)
            gsub(/".*/,"",v)
            tag=v
          }
          if(line ~ /"protocol"[ \t]*:/){
            v=line
            gsub(/.*"protocol"[ \t]*:[ \t]*"/,"",v)
            gsub(/".*/,"",v)
            proto=v
          }

          # socks settings (first wins)
          if(addr=="" && line ~ /"address"[ \t]*:/){
            v=line
            gsub(/.*"address"[ \t]*:[ \t]*"/,"",v)
            gsub(/".*/,"",v)
            addr=v
          }
          if(port=="" && line ~ /"port"[ \t]*:/){
            v=line
            gsub(/.*"port"[ \t]*:[ \t]*/,"",v)
            gsub(/[^0-9].*/,"",v)
            if(v!="") port=v
          }

          if(brace<=0){
            emit_if_match()
            inObj=0
            brace=0
            if(found==1){ exit }
          }
          next
        }
      }
    }
  ' "$f" 2>/dev/null || true
}

get_global_socks() {
  local any_active=0
  local ports_active=""

  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue

    local ap addr port
    ap="$(detect_warp_socks_addr_port_file "$f" || true)"
    [ -n "$ap" ] || continue

    addr="$(awk '{print $1}' <<<"$ap")"
    port="$(awk '{print $2}' <<<"$ap")"
    [ -n "$addr" ] && [ -n "$port" ] || continue

    # only count if REALLY listening
    if is_listening "$addr" "$port"; then
      any_active=1
      ports_active+="$port "
    fi
  done

  if [ "$any_active" -eq 0 ]; then
    echo "OFF"
    return
  fi

  # unique ports
  local uniq
  uniq="$(echo "$ports_active" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/[ \t]*$//')"
  if [ "$(echo "$uniq" | wc -w)" -eq 1 ]; then
    echo "$uniq"
  else
    echo "MIXED"
  fi
}

# ---------- MODE (warp/direct) from FIRST rule that has domain[] ----------
get_mode_file() {
  local f="$1"
  awk '
    BEGIN{inRule=0; brace=0; hasDom=0}
    function trim(s){ sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    {
      line=$0
      if(line ~ /{[ \t]*$/){
        inRule=1; brace=1; hasDom=0
      } else if(inRule==1){
        if(index(line,"{")>0) brace++
        if(index(line,"}")>0) brace--
      }

      if(inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){ hasDom=1 }

      if(inRule==1 && hasDom==1 && line ~ /"outboundTag"[ \t]*:/){
        v=line
        gsub(/.*"outboundTag"[ \t]*:[ \t]*"/,"",v)
        gsub(/".*/,"",v)
        print trim(v)
        exit
      }

      if(inRule==1 && brace<=0){ inRule=0; brace=0; hasDom=0 }
    }
  ' "$f" 2>/dev/null || true
}

get_global_mode() {
  local w=0 d=0 u=0
  local m=""
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    m="$(get_mode_file "$f")"
    case "$m" in
      warp) w=1 ;;
      direct) d=1 ;;
      "") u=1 ;;
      *) u=1 ;;
    esac
  done
  if [ "$w" -eq 1 ] && [ "$d" -eq 0 ] && [ "$u" -eq 0 ]; then
    echo "warp"
  elif [ "$d" -eq 1 ] && [ "$w" -eq 0 ] && [ "$u" -eq 0 ]; then
    echo "direct"
  else
    echo "mixed"
  fi
}

status_line() {
  local mode socks color label
  mode="$(get_global_mode)"
  socks="$(get_global_socks)"
  case "$mode" in
    warp)   color="$GREEN";  label="WARP" ;;
    direct) color="$ORANGE"; label="DIRECT" ;;
    *)      color="$YELLOW"; label="MIXED/UNKNOWN" ;;
  esac

  local scol="$CYAN"
  if [ "$socks" = "OFF" ]; then scol="$RED"; fi
  if [ "$socks" = "MIXED" ]; then scol="$YELLOW"; fi

  echo -e "${color}${BOLD}MODE:${RESET} ${color}${label}${RESET}  |  ${BOLD}SOCKS:${RESET} ${scol}${socks}${RESET}"
}

# ---------- DOMAIN helpers ----------
domains_list_file_raw() {
  local f="$1"
  awk '
    BEGIN{inRule=0; brace=0; hasDom=0; inDom=0}
    function clean(s){
      gsub(/[",]/,"",s)
      sub(/^[ \t]+/,"",s)
      sub(/[ \t]+$/,"",s)
      return s
    }
    {
      line=$0
      if(line ~ /{[ \t]*$/){
        inRule=1; brace=1; hasDom=0; inDom=0
      } else if(inRule==1){
        if(index(line,"{")>0) brace++
        if(index(line,"}")>0) brace--
      }

      if(inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){
        hasDom=1; inDom=1
        next
      }

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
    BEGIN{inRule=0; brace=0; hasDom=0; inDom=0; dn=0; indent=""; targetDone=0;}
    function push_dom(s){ if(s=="") return; for(i=1;i<=dn;i++) if(dom[i]==s) return; dom[++dn]=s }
    function clean(s){ gsub(/[",]/,"",s); sub(/^[ \t]+/,"",s); sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
    function flush_domain_block(closeLine){
      if(ACTION=="add"){ push_dom(PARAM) }
      else if(ACTION=="del"){ k=PARAM+0; if(k>=1 && k<=dn){ for(i=k;i<dn;i++) dom[i]=dom[i+1]; dn-- } }
      else if(ACTION=="flush"){ dn=0; push_dom(PARAM) }
      # ACTION=="normalize" => just rewrite deduped list (push_dom already dedupe)
      if(indent=="") indent="          "
      for(i=1;i<=dn;i++){ if(i<dn) printf "%s\"%s\",\n", indent, dom[i]; else printf "%s\"%s\"\n", indent, dom[i] }
      print closeLine
      targetDone=1
    }
    {
      line=$0
      if(line ~ /{[ \t]*$/){ inRule=1; brace=1; hasDom=0; inDom=0; dn=0; indent="" }
      else if(inRule==1){ if(index(line,"{")>0) brace++; if(index(line,"}")>0) brace-- }

      if(targetDone==0 && inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){ hasDom=1; inDom=1; print line; next }

      if(targetDone==0 && inRule==1 && hasDom==1 && inDom==1){
        if(indent=="" && match(line,/^[ \t]*/)) indent=substr(line,RSTART,RLENGTH)
        if(line ~ /^[ \t]*][ \t]*,?[ \t]*$/){ closeLine=line; flush_domain_block(closeLine); inDom=0; next }
        if(line ~ /domain:/){ s=clean(line); push_dom(s) }
        next
      }

      print line
      if(inRule==1 && brace<=0){ inRule=0; brace=0; hasDom=0; inDom=0 }
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

build_global_domains() {
  local f d
  GLOBAL_DOMAINS=()
  declare -gA _SEEN=()
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || continue
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      if [ -z "${_SEEN[$d]+x}" ]; then
        _SEEN["$d"]=1
        GLOBAL_DOMAINS+=("$d")
      fi
    done < <(domains_list_file_raw "$f" || true)
  done
}

show_domains_all() {
  local idx=0 shown=0
  echo
  echo -e "${ORANGE}--------------------------------------${RESET}"
  echo -e " ${WHITE}${BOLD}Current Domains (ANCHOR RULE)${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"
  for f in "${CFG_LIST[@]}"; do
    idx=$((idx+1))
    [ -f "$f" ] || continue
    echo -e "${PINK}File #${idx}:${RESET} ${DIM}$(basename "$f")${RESET}"
    mapfile -t arr < <(domains_list_file_raw "$f" | sed '/^$/d' || true)
    if [ "${#arr[@]}" -eq 0 ]; then
      echo "  - (empty)"
    else
      local i
      for i in "${!arr[@]}"; do printf "  %2d) %s\n" $((i+1)) "${arr[$i]}"; done
    fi
    echo
    shown=1
  done
  [ "$shown" -eq 1 ] || echo -e "${YELLOW}No target file found.${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"
  echo
}

show_domains_global() {
  build_global_domains
  echo
  echo -e "${ORANGE}--------------------------------------${RESET}"
  echo -e " ${WHITE}${BOLD}Domains (GLOBAL LIST)${RESET}  ${DIM}- merged from all files, de-duplicated${RESET}"
  echo -e "${ORANGE}--------------------------------------${RESET}"
  if [ "${#GLOBAL_DOMAINS[@]}" -eq 0 ]; then
    echo "  - (empty)"
  else
    local i
    for i in "${!GLOBAL_DOMAINS[@]}"; do printf "  %2d) %s\n" $((i+1)) "${GLOBAL_DOMAINS[$i]}"; done
  fi
  echo -e "${ORANGE}--------------------------------------${RESET}"
  echo
}

# ---------- ACTIONS ----------
set_mode_all() {
  local mode="$1"
  local changed=0 skipped=0
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    awk -v MODE="$mode" '
      BEGIN{inRule=0; brace=0; hasDom=0; done=0}
      {
        line=$0
        if(line ~ /{[ \t]*$/){ inRule=1; brace=1; hasDom=0 }
        else if(inRule==1){ if(index(line,"{")>0) brace++; if(index(line,"}")>0) brace-- }
        if(done==0 && inRule==1 && line ~ /"domain"[ \t]*:[ \t]*\[/){ hasDom=1 }
        if(done==0 && inRule==1 && hasDom==1 && line ~ /"outboundTag"[ \t]*:/){ sub(/"(warp|direct)"/,"\""MODE"\"", line); done=1 }
        print line
        if(inRule==1 && brace<=0){ inRule=0; brace=0; hasDom=0 }
      }
    ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    changed=$((changed+1))
  done
  ok "Mode updated: $mode (changed=$changed, skipped=$skipped)"
}

# NEW: Add multiple domains (multi-line), optional restart
add_domain_all() {
  show_domains_global
  echo
  echo -e "${YELLOW}Masukkan domain banyak-banyak (1 baris 1 domain).${RESET}"
  echo -e "${YELLOW}Contoh:${RESET}"
  echo -e "  speedtest.net"
  echo -e "  fb.com"
  echo -e "  ig.com"
  echo -e "${YELLOW}Tekan ENTER kosong untuk tamat input.${RESET}"
  echo

  local input=()
  while true; do
    read -rp "> " line || true
    line="${line// /}"
    [ -z "$line" ] && break
    input+=("$line")
  done

  [ "${#input[@]}" -gt 0 ] || die "Tiada domain dimasukkan."

  # normalize + dedupe input
  local new_domains=()
  declare -A seen=()
  local d
  for d in "${input[@]}"; do
    d="${d// /}"
    [ -n "$d" ] || continue
    [[ "$d" != domain:* ]] && d="domain:$d"
    if [ -z "${seen[$d]+x}" ]; then
      seen["$d"]=1
      new_domains+=("$d")
    fi
  done

  [ "${#new_domains[@]}" -gt 0 ] || die "Tiada domain valid selepas normalize."

  local changed_files=0 skipped=0 total_added=0
  local f

  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }

    local need_backup=0
    for d in "${new_domains[@]}"; do
      if ! domains_list_file_raw "$f" | grep -qxF "$d"; then
        need_backup=1
        break
      fi
    done
    [ "$need_backup" -eq 1 ] || continue

    backup "$f"

    local added_here=0
    for d in "${new_domains[@]}"; do
      if domains_list_file_raw "$f" | grep -qxF "$d"; then
        continue
      fi
      apply_domains_file "$f" "add" "$d"
      added_here=$((added_here+1))
    done

    apply_domains_file "$f" "normalize" ""
    if [ "$added_here" -gt 0 ]; then
      changed_files=$((changed_files+1))
      total_added=$((total_added+added_here))
    fi
  done

  if [ "$total_added" -eq 0 ]; then
    info "Semua domain yang dimasukkan memang dah wujud. Tiada perubahan."
    return 0
  fi

  ok "Domain(s) added: $total_added item(s) (changed_files=$changed_files, skipped=$skipped)"
  echo -e "${CYAN}Added list:${RESET}"
  for d in "${new_domains[@]}"; do echo "  - $d"; done

  show_domains_all

  echo
  read -rp "Restart XRAY now? type YES: " ans
  [ "$ans" = "YES" ] && restart_xray_all
}

delete_domain_global_number() {
  show_domains_global
  build_global_domains
  [ "${#GLOBAL_DOMAINS[@]}" -gt 0 ] || die "GLOBAL domain list is empty."
  read -rp "Select domain number to delete (GLOBAL) 1..${#GLOBAL_DOMAINS[@]} (0 to cancel): " n
  [[ "$n" =~ ^[0-9]+$ ]] || die "Input must be a number."
  [ "$n" -eq 0 ] && return 0
  [ "$n" -ge 1 ] && [ "$n" -le "${#GLOBAL_DOMAINS[@]}" ] || die "Invalid number."
  local target="${GLOBAL_DOMAINS[$((n-1))]}"
  local changed=0 skipped=0
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    mapfile -t arr < <(domains_list_file_raw "$f" | sed '/^$/d' || true)
    local idx=-1 i
    for i in "${!arr[@]}"; do
      if [ "${arr[$i]}" = "$target" ]; then idx=$((i+1)); break; fi
    done
    [ "$idx" -eq -1 ] && continue
    backup "$f"
    apply_domains_file "$f" "del" "$idx"
    apply_domains_file "$f" "normalize" ""
    changed=$((changed+1))
  done
  ok "Domain removed (ALL files): $target (changed=$changed, skipped=$skipped)"
  show_domains_all
}

flush_domains_all() {
  echo -e "${YELLOW}NOTE:${RESET} Flush will NOT leave domain[] empty."
  echo -e "      It will keep a safe placeholder: ${PINK}${FLUSH_PLACEHOLDER}${RESET}"
  read -rp "CONFIRM flush (replace domain[] with placeholder in ALL files)? type YES: " ans
  [ "$ans" = "YES" ] || { info "Cancelled."; return 0; }
  local donec=0 skipped=0
  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }
    backup "$f"
    apply_domains_file "$f" "flush" "$FLUSH_PLACEHOLDER"
    donec=$((donec+1))
  done
  ok "Flush completed (placeholder kept) (changed=$donec, skipped=$skipped)"
  show_domains_all
}

restart_xray_all() {
  systemctl restart xray@config 2>/dev/null || true
  systemctl restart xray@none 2>/dev/null || true
  ok "Restarted all target services"
}

# NEW: Cleanup backup files (*.bak.*)
cleanup_backups_all() {
  local total=0
  echo
  echo -e "${YELLOW}NOTE:${RESET} Ini akan DELETE semua backup file (*.bak.*) untuk target dalam:"
  echo -e "      ${PINK}${XRAY_DIR}${RESET}"
  echo

  for f in "${CFG_LIST[@]}"; do
    local base c
    base="$(basename "$f")"
    c="$(find "$XRAY_DIR" -maxdepth 1 -type f -name "${base}.bak.*" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${c:-0}" -gt 0 ]; then
      echo -e "  ${PINK}${base}${RESET}: ${c} backup(s)"
      total=$((total + c))
    fi
  done

  if [ "$total" -eq 0 ]; then
    info "No backup files found."
    return 0
  fi

  echo
  echo -e "${RED}Total:${RESET} $total backup file(s) akan dipadam."
  read -rp "CONFIRM cleanup backup? type YES: " ans
  [ "$ans" = "YES" ] || { info "Cancelled."; return 0; }

  local deleted=0
  for f in "${CFG_LIST[@]}"; do
    local base
    base="$(basename "$f")"
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      rm -f -- "$b"
      deleted=$((deleted+1))
    done < <(find "$XRAY_DIR" -maxdepth 1 -type f -name "${base}.bak.*" 2>/dev/null)
  done

  ok "Backup cleanup done. Deleted=$deleted"
}

# NEW: Import domains from file, optional restart
import_domains_file_all() {
  local file=""
  echo
  echo -e "${YELLOW}Masukkan path file domain list (1 baris 1 domain).${RESET}"
  echo -e "${YELLOW}Contoh path:${RESET} /root/domainlist.txt"
  read -rp "File path [/root/domainlist.txt]: " file
  file="${file// /}"
  [ -z "$file" ] && file="/root/domainlist.txt"

  [ -f "$file" ] || die "File not found: $file"

  # read file, remove spaces, ignore blank & comments
  local raw=()
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"    # strip trailing comment
    line="${line// /}"    # strip spaces
    [ -z "$line" ] && continue
    raw+=("$line")
  done < "$file"

  [ "${#raw[@]}" -gt 0 ] || die "File kosong / tiada domain valid."

  # normalize + dedupe
  local new_domains=()
  declare -A seen=()
  local d
  for d in "${raw[@]}"; do
    [[ "$d" != domain:* ]] && d="domain:$d"
    if [ -z "${seen[$d]+x}" ]; then
      seen["$d"]=1
      new_domains+=("$d")
    fi
  done

  [ "${#new_domains[@]}" -gt 0 ] || die "Tiada domain valid selepas normalize."

  local changed_files=0 skipped=0 total_added=0
  local f

  for f in "${CFG_LIST[@]}"; do
    [ -f "$f" ] || { skipped=$((skipped+1)); continue; }

    local need_backup=0
    for d in "${new_domains[@]}"; do
      if ! domains_list_file_raw "$f" | grep -qxF "$d"; then
        need_backup=1
        break
      fi
    done
    [ "$need_backup" -eq 1 ] || continue

    backup "$f"

    local added_here=0
    for d in "${new_domains[@]}"; do
      if domains_list_file_raw "$f" | grep -qxF "$d"; then
        continue
      fi
      apply_domains_file "$f" "add" "$d"
      added_here=$((added_here+1))
    done

    apply_domains_file "$f" "normalize" ""
    if [ "$added_here" -gt 0 ]; then
      changed_files=$((changed_files+1))
      total_added=$((total_added+added_here))
    fi
  done

  if [ "$total_added" -eq 0 ]; then
    info "Import siap, tapi semua domain dalam file memang dah wujud. Tiada perubahan."
    return 0
  fi

  ok "Imported: $total_added domain(s) from: $file (changed_files=$changed_files, skipped=$skipped)"
  echo -e "${CYAN}Imported list:${RESET}"
  for d in "${new_domains[@]}"; do echo "  - $d"; done

  show_domains_all

  echo
  read -rp "Restart XRAY now? type YES: " ans
  [ "$ans" = "YES" ] && restart_xray_all
}

# ---------- MAIN ----------
need_targets

while true; do
  clear
  gm="$(get_global_mode)"
  case "$gm" in
    warp) BAR="$GREEN" ;;
    direct) BAR="$ORANGE" ;;
    *) BAR="$YELLOW" ;;
  esac

  echo -e "${BAR}======================================${RESET}"
  echo -e " ${WHITE}${BOLD}XRAY WARP / FREEDOM MENU${RESET}"
  echo -e "${BAR}======================================${RESET}"
  echo -e " ${WHITE}Targets :${RESET} ${PINK}${#CFG_LIST[@]} config(s)${RESET}"
  echo -e " ${WHITE}Status  :${RESET} $(status_line)"
  echo -e "${BAR}--------------------------------------${RESET}"

  echo -e " ${PINK}1)${RESET} Enable WARP (outboundTag -> WARP)"
  echo -e " ${PINK}2)${RESET} Set FREEDOM (outboundTag -> Direct/Freedom)"
  echo -e " ${PINK}3)${RESET} Add domain (bypass domain proxy) [MULTI]"
  echo -e " ${PINK}4)${RESET} Delete domain (delete domain proxy)"
  echo -e " ${PINK}5)${RESET} Flush domains (remove all domain)"
  echo -e " ${PINK}6)${RESET} Show domains (GLOBAL list)"
  echo -e " ${PINK}7)${RESET} Restart XRAY (target services)"
  echo -e " ${PINK}8)${RESET} Cleanup backup files (*.bak.*)"
  echo -e " ${PINK}9)${RESET} Import domains from file (/root/domainlist.txt)"
  echo -e " "
  echo -e " ${PINK}0)${RESET} Back to menu"
  echo -e ""
  echo -e "${BAR}--------------------------------------${RESET}"
  echo -e " ${YELLOW}Notes:${RESET}"
  echo -e " ${YELLOW}❇️ Please Enable Socks5 40000 at Cloudflare WARP+ before using this script.${RESET}"
  echo -e " ${YELLOW}❇️ Please Set Custom DNS 1.1.1.1 at MENU to avoid any problem. TQ.${RESET}"
  echo

  read -rp "Select: " c
  case "$c" in
    1) set_mode_all "warp" ;;
    2) set_mode_all "direct" ;;
    3) add_domain_all ;;
    4) delete_domain_global_number ;;
    5) flush_domains_all ;;
    6) show_domains_global; read -rp "Press Enter..." ;;
    7) restart_xray_all ;;
    8) cleanup_backups_all ;;
    9) import_domains_file_all ;;
    0) exec menu ;;
    *) info "Invalid option"; sleep 1 ;;
  esac
  read -rp "Press Enter to continue..."
done
