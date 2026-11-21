#!/bin/bash
# // wget https://github.com/${GitUser}/
GitUser="RedHawk70"

cert_dir=/usr/local/etc/xray

# Fail domain kosong atau alamat IPv4 memilih mod alamat IP.
ipv4_pattern='^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])[.]){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$'
domain=""
configured_ip=""
if [[ -f /root/domain ]]; then
  domain=$(< /root/domain)
elif [[ -f "$cert_dir/domain" ]]; then
  domain=$(< "$cert_dir/domain")
fi
domain="${domain//[[:space:]]/}"
if [[ "$domain" =~ $ipv4_pattern ]]; then
  configured_ip="$domain"
  domain=""
fi

set -Eeuo pipefail

# ------------------------- TETAPAN ----------------------------
FORK_URL="${FORK_URL:-https://github.com/RedHawk70/xraycore/releases/download/xrmodv26.2.6-1/Xray-linux-64-v26.2.6-1}"
BIN="${BIN:-/usr/local/bin/xray}"
BAK="${BAK:-/usr/local/bin/xray.bakk}"
INSTALLER_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"

red=$'\033[31m'; grn=$'\033[32m'; cyn=$'\033[36m'; rst=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "$cyn" "$*" "$rst"; }
ok()   { printf '%s  [OK] %s%s\n' "$grn" "$*" "$rst"; }
warn() { printf '\033[33m  [!] %s%s\n' "$*" "$rst"; }
die()  { printf '%s  [X] %s%s\n' "$red" "$*" "$rst" >&2; exit 1; }

TMP="$(mktemp -d)"
nginx_stopped=false
none_stopped=false
cleanup() {
  if "$none_stopped"; then
    systemctl start xray@none.service || warn "Xray port 80 gagal dihidupkan semula."
  fi
  if "$nginx_stopped"; then
    systemctl start nginx || warn "Nginx gagal dihidupkan semula."
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

# --------------------- SEMAKAN AWAL ---------------------------
step "Semakan awal"
[[ "${EUID}" -eq 0 ]] || die "Kena jalan sebagai root. Guna: sudo bash $0"
[[ "$(uname -s)" == "Linux" ]] || die "Skrip ni untuk Linux sahaja."
case "$(uname -m)" in
  x86_64 | amd64) ;;
  *) die "Aset fork ni untuk x86_64/amd64 sahaja, bukan $(uname -m). Cari aset lain di https://github.com/RedHawk70/xraycore/releases" ;;
esac
systemctl list-units >/dev/null || die "Systemd perlu berjalan untuk pemasangan ini."
ok "root, Linux $(uname -m), systemd tersedia"

# Simpan nama domain sahaja supaya menu tidak memaparkan IP sebagai domain.
save_domain_metadata() {
  mkdir -p "$cert_dir" /etc/xray
  printf '%s\n' "$domain" > "$cert_dir/domain"
  install -m 0644 "$cert_dir/domain" /etc/xray/domain
}

if [[ "${1:-}" == "--refresh-domain-metadata" ]]; then
  save_domain_metadata
  ok "Maklumat domain dikemas kini."
  exit 0
fi

# ------------------------ ROLLBACK ----------------------------
if [[ "${1:-}" == "--rollback" ]]; then
  step "Rollback ke binari asal"
  [[ -f "$BAK" ]] || die "Tiada backup di $BAK — tak boleh rollback."
  install -m 0755 -o root -g root "$BAK" "$BIN"
  for unit in xray.service xray@config.service xray@none.service; do
    if systemctl is-active --quiet "$unit"; then
      systemctl restart "$unit" || die "Gagal restart $unit selepas rollback."
    fi
  done
  ok "Dah pulih ke $BAK — $("$BIN" version 2>/dev/null | head -n1)"
  exit 0
fi

apt-get install iptables iptables-persistent -y
apt-get install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release openssl acl -y
# Gunakan chrony untuk penyelarasan masa, termasuk pada Debian 13.
apt-get install -y cron bash-completion chrony
systemctl enable --now chrony.service
timedatectl set-timezone Asia/Kuala_Lumpur

# // MAKE FILE TROJAN TCP
mkdir -p /etc/xray
mkdir -p /usr/local/etc/xray/
mkdir -p /var/log/xray
touch /usr/local/etc/xray/akunxtr.conf
touch /var/log/xray/access.log /var/log/xray/error.log

# ---------------- 1. ASAS: SERVICE + CONFIG + GEODATA ---------
step "Pasang asas Xray (servis systemd, config, geodata)"
if [[ -x "$BIN" ]] && [[ -f /etc/systemd/system/xray.service && -f /etc/systemd/system/xray@.service ]]; then
  ok "Asas dah wujud — langkau langkah ni."
