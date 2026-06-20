#!/bin/bash
# // wget https://github.com/${GitUser}/
GitUser="RedHawk70"

# // MY IPVPS
export MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -s ipinfo.io/ip )
MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -sS ifconfig.me )

# // install socat
apt install socat

# // EMAIL & DOMAIN
export emailcf=$(cat /usr/local/etc/xray/email)
export domain=$(cat /root/domain)

apt install iptables iptables-persistent -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y 
apt install socat cron bash-completion ntpdate -y
ntpdate pool.ntp.org
apt -y install chrony
timedatectl set-ntp true
systemctl enable chronyd && systemctl restart chronyd
systemctl enable chrony && systemctl restart chrony
timedatectl set-timezone Asia/Kuala_Lumpur
chronyc sourcestats -v
chronyc tracking -v
date

# // MAKE FILE TROJAN TCP
mkdir -p /etc/xray
mkdir -p /usr/local/etc/xray/
mkdir -p /var/log/xray/;
touch /usr/local/etc/xray/akunxtr.conf
touch /var/log/xray/access.log;
touch /var/log/xray/error.log;

# // VERSION XRAY
export version="$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"

# // INSTALL CORE XRAY (LATEST)
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data

systemctl stop nginx

# // INSTALL CERTIFICATES
mkdir /root/.acme.sh
curl https://raw.githubusercontent.com/NiL070/oddloop/main/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain -d sshws.$domain --standalone -k ec-256 --listen-v6
~/.acme.sh/acme.sh --installcert -d $domain -d sshws.$domain --fullchainpath /usr/local/etc/xray/xray.crt --keypath /usr/local/etc/xray/xray.key --ecc
chmod 755 /usr/local/etc/xray/xray.key;
service squid start
systemctl restart nginx
sleep 0.5;
clear;

# // UUID PATH
export uuid=$(cat /proc/sys/kernel/random/uuid)
export uuid1=$(cat /proc/sys/kernel/random/uuid)
export uuid2=$(cat /proc/sys/kernel/random/uuid)
export uuid3=$(cat /proc/sys/kernel/random/uuid)
export uuid4=$(cat /proc/sys/kernel/random/uuid)
export uuid5=$(cat /proc/sys/kernel/random/uuid)
export uuid6=$(cat /proc/sys/kernel/random/uuid)
export uuid7=$(cat /proc/sys/kernel/random/uuid)
export uuid8=$(cat /proc/sys/kernel/random/uuid)

# // JSON WS & TCP XTLS
cat > /usr/local/etc/xray/config.json << END
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942",
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942",
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942",
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
      "settings": {
        "clients": [
          {
            "password": "f08617ab-98df-4046-b4a0-9266c2d6c942"
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942",
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942"
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
cat > /usr/local/etc/xray/none.json << END
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942"
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
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942"
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
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942",
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942",
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
      "settings": {
        "clients": [
          {
            "password": "f08617ab-98df-4046-b4a0-9266c2d6c942"
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
      "settings": {
        "clients": [
          {
            "id": "f08617ab-98df-4046-b4a0-9266c2d6c942"
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

# // IPTABLE TCP 
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8080 -j ACCEPT
iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport 8880 -j ACCEPT


# // IPTABLE UDP
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8443 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 80 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8080 -j ACCEPT
iptables -I INPUT -m state --state NEW -m udp -p udp --dport 8880 -j ACCEPT
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# // ENABLE XRAY TCP XTLS 80/443
systemctl daemon-reload
systemctl enable xray.service
systemctl restart xray.service
systemctl enable xray@none
systemctl restart xray@none

# // ENABLE XRAY WS TLS && NONE TLS
systemctl enable xray@config
systemctl restart xray@config

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

# // Install XrayCore Mod V.25.10.15 (Custompath)
mv /usr/local/bin/xray /usr/local/bin/xray.bakk && wget -q -O /usr/local/bin/xray "https://github.com/howitzer07/xraycore/releases/download/v25.10.15/xray-linux-amd64" && chmod 755 /usr/local/bin/xray

cd
rm -f ins-xray.sh
mv /root/domain /usr/local/etc/xray/domain
cp /usr/local/etc/xray/domain /etc/xray/domain
sleep 1
clear;
