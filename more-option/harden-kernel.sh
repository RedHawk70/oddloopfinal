#!/bin/bash
# ============================================
#  Kernel Hardening (sysctl) - untuk VPS Xray + SSH
#  Jalankan sebagai root:  sudo bash harden-kernel.sh
#  Created By NiL@NotionAI
# ============================================

set -e

CONF="/etc/sysctl.d/99-hardening.conf"

# --- Pastikan dijalankan sebagai root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Harap jalankan sebagai root (pakai sudo)."
  exit 1
fi

# --- Backup config lama kalau ada ---
if [ -f "$CONF" ]; then
  cp "$CONF" "${CONF}.bak.$(date +%Y%m%d%H%M%S)"
  echo "📦 Backup lama disimpan: ${CONF}.bak.*"
fi

# --- Tulis konfigurasi hardening ---
echo "📝 Menulis konfigurasi ke $CONF ..."
cat > "$CONF" <<'EOF'
# ================= KERNEL HARDENING =================

# --- Lawan SYN flood ---
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2

# --- Anti IP spoofing (reverse path filter) ---
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# --- Abaikan ICMP broadcast (cegah Smurf attack) ---
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# --- Jangan terima ICMP redirect (cegah MITM) ---
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# --- Jangan terima source routed packets ---
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# --- Log paket aneh (martian) ---
net.ipv4.conf.all.log_martians = 1

# --- Perbesar kapasitas koneksi (penting buat tunneling banyak user) ---
net.core.somaxconn = 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.core.netdev_max_backlog = 250000
EOF

# --- Terapkan langsung tanpa reboot ---
echo "⚙️  Menerapkan konfigurasi ..."
if sysctl -p "$CONF"; then
  echo ""
  echo "✅ Selesai! Kernel hardening berhasil diterapkan."
  echo "   File config: $CONF"
else
  echo ""
  echo "⚠️  Sebagian parameter mungkin gagal (tergantung kernel/OS provider)."
  echo "   Cek pesan di atas. Config tetap tersimpan di $CONF."
fi