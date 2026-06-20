#!/bin/bash
set -euo pipefail

# ====== settings ======
SYSCTL_DROPIN="/etc/sysctl.d/99-bbr-tuning.conf"
MODULES_CONF="/etc/modules-load.d/bbr.conf"
LIMITS_CONF="/etc/security/limits.conf"
BACKUP_DIR="/root/backup-bbr-$(date +%F_%H%M%S)"

GREEN="\e[0;32m"; RED="\e[1;31m"; YELLOW="\e[1;33m"; NC="\e[0m"

log()   { echo -e "${GREEN}$*${NC}"; }
warn()  { echo -e "${YELLOW}$*${NC}"; }
err()   { echo -e "${RED}$*${NC}"; }

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    err "Run sebagai root (sudo -i)."
    exit 1
  fi
}

backup_files() {
  mkdir -p "$BACKUP_DIR"
  for f in "$SYSCTL_DROPIN" "$MODULES_CONF" "$LIMITS_CONF" "/etc/sysctl.conf"; do
    [[ -f "$f" ]] && cp -a "$f" "$BACKUP_DIR"/
  done
  log "Backup disimpan di: $BACKUP_DIR"
}

ensure_file() {
  local f="$1"
  mkdir -p "$(dirname "$f")"
  [[ -f "$f" ]] || : > "$f"
}

ensure_line() {
  local file="$1" line="$2"
  ensure_file "$file"
  if ! grep -Fxq -- "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

set_sysctl_kv() {
  local file="$1" key="$2" value="$3"
  ensure_file "$file"
  if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|g" "$file"
  else
    echo "${key} = ${value}" >> "$file"
  fi
}

install_bbr() {
  echo -e "\n${GREEN}================================${NC}"
  log "Setup TCP BBR..."

  if modprobe tcp_bbr 2>/dev/null; then
    ensure_line "$MODULES_CONF" "tcp_bbr"
  else
    warn "modprobe tcp_bbr gagal (mungkin kernel tak ada module tcp_bbr). Teruskan check sysctl..."
  fi

  local avail
  avail="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
  if ! grep -qw "bbr" <<<"$avail"; then
    err "BBR tak tersedia dalam kernel. tcp_available_congestion_control: ${avail:-<empty>}"
    err "Solusi: update kernel ke versi yang support BBR."
    return 1
  fi

  set_sysctl_kv "$SYSCTL_DROPIN" "net.core.default_qdisc" "fq"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_congestion_control" "bbr"

  sysctl --system >/dev/null

  local cc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)"
  if [[ "$cc" == "bbr" ]]; then
    log "TCP BBR aktif. (tcp_congestion_control=$cc)"
  else
    err "BBR masih belum aktif. (tcp_congestion_control=$cc)"
    return 1
  fi

  echo -e "${GREEN}================================${NC}"
}

optimize_parameters() {
  echo -e "\n${GREEN}================================${NC}"
  log "Optimasi parameters..."

  ensure_line "$LIMITS_CONF" "* soft nofile 51200"
  ensure_line "$LIMITS_CONF" "* hard nofile 51200"
  ensure_line "$LIMITS_CONF" "root soft nofile 51200"
  ensure_line "$LIMITS_CONF" "root hard nofile 51200"

  set_sysctl_kv "$SYSCTL_DROPIN" "fs.file-max" "51200"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.core.rmem_max" "67108864"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.core.wmem_max" "67108864"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.core.netdev_max_backlog" "250000"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.core.somaxconn" "4096"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_syncookies" "1"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_tw_reuse" "1"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_fin_timeout" "30"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_keepalive_time" "1200"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.ip_local_port_range" "10000 65000"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_max_syn_backlog" "8192"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_max_tw_buckets" "5000"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_fastopen" "3"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_mem" "25600 51200 102400"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_rmem" "4096 87380 67108864"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_wmem" "4096 65536 67108864"
  set_sysctl_kv "$SYSCTL_DROPIN" "net.ipv4.tcp_mtu_probing" "1"

  sysctl --system >/dev/null
  log "Optimize siap. (sysctl drop-in: $SYSCTL_DROPIN)"
  echo -e "${GREEN}================================${NC}"
}

verify() {
  echo -e "\n${GREEN}===== Verify =====${NC}"
  sysctl net.core.default_qdisc net.ipv4.tcp_congestion_control net.ipv4.tcp_available_congestion_control | sed 's/^/  /'
  lsmod | grep -E 'tcp_bbr|bbr' || true
}

main() {
  need_root
  backup_files
  install_bbr
  optimize_parameters
  verify

  # self-delete (ON)
  rm -f "$0"
}

main "$@"