else
  # NOTA: JANGAN guna '-u www-data'. Flag tu dah DIBUANG dari skrip rasmi
  # (commit 1142d3d, 2026-10-18). Skrip sekarang auto-cipta user 'xray'.
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 \
    -o "$TMP/install-release.sh" "$INSTALLER_URL" \
    || die "Gagal muat turun install-release.sh — semak internet/DNS VPS."

  grep -q 'judgment_parameters' "$TMP/install-release.sh" \
    || die "Skrip install tak lengkap (mungkin dapat halaman HTML ralat)."

  bash "$TMP/install-release.sh" install \
    || die "Pemasangan asas gagal. Baca ralat di atas (selalunya DNS, tiada systemd, atau bukan root)."
  ok "Asas siap dipasang."
fi

# ------------------- 2. MUAT TURUN BINARI ---------------------
step "Muat turun binari fork"
NEW="$TMP/xray.new"
curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 --progress-bar \
  -o "$NEW" "$FORK_URL" \
  || die "Muat turun gagal (404 / TLS / rangkaian). Uji: curl -I \"$FORK_URL\""

size=$(stat -c '%s' "$NEW" 2>/dev/null || echo 0)
(( size > 5000000 )) || die "Fail terlalu kecil (${size} bait) — itu bukan binari, mungkin halaman ralat."

magic=$(head -c 4 "$NEW" | od -An -tx1 | tr -d ' \n')
[[ "$magic" == "7f454c46" ]] || die "Bukan binari ELF (magic: $magic)."

chmod 0755 "$NEW"
"$NEW" version >/dev/null 2>&1 \
  || die "Binari tak boleh jalan pada CPU/kernel ni (glibc terlalu lama?)."
ok "Binari sah: $("$NEW" version 2>/dev/null | head -n1)"

# ------------------- 3. BACKUP + TUKAR ------------------------
step "Backup & ganti binari"
if [[ -f "$BIN" ]]; then
  if [[ ! -f "$BAK" ]]; then
    cp -a "$BIN" "$BAK"
    ok "Backup binari asal: $BAK"
  else
    ok "Backup sedia ada dikekalkan: $BAK"
  fi
else
  warn "Tiada binari lama untuk dibackup."
fi

install -m 0755 -o root -g root "$NEW" "$BIN"

if ! "$BIN" version >/dev/null 2>&1; then
  if [[ -f "$BAK" ]]; then
    install -m 0755 -o root -g root "$BAK" "$BIN"
    die "Binari fork gagal jalan — dah auto-rollback ke backup."
  fi
  die "Binari fork gagal jalan dan tiada backup."
fi
ok "Terpasang: $("$BIN" version 2>/dev/null | head -n1)"

# // INSTALL CERTIFICATES
step "Sediakan sijil TLS"
endpoint="$domain"
if [[ -n "$domain" ]]; then
  if systemctl is-active --quiet nginx; then
    systemctl stop nginx
    nginx_stopped=true
  fi
  if systemctl is-active --quiet xray@none.service; then
    systemctl stop xray@none.service
    none_stopped=true
  fi
  install -d -m 0700 /root/.acme.sh
  acme=/root/.acme.sh/acme.sh
  curl -fsSL https://raw.githubusercontent.com/NiL070/oddloop/main/acme.sh -o "$acme"
  chmod +x "$acme"
  "$acme" --upgrade --auto-upgrade
  "$acme" --set-default-ca --server letsencrypt
  issue_status=0
  "$acme" --issue -d "$domain" -d "sshws.$domain" --standalone -k ec-256 --listen-v6 || issue_status=$?
  # Kod 2 bermakna acme.sh melangkau pengeluaran sijil yang masih sah.
  (( issue_status == 0 || issue_status == 2 )) || die "ACME gagal untuk $domain."
  "$acme" --installcert -d "$domain" -d "sshws.$domain" \
    --fullchainpath "$cert_dir/xray.crt" --keypath "$cert_dir/xray.key" --ecc
