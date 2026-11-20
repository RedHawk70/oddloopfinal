#!/bin/bash
clear
IP=$(wget -qO- https://icanhazip.com) || exit 1
[[ "$IP" =~ ^[0-9a-fA-F:.]+$ ]] || { echo "IP VPS tidak sah." >&2; exit 1; }
date=$(date +"%Y-%m-%d")
email=$(cat /home/email)
umask 077
workdir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$workdir"' EXIT
cd "$workdir" || exit 1
mkdir backup || exit 1
echo Start Backup
cp -r /usr/local/etc/xray backup/xray || exit 1
if [[ -d /etc/xray/configlist ]]; then
    cp -r /etc/xray/configlist backup/configlist || exit 1
fi
# Panel guna IP VPS apabila fail domain tiada.
if [[ ! -s backup/xray/domain && "$IP" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
    printf '%s\n' "$IP" > backup/source-domain || exit 1
fi
cp /etc/passwd /etc/group /etc/shadow /etc/gshadow backup/ || exit 1
[[ ! -d /etc/wireguard ]] || cp -r /etc/wireguard backup/wireguard || exit 1
[[ ! -f /etc/shadowsocks-libev/akun.conf ]] || cp /etc/shadowsocks-libev/akun.conf backup/ss.conf || exit 1
[[ ! -d /var/lib/premium-script ]] || cp -r /var/lib/premium-script backup/premium-script || exit 1
[[ ! -d /etc/trojan-go ]] || cp -r /etc/trojan-go backup/trojan-go || exit 1
[[ ! -d /usr/local/shadowsocksr ]] || cp -r /usr/local/shadowsocksr backup/shadowsocksr || exit 1
[[ ! -f /etc/crontab ]] || cp /etc/crontab backup/crontab || exit 1
[[ ! -d /home/vps/public_html ]] || cp -r /home/vps/public_html backup/public_html || exit 1
zip -qr "$IP-$date.zip" backup || exit 1
rclone copy "$workdir/$IP-$date.zip" dr:backup/ || exit 1
url=$(rclone link "dr:backup/$IP-$date.zip") || exit 1
id=(`echo $url | grep '^https' | cut -d'=' -f2`)
link="https://drive.google.com/u/4/uc?id=${id}&export=download"
echo -e "The following is a link to your vps data backup file.

Your VPS IP $IP

$link

If you want to restore data, please enter the link above.

Thank You For Using Our Services" | mail -s "Backup Data" $email
echo Done
