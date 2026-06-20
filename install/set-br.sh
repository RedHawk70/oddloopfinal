#!/bin/bash

GitUser="RedHawk70"
#curl https://rclone.org/install.sh | bash
# rclone v2
#wget https://rclone.org/install.sh
#chmod +x install.sh
#./install.sh
#printf "q\n" | rclone config

# rclone v3
#wget https://raw.githubusercontent.com/JebonRX/test/main/setup/rclone-v1.72.1-linux-amd64.zip
cd /root
LATEST=$(curl -s https://api.github.com/repos/rclone/rclone/releases/latest | grep tag_name | cut -d '"' -f4)
wget -O rclone.zip https://github.com/rclone/rclone/releases/download/${LATEST}/rclone-${LATEST}-linux-amd64.zip
unzip -o rclone.zip
cd rclone-${LATEST}-linux-amd64
cp rclone /usr/local/bin/
chmod 755 /usr/local/bin/rclone
rclone version
sleep 5

#wget -O /root/.config/rclone/rclone.conf "https://raw.githubusercontent.com/JebonRX/test/main/others/rclone.conf"
#git clone  https://github.com/MrMan21/wondershaper.git &> /dev/null
#cd wondershaper
#make install

# wonder v2
git clone https://github.com/MrMan21/wondershaper.git
cd wondershaper
chmod +x wondershaper
cp wondershaper /usr/local/bin/
cd
rm -rf wondershaper
cd /usr/bin
wget -O autobackup "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/system/autobackup.sh"
wget -O backup "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/system/backup.sh"
wget -O bckp "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/system/bckp.sh"
wget -O restore "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/system/restore.sh"
#wget -O strt "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/system/strt.sh"
wget -O limit-speed "https://raw.githubusercontent.com/${GitUser}/oddloopfinal/main/limit-speed.sh"
chmod +x autobackup
chmod +x backup
chmod +x bckp
chmod +x restore
#chmod +x strt
chmod +x limit-speed
chmod +x clear-log

# custom rclone
cat <<EOF > /root/.config/rclone/rclone.conf
[dr]
type = drive
scope = drive
token = {"access_token":"ya29.a0AeXRPp58FAmmDygCAB20FbnpfpZRiv72T5k8_enesoV0l4rtv0u7Fgcr3nAoSupzGm9hT-lzDzDy3LT1LhHR9Z71IrlqBD38BnryhDMQfVNfi3eYvtzxDoDIvJ_XU9ugOOF_JlkzfhLLFPNQVqQvBTZv3n4uTkThae8i_qBgaCgYKAUoSARASFQHGX2MiB3or38tOJH09P5rlrHqOQQ0175","token_type":"Bearer","refresh_token":"1//0gjYDcteseoaHCgYIARAAGBASNwF-L9Iro5DIXkhT28BQePyJiKkR-qIr4hLFnkCEpEO6pNbUwHgHhnoOK62IYo6oEwxUueQufvI","expiry":"2025-03-16T23:49:24.3586405+08:00"}
EOF


# install speedtest ookla latest
# 1️⃣ Update package list
#apt-get update

# 2️⃣ Pasang curl kalau belum ada
#apt-get install curl -y

# 3️⃣ Tambah repository rasmi Ookla
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash

# 4️⃣ Pasang Speedtest CLI
apt-get install speedtest -y

# 5️⃣ Jalankan ujian speed
#speedtest

#Buat script helper systemd
cat <<'EOF' > /usr/local/bin/limit-speed-apply.sh
#!/bin/bash
LIMIT_FILE="/home/limit"

if [[ -f "$LIMIT_FILE" ]] && [[ -s "$LIMIT_FILE" ]]; then
    read NIC DOWN UP < "$LIMIT_FILE"
    wondershaper -c -a "$NIC" 2>/dev/null
    wondershaper -a "$NIC" -d $((DOWN*1000)) -u $((UP*1000))
fi
EOF

chmod +x /usr/local/bin/limit-speed-apply.sh


#Buat systemd service untuk auto-apply limit saat boot
cat <<EOF > /etc/systemd/system/limit-speed.service
[Unit]
Description=Apply bandwidth limit with wondershaper
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/limit-speed-apply.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# start limit speed boot
systemctl daemon-reload
systemctl start limit-speed.service
#systemctl status limit-speed.service
systemctl enable limit-speed.service

#AUTO CLEAR LOG VPS EVERY 5 HOURS
tee /etc/systemd/system/clear-log.service > /dev/null <<'EOF'
[Unit]
Description=Run clear-log script

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/bin/clear-log
EOF

#systemd timer (setiap 5 jam)
tee /etc/systemd/system/clear-log.timer > /dev/null <<'EOF'
[Unit]
Description=Run clear-log every 5 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=5h
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload & enable timer
systemctl daemon-reload
systemctl enable --now clear-log.timer

#done
rm -r set-br.sh
rm -r rclone.zip
sleep 1
