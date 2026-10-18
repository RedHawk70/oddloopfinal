#!/bin/bash
# Delete Expired SSH Account

clear
hariini=$(date +%d-%m-%Y)
SHADOW_FILE="${SHADOW_FILE:-/etc/shadow}"
LOG_DIR="${LOG_DIR:-/usr/local/bin}"

echo "Thank you for removing the EXPIRED USERS"
echo "--------------------------------------"

# Ambil user yang mempunyai expiry (medan 8 /etc/shadow)
awk -F: '$8 != "" {print $1":"$8}' "$SHADOW_FILE" > /tmp/expirelist.txt
totalaccounts=$(wc -l < /tmp/expirelist.txt)

for ((i=1; i<=totalaccounts; i++)); do
    tuserval=$(sed -n "${i}p" /tmp/expirelist.txt)
    [ -z "$tuserval" ] && continue

    username=${tuserval%%:*}
    userexp=${tuserval##*:}

    # Pastikan expiry ialah nombor
    [[ "$userexp" =~ ^[0-9]+$ ]] || continue

    # Hanya user biasa (UID >= 1000), bukan root dan bukan user semasa
    uid=$(getent passwd "$username" | cut -d: -f3)
    [ -z "$uid" ] && continue
    [ "$uid" -lt 1000 ] && continue
    [ "$username" = "$(id -un)" ] && continue

    userexpireinseconds=$(( userexp * 86400 ))
    tgl=$(date -d "@$userexpireinseconds" +"%d %b %Y")

    echo "Expired- User : $username Expire at : $tgl" >> "$LOG_DIR/alluser"

    todaystime=$(date +%s)
    if [ "$userexpireinseconds" -lt "$todaystime" ]; then

        # Hentikan semua proses user sebelum userdel
        pkill -TERM -u "$username" 2>/dev/null
        sleep 1
        pkill -KILL -u "$username" 2>/dev/null
        sleep 1

        if userdel -r "$username" 2>/tmp/userdel_err; then
            echo "Expired- Username : $username are expired at: $tgl and removed : $hariini" >> "$LOG_DIR/deleteduser"
            echo "Username $username that are expired at $tgl removed from the VPS $hariini"
        else
            echo "Gagal padam $username: $(cat /tmp/userdel_err)"
        fi
    fi
done

echo " "
echo "--------------------------------------"
echo "Script are successfully run"