else
  endpoint="$configured_ip"
  if [[ -z "$endpoint" ]]; then
    endpoint=$(curl -4fsS --connect-timeout 5 --max-time 10 https://ipv4.icanhazip.com || true)
  fi
  if ! [[ "$endpoint" =~ $ipv4_pattern ]]; then
    endpoint=127.0.0.1
    warn "IPv4 awam tidak dapat dikesan. Sijil TLS akan menggunakan $endpoint."
  fi
  if ! openssl x509 -in "$cert_dir/xray.crt" -noout -checkend 86400 >/dev/null 2>&1 ||
     ! openssl verify -partial_chain -trusted "$cert_dir/xray.crt" -verify_ip "$endpoint" \
       "$cert_dir/xray.crt" >/dev/null 2>&1 ||
     ! cmp -s <(openssl x509 -in "$cert_dir/xray.crt" -pubkey -noout) \
       <(openssl pkey -in "$cert_dir/xray.key" -pubout -passin pass: 2>/dev/null); then
    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -x509 \
      -days 365 -subj "/CN=$endpoint" -addext "subjectAltName=IP:$endpoint" \
      -keyout "$TMP/xray.key" -out "$TMP/xray.crt" || die "Gagal menjana sijil TLS untuk $endpoint."
    install -m 0600 "$TMP/xray.key" "$cert_dir/xray.key"
    install -m 0644 "$TMP/xray.crt" "$cert_dir/xray.crt"
  fi
  warn "TLS mod IP menggunakan sijil tandatangan sendiri. Percayai sijil ini pada klien."
fi
chmod 0600 "$cert_dir/xray.key"

if "$nginx_stopped"; then
  systemctl start nginx
  nginx_stopped=false
fi
if [[ "$(systemctl show -p LoadState --value squid.service)" == loaded ]]; then
  systemctl start squid.service
fi

# Jana kelayakan unik untuk konfigurasi baharu.
uuid=$(cat /proc/sys/kernel/random/uuid)

# // JSON WS & TCP XTLS
cat > "$TMP/config.json" << END
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085, # CEK USER QUOTA
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
      "port": 443,
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "flow": "xtls-rprx-vision",
            "level": 0
#xray-vless-xtls-rprx-vision
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "path": "/vless", # // VLESS WS TLS
            "dest": 1212,
            "xver": 1
          },
          {
            "path": "/httpupgrade", # // HTTPUPGRADE TLS
            "dest": 1213,
            "xver": 1
          },
          {
            "path": "/vmess", # // VMESS WS TLS
            "dest": 1214,
            "xver": 1
          },
          {
            "dest": 1216
          },
          {
            "path": "/trojanwstls", # // TROJAN WS TLS
            "dest": 1215,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": [
            "h2",
            "http/1.1"
          ],
          "certificates": [
            {
              "certificateFile": "/usr/local/etc/xray/xray.crt",
              "keyFile": "/usr/local/etc/xray/xray.key"
            }
          ],
          "minVersion": "1.2"
        }
      }
    },
    {
      "port": 1212,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "level": 0
#xray-vless-tls
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vless"
        }
      }
    },
    {
      "port": 1214,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0,
            "level": 0
#xray-vmess-tls
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vmess"
        }
      }
    },
    {
      "port": 1215,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "password": "$uuid"
#xray-trojan-tls
          }
        ],
        "udp": true
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojanwstls"
        }
      }
    },
    {
      "port": 1213,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "level": 0
#httpupgrade-tls
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "httpupgrade",
        "security": "none",
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/httpupgrade"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 1216,
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid"
#xray-vless-xhttp-tls
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "/xhttp",
          "headers": {},
          "mode": "auto",
          "noSSEHeader": false,
          "scMaxEachPostBytes": "500000-1000000",
          "scMinPostsIntervalMs": "10-50",
          "scMaxBufferedPosts": 30
        }
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "user": [
          "regexp:^blocked-"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },

      /* ===== DOMAIN WARP (MUDAH BUANG) ===== */
      {
        "type": "field",
        "domain": [
          "domain:example.net"
        ],
        "outboundTag": "direct"
      }
    ]
  },

  "stats": {},

  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },

  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },

  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "socks",
      "tag": "warp",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": 40000
          }
        ]
      }
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "api"
    }
  ]
}
END

