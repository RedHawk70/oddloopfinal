#!/bin/bash
# Created by NiLphreakz
#wget https://github.com/${GitUser}/
GitUser="RedHawk70"

# IZIN SCRIPT
MYIP=$(curl -sS ipv4.icanhazip.com)

clear

if [ -f /etc/debian_version ]; then
    UIDN=1000
elif [ -f /etc/redhat-release ]; then
    UIDN=500
else
    UIDN=500
fi

clear
echo " "
echo " "
echo "==========================================="
echo " "
echo "-----------------------------------"
echo "        USER ACCOUNTS LIST         "
echo "-----------------------------------"
echo "[USERNAME]   -   [DATE EXPIRED]"
echo " "

while IFS=: read -r AKUN x ID GID GECOS HOME SHELL
do
    if [[ "$ID" -ge "$UIDN" && "$AKUN" != "nobody" && "$AKUN" != "debian" && "$AKUN" != "ubuntu" && "$SHELL" == "/bin/false" ]]; then
        exp="$(chage -l "$AKUN" | grep "Account expires" | awk -F": " '{print $2}')"
        printf "%-17s %2s\n" "$AKUN" "$exp"
    fi
done < /etc/passwd

JUMLAH="$(awk -F: -v uid="$UIDN" '$3 >= uid && $1 != "nobody" && $1 != "debian" && $1 != "ubuntu" && $7 == "/bin/false" {print $1}' /etc/passwd | wc -l)"

echo "-------------------------------------"
echo "Number Of User Accounts: $JUMLAH USERS"
echo "-------------------------------------"
echo " "
echo "==========================================="
echo " "