# // JSON WS NONE
cat > "$TMP/none.json" << END
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10086, # CEK USER QUOTA
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
      "listen": "0.0.0.0",
      "port": 80,
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "path": "/httpupgrade", # // HTTPUPGRADE NONE
            "dest": 1302,
            "xver": 1
          },
          {
            "path": "/vmess", # // VMESS NONE
            "dest": 1303,
            "xver": 1
          },
          {
            "path": "/trojanwsntls", # // TROJAN NONE
            "dest": 1304,
            "xver": 1
          },
          {
            "dest": 1305 # // XHTTP NONE
          },
          {
            "path": "/vless", # // VLESS NONE          
            "dest": 1301,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 1301,
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "$uuid"
#xray-vless-nontls
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vless"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 1302,
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "$uuid",
            "level": 0
#httpupgrade-nontls
          }
        ]
      },
      "streamSettings": {
        "network": "httpupgrade",
        "security": "none",
        "httpupgradeSettings": {
          "acceptProxyProtocol": true,
          "path": "/httpupgrade"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 1303,
      "protocol": "vmess",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "alterId": 0
#xray-vmess-nontls
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/vmess"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 1304,
      "protocol": "trojan",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "password": "$uuid"
#xray-trojan-nontls
          }
        ],
        "udp": true
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "acceptProxyProtocol": true,
          "path": "/trojanwsntls"
        }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 1305,
      "protocol": "vless",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      },
      "settings": {
        "clients": [
          {
            "id": "$uuid"
#xray-vless-xhttp-nontls
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "/xhttp",
          "headers": {},
          "scMaxBufferedPosts": 20,
          "scMaxEachPostBytes": 800000,
          "noSSEHeader": false,
          "xPaddingBytes": "100-1000",
          "mode": "auto"
        }
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "user": [
          "regexp:^blocked-"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "inboundTag": ["api"],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "protocol": ["bittorrent"],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },

      /* ===== DOMAIN WARP (MUDAH BUANG) ===== */
      {
        "type": "field",
        "domain": [
          "domain:example.net"
        ],
        "outboundTag": "direct"
      }
    ]
  },

  "stats": {},

  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },

  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },

  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "socks",
      "tag": "warp",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": 40000
          }
        ]
      }
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "api"
    }
  ]
}
END

# Kekalkan konfigurasi yang sudah digunakan oleh menu pengurusan akaun.
for profile in config none; do
  config_path="$cert_dir/$profile.json"
  candidate="$TMP/$profile.json"
  if [[ -f "$config_path" ]] && grep -Eq '^#(xray-|httpupgrade-)' "$config_path"; then
    candidate="$config_path"
  fi
  "$BIN" run -test -config "$candidate" || die "Konfigurasi $profile gagal disahkan."
  if [[ "$candidate" != "$config_path" ]]; then
    install -m 0644 "$candidate" "$config_path"
  fi
done

# Benarkan port asal sekali bagi setiap protokol.
for protocol in tcp udp; do
  for port in 443 8443 80 8080 8880; do
    rule=(-m state --state NEW -p "$protocol" --dport "$port" -j ACCEPT)
    iptables -C INPUT "${rule[@]}" 2>/dev/null || iptables -I INPUT "${rule[@]}"
  done
done

# addons open port tls & ntls #NiLphreakz@CreditToNevermoreSSH
iptables -t nat -C PREROUTING -p tcp -m multiport --dports 8443,2083,2096 -j REDIRECT --to-ports 443 2>/dev/null || \
iptables -t nat -A PREROUTING -p tcp -m multiport --dports 8443,2083,2096 -j REDIRECT --to-ports 443

iptables -t nat -C PREROUTING -p tcp -m multiport --dports 8080,2052,2082,2095 -j REDIRECT --to-ports 80 2>/dev/null || \
iptables -t nat -A PREROUTING -p tcp -m multiport --dports 8080,2052,2082,2095 -j REDIRECT --to-ports 80
# save rules
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules

netfilter-persistent save
netfilter-persistent reload
sleep 1

# Jalankan satu unit bagi setiap konfigurasi untuk mengelakkan konflik port.
systemctl daemon-reload
systemctl disable --now xray.service
for profile in config none; do
  unit="xray@$profile.service"
  service_user=$(systemctl show -p User --value "$unit")
  if [[ -n "$service_user" && "$service_user" != root ]]; then
    setfacl -m "u:$service_user:r" "$cert_dir/$profile.json"
    setfacl -m "u:$service_user:rw" /var/log/xray/access.log /var/log/xray/error.log
    if [[ "$profile" == config ]]; then
      setfacl -m "u:$service_user:r" "$cert_dir/xray.key"
    fi
  fi
  systemctl enable "$unit"
  systemctl restart "$unit" || die "$unit gagal dimulakan. Semak journalctl -u $unit."
done
none_stopped=false
sleep 1
for unit in xray@config.service xray@none.service; do
  systemctl is-active --quiet "$unit" || die "$unit tidak aktif. Semak journalctl -u $unit."
done

save_domain_metadata

# download script
cd /usr/bin
wget -O port-xray "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/change-port/port-xray2.sh"
wget -O certv2ray "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/cert.sh"
wget -O trojaan "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/menu/trojaan2.sh"
wget -O xraay "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/menu/xraay2.sh"
chmod +x port-xray
chmod +x certv2ray
chmod +x trojaan
chmod +x xraay

ok "Xray aktif pada $endpoint melalui xray@config dan xray@none."
