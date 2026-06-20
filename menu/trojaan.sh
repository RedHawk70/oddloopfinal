#!/bin/bash

GitUser="RedHawk70"

# // IZIN SCRIPT
export MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -s ipinfo.io/ip )
MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -sS ifconfig.me )
clear

# // PROVIDED && MY IP
export MYIP=$(wget -qO- ifconfig.me/ip);
source /var/lib/premium-script/ipvps.conf
export creditt=$(cat /root/provided)

# // BANNER COLOUR
export banner_colour=$(cat /etc/banner)

# // TEXT ON BOX COLOUR
export box=$(cat /etc/box)

# // LINE COLOUR
export line=$(cat /etc/line)

# // TEXT COLOUR ON TOP
export text=$(cat /etc/text)

# // TEXT COLOUR BELOW
export below=$(cat /etc/below)

# // BACKGROUND TEXT COLOUR
export back_text=$(cat /etc/back)

# // NUMBER COLOUR
export number=$(cat /etc/number)

# // TOTAL ACC CREATE  TROJAN
export total=$(grep -c -E "^#trx " "/usr/local/etc/xray/tcp.json")

# // TOTAL ACC CREATE  TROJAN WS TLS
export total2=$(grep -c -E "^#trws " "/usr/local/etc/xray/trojan.json")
if [[ "$IP" = "" ]]; then
    domain=$(cat /usr/local/etc/xray/domain)
else
    domain=$IP
fi

# // FUCTION CREATE USER TROJAN
function menu1 () {
clear
export xtr="$(cat ~/log-install.txt | grep -w "Trojan Tcp Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box CREATE USER XRAY TROJAN TCP TLS\e[30m ]\e[1m          \e[m"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
		read -rp "   Password: " -e user
		user_EXISTS=$(grep -w $user /usr/local/etc/xray/akunxtr.conf | wc -l)

		if [[ ${user_EXISTS} == '1' ]]; then
			echo ""
			echo "A client with the specified name was already created, please choose another name."
			exit 1
		fi
	done
read -p "   Bug Address (Example: www.google.com) : " address
read -p "   Bug SNI (Example : m.facebook.com) : " sni
read -p "   Expired (days) : " masaaktif

export bug_addr=${address}.
export bug_addr2=$address
if [[ $address == "" ]]; then
    sts=$bug_addr2
else
    sts=$bug_addr
fi

export harini=`date -d "0 days" +"%Y-%m-%d"`
export exp=`date -d "$masaaktif days" +"%Y-%m-%d"`

sed -i '/#trojan$/a\#trx '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/tcp.json

echo -e "### $user $exp $harini $uuid" >> /usr/local/etc/xray/akunxtr.conf

systemctl restart xray@tcp
export trojanlink="trojan://${user}@${sts}${domain}:${xtr}?sni=$sni#${user}"

cat > /home/vps/public_html/trojan-$user.txt <<-END

====================================================================
             P R O J E C T  O F  N I L P H R E A K Z V P N
                       [Freedom Internet]
====================================================================
             https://github.com/NiL070/oddloop
====================================================================
             Format Trojan TCP - SPv2
====================================================================

             Link Trojan Account
====================================================================
Remarks       : ${user}
Domain        : ${domain}
IP/Host       : ${MYIP}
Port          : ${xtr}
Key           : ${user}
Network       : TCP
allowInsecure : True/allow
====================================================================
Link Trojan : ${trojanlink}
====================================================================
Expired On : $exp
====================================================================

END

clear
echo -e ""
echo -e "\e[$line════════[XRAY TROJAN TCP]════════\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port          : ${xtr}"
echo -e "Key           : ${user}"
echo -e "Network       : TCP"
echo -e "allowInsecure : True/allow"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link Trojan : ${trojanlink}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

# // FUCTION TRIAL USER TROJAN
function menu2 () {
clear
export xtr="$(cat ~/log-install.txt | grep -w "Trojan Tcp Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box TRIAL USER XRAY TROJAN TCP TLS\e[30m ]\e[1m           \e[m"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"

# // Create Expried 
export masaaktif="1"
export exp=$(date -d "$masaaktif days" +"%Y-%m-%d")

# // Make Random Username 
export user=Trial`</dev/urandom tr -dc X-Z0-9 | head -c4`

read -p "   Bug Address (Example: www.google.com) : " address
read -p "   Bug SNI (Example : m.facebook.com) : " sni

bug_addr=${address}.
bug_addr2=$address
if [[ $address == "" ]]; then
sts=$bug_addr2
else
sts=$bug_addr
fi

export harini=`date -d "0 days" +"%Y-%m-%d"`

sed -i '/#trojan$/a\#trx '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/tcp.json

echo -e "### $user $exp $harini $uuid" >> /usr/local/etc/xray/akunxtr.conf

systemctl restart xray@tcp

export trojanlink="trojan://${user}@${sts}${domain}:${xtr}?sni=$sni#${user}"

clear
echo -e ""
echo -e "\e[$line═════[TRIAL XRAY TROJAN TCP]═════\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port          : ${xtr}"
echo -e "Key           : ${user}"
echo -e "Network       : TCP"
echo -e "allowInsecure : True/allow"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link Trojan : ${trojanlink}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu3 () {
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/usr/local/etc/xray/akunxtr.conf")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	echo ""
	echo " DELETE XRAY TROJAN TCP"
	echo " Select the existing client you want to remove"
	echo " Press CTRL+C to return"
	echo " ==============================="
	echo "     No  Expired   User"
	grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
export harini=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)
export CLIENT_NAME=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 2-3 | sed -n "${CLIENT_NUMBER}"p)
export user=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)

sed -i "/^### $user $exp $harini $uuid/d" /usr/local/etc/xray/akunxtr.conf
sed -i "/^#trx $user $exp $harini $uuid/,/^},{/d" /usr/local/etc/xray/tcp.json

systemctl restart xray@tcp
service cron restart

clear
echo " Xray Trojan TCP Account Deleted Successfully"
echo " =========================="
echo " Client Name : $user"
echo " Expired On  : $exp"
echo " =========================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu4 () {
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/usr/local/etc/xray/akunxtr.conf")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		clear
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	clear
	echo ""
	echo "Renew User Xray Trojan Tcp"
	echo "Select the existing client you want to renew"
	echo " Press CTRL+C to return"
	echo -e "==============================="
	grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
read -p "Expired (days): " masaaktif

export harini=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)
export user=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)

# // Date
export now=$(date +%Y-%m-%d)
export d1=$(date -d "$exp" +%s)
export d2=$(date -d "$now" +%s)
export exp2=$(( (d1 - d2) / 86400 ))
export exp3=$(($exp2 + $masaaktif))
export exp4=`date -d "$exp3 days" +"%Y-%m-%d"`

sed -i "s/### $user $exp $harini $uuid/### $user $exp4 $harini $uuid/g" /usr/local/etc/xray/akunxtr.conf
sed -i "s/#trx $user $exp $harini $uuid/#trx $user $exp4 $harini $uuid/g" /usr/local/etc/xray/tcp.json

systemctl restart xray@tcp
service cron restart

clear
echo ""
echo " XRAY TROJAN TCP Account Was Successfully Renewed"
echo " =========================="
echo " Client Name : $user"
echo " Expired On  : $exp4"
echo " =========================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu5 () {
xtr="$(cat ~/log-install.txt | grep -w "Trojan Tcp Tls" | cut -d: -f2|sed 's/ //g')"
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^### " "/usr/local/etc/xray/akunxtr.conf")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		clear
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	clear
	echo ""
	echo "SHOW USER XRAY TROJAN TCP TLS"
	echo "Select the existing client you want to renew"
	echo " Press CTRL+C to return"
	echo -e "==============================="
	grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
export patch=/xray
export user=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export harini=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^### " "/usr/local/etc/xray/akunxtr.conf" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)

export trojanlink="trojan://${user}@${domain}:${xtr}?sni=bug.com#${user}"

clear
echo -e ""
echo -e "\e[$line════════[XRAY TROJAN TCP]════════\e[m"
echo -e "Remarks        : ${user}"
echo -e "Domain         : ${domain}"
echo -e "IP/Host        : ${MYIP}"
echo -e "Port           : ${xtr}"
echo -e "Key            : ${user}"
echo -e "Network        : TCP"
echo -e "allowInsecure  : True"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link Trojan  : ${trojanlink}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Created  : $harini"
echo -e "Expired  : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu6 () {
clear
  LOGFILE="/var/log/xray/access3.log"
  LOGLINES=50000

echo -e "\033[0;34m══════════════════════════════════════════\033[0m"
echo -e "\\E[0;44;37m    ⇱ XRAY Trojan Tcp Tls User Login  ⇲   \E[0m"
echo -e "\033[0;34m══════════════════════════════════════════\033[0m"

  tail -n "$LOGLINES" "$LOGFILE" 2>/dev/null | \
  awk '
  function clean_ip(s) {
    sub(/^tcp:/, "", s)
    sub(/^udp:/, "", s)
    gsub(/^\[/, "", s)
    sub(/\].*/, "", s)
    sub(/:.*/, "", s)
    return s
  }
  function clean_user(s) {
    sub(/^email:/, "", s)
    gsub(/^[[:space:]]+/, "", s)
    gsub(/[[:space:]]+$/, "", s)
    return s
  }
  function looks_like_ip(s) {
    if (s ~ /^[0-9.]+$/ && s ~ /\./) return 1
    if (s ~ /^[0-9a-fA-F:]+$/ && s ~ /:/) return 1
    return 0
  }

  {
    ip=""; user="";

    # username/email (support "email: USER" & "email:USER")
    for (i=1; i<=NF; i++) {
      if ($i=="email:" && (i+1)<=NF) { user=$(i+1); break }
      if ($i ~ /^email:/)            { user=clean_user($i); break }
    }
    if (user=="") next

    # Debian 10: from tcp:IP:PORT
    for (i=1; i<=NF; i++) {
      if ($i=="from" && (i+1)<=NF && $(i+1) ~ /^tcp:/) {
        ip = clean_ip($(i+1))
        break
      }
    }

    # Debian 12/13 fallback: kolum ke-3 (cth 113.x.x.x:0 atau tcp:x.x.x.x:0)
    if (ip=="") ip = clean_ip($3)

    if (!looks_like_ip(ip)) next

    key = user SUBSEP ip
    if (!(key in seen)) {
      seen[key]=1
      ips[user] = ips[user] ip "|"
    }
  }

  END {
    # output 1 line per user: user<TAB>ip1|ip2|ip3|
    for (u in ips) {
      printf "%s\t%s\n", u, ips[u]
    }
  }' | \
  sort -t $'\t' -k1,1 | \
  awk -F'\t' '
  BEGIN { user_idx=0 }
  {
    user=$1
    ipstr=$2

    user_idx++
    printf "%d) user : %s\n", user_idx, user

    n = split(ipstr, a, /\|/)
    idx=0
    for (i=1; i<=n; i++) {
      if (a[i] != "") {
        idx++
        printf "%d. %s\n", idx, a[i]
      }
    }
    print ""
    print "------------------------------------------"
  }'
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

# // FUCTION CREATE USER TROJAN
function menu7 () {
clear
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box CREATE USER XRAY TROJAN WS TLS\e[30m ]\e[1m          \e[m"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
		read -rp "   Password: " -e user
		user_EXISTS=$(grep -w $user /usr/local/etc/xray/trojan.json | wc -l)

		if [[ ${user_EXISTS} == '1' ]]; then
			echo ""
			echo "A client with the specified name was already created, please choose another name."
			exit 1
		fi
	done
export patchtls=/trojanwstls
export patchnone=/trojanwsntls
read -p "   Bug Address (Example: www.google.com) : " address
read -p "   Bug SNI (Example : m.facebook.com) : " sni
read -p "   Expired (days) : " masaaktif

bug_addr=${address}.
bug_addr2=$address
if [[ $address == "" ]]; then
sts=$bug_addr2
else
sts=$bug_addr
fi

export harini=`date -d "0 days" +"%Y-%m-%d"`
export exp=`date -d "$masaaktif days" +"%Y-%m-%d"`

sed -i '/#xray-trojan-tls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/trojan.json
sed -i '/#xray-trojan-nontls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/trojannone.json

systemctl restart xray@trojan
systemctl restart xray@trojannone

export trojanlink="trojan://${user}@${sts}${domain}:80?host=$sni&security=none&type=ws&path=${patchnone}#${user}";
export trojanlink1="trojan://${user}@${sts}${domain}:443?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"

cat > /home/vps/public_html/trojanws-$user.txt <<-END

====================================================================
             P R O J E C T  O F  N I L P H R E A K Z V P N
                       [Freedom Internet]
====================================================================
             https://github.com/NiL070/oddloop
====================================================================
             Format Trojan WS - SPv2
====================================================================

             Link Trojan Account
====================================================================
Remarks       : ${user}
Domain        : ${domain}
IP/Host       : ${MYIP}
Port Tls      : ${trws}
Port None     : ${trnone}
Key           : ${user}
Security      : Auto
Network       : Websocket
Path Tls      : $patchtls
Path Ntls     : $patchnone
allowInsecure : True/allow
====================================================================
Link Trojan TLS : ${trojanlink1}
====================================================================
Link Trojan NTLS : ${trojanlink}
====================================================================
Expired On : $exp
====================================================================

END

clear
echo -e ""
echo -e "\e[$line════════[XRAY TROJAN WS TLS]════════\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port Tls      : ${trws}"
echo -e "Port None     : ${trnone}"
echo -e "Key           : ${user}"
echo -e "Security      : Auto"
echo -e "Network       : Websocket"
echo -e "Path Tls      : $patchtls"
echo -e "Path Ntls     : $patchnone"
echo -e "allowInsecure : True/allow"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

# FUCTION TRIAL USER TROJAN
function menu8 () {
clear
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box TRIAL USER XRAY TROJAN WS TLS\e[30m ]\e[1m           \e[m"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"

# // Make Random Username && Date
export masaaktif="1"
export exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
export user=Trial`</dev/urandom tr -dc X-Z0-9 | head -c4`

export patchtls=/trojanwstls
export patchnone=/trojanwsntls

read -p "   Bug Address (Example: www.google.com) : " address
read -p "   Bug SNI (Example : m.facebook.com) : " sni

bug_addr=${address}.
bug_addr2=$address
if [[ $address == "" ]]; then
sts=$bug_addr2
else
sts=$bug_addr
fi

export harini=`date -d "0 days" +"%Y-%m-%d"`

sed -i '/#xray-trojan-tls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/trojan.json
sed -i '/#xray-trojan-nontls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/trojannone.json

systemctl restart xray@trojan
systemctl restart xray@trojannone

export trojanlink="trojan://${user}@${sts}${domain}:80?path=$patchnone&security=none&host=$sni&type=ws#${user}"
export trojanlink1="trojan://${user}@${sts}${domain}:443?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"

clear
echo -e ""
echo -e "\e[$line═════[TRIAL XRAY TROJAN WS TLS]═════\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port Tls      : ${trws}"
echo -e "Port None     : ${trnone}"
echo -e "Key           : ${user}"
echo -e "Security      : Auto"
echo -e "Network       : Websocket"
echo -e "Path Tls      : $patchtls"
echo -e "Path Ntls     : $patchnone"
echo -e "allowInsecure : True/allow"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu9 () {
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#trws " "/usr/local/etc/xray/trojan.json")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	echo ""
	echo " DELETE XRAY TROJAN WS TLS"
	echo " Select the existing client you want to remove"
	echo " Press CTRL+C to return"
	echo " ==============================="
	echo "     No  Expired   User"
	grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
export harini=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)
export CLIENT_NAME=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 2-3 | sed -n "${CLIENT_NUMBER}"p)
export user=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)

sed -i "/^#trws $user $exp $harini $uuid/,/^},{/d" /usr/local/etc/xray/trojan.json
sed -i "/^#trws $user $exp $harini $uuid/,/^},{/d" /usr/local/etc/xray/trojannone.json

systemctl restart xray@trojannone
systemctl restart xray@trojan
service cron restart

clear
echo " Xray Trojan WS TLS Account Deleted Successfully"
echo " =========================="
echo " Client Name : $user"
echo " Expired On  : $exp"
echo " =========================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu10 () {
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#trws " "/usr/local/etc/xray/trojan.json")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		clear
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	clear
	echo ""
	echo "Renew User Xray Trojan Ws Tls"
	echo "Select the existing client you want to renew"
	echo " Press CTRL+C to return"
	echo -e "==============================="
	grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
read -p "Expired (days): " masaaktif
export harini=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)
export user=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
export now=$(date +%Y-%m-%d)
export d1=$(date -d "$exp" +%s)
export d2=$(date -d "$now" +%s)
export exp2=$(( (d1 - d2) / 86400 ))
export exp3=$(($exp2 + $masaaktif))
export exp4=`date -d "$exp3 days" +"%Y-%m-%d"`

sed -i "s/#trws $user $exp $harini $uuid/#trws $user $exp4 $harini $uuid/g" /usr/local/etc/xray/trojan.json
sed -i "s/#trws $user $exp $harini $uuid/#trws $user $exp4 $harini $uuid/g" /usr/local/etc/xray/trojannone.json

service cron restart

clear
echo ""
echo " XRAY TROJAN WS TLS Account Was Successfully Renewed"
echo " =========================="
echo " Client Name : $user"
echo " Expired On  : $exp4"
echo " =========================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu11 () {
clear
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
NUMBER_OF_CLIENTS=$(grep -c -E "^#trws " "/usr/local/etc/xray/trojan.json")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		clear
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	clear
	echo ""
	echo "SHOW USER XRAY TROJAN TCP TLS"
	echo "Select the existing client you want to renew"
	echo " Press CTRL+C to return"
	echo -e "==============================="
	grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
export patchtls=/trojanwstls
export patchnone=/trojanwsntls
export user=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export harini=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^#trws " "/usr/local/etc/xray/trojan.json" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)

export trojanlink1="trojan://${user}@${sts}${domain}:443?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"
export trojanlink="trojan://${user}@${sts}${domain}:80?path=$patchnone&security=none&host=$sni&type=ws#${user}"

clear
echo -e ""
echo -e "\e[$line════════[XRAY TROJAN WS TLS]════════\e[m"
echo -e "Remarks       : ${user}"
echo -e "Domain        : ${domain}"
echo -e "IP/Host       : ${MYIP}"
echo -e "Port Tls      : ${trws}"
echo -e "Port None     : ${trnone}"
echo -e "Key           : ${user}"
echo -e "Security      : Auto"
echo -e "Network       : Websocket"
echo -e "Path Tls      : $patchtls"
echo -e "Path Ntls     : $patchnone"
echo -e "allowInsecure : True/allow"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line═════════════════════════════════\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

function menu12 () {
clear
  LOGFILE="/var/log/xray/access4.log"
  LOGLINES=50000

echo -e "\033[0;34m══════════════════════════════════════════\033[0m"
echo -e "\\E[0;44;37m      ⇱ XRAY Trojan WS User Login  ⇲      \E[0m"
echo -e "\033[0;34m══════════════════════════════════════════\033[0m"

  tail -n "$LOGLINES" "$LOGFILE" 2>/dev/null | \
  awk '
  function clean_ip(s) {
    sub(/^tcp:/, "", s)
    sub(/^udp:/, "", s)
    gsub(/^\[/, "", s)
    sub(/\].*/, "", s)
    sub(/:.*/, "", s)
    return s
  }
  function clean_user(s) {
    sub(/^email:/, "", s)
    gsub(/^[[:space:]]+/, "", s)
    gsub(/[[:space:]]+$/, "", s)
    return s
  }
  function looks_like_ip(s) {
    if (s ~ /^[0-9.]+$/ && s ~ /\./) return 1
    if (s ~ /^[0-9a-fA-F:]+$/ && s ~ /:/) return 1
    return 0
  }

  {
    ip=""; user="";

    # username/email (support "email: USER" & "email:USER")
    for (i=1; i<=NF; i++) {
      if ($i=="email:" && (i+1)<=NF) { user=$(i+1); break }
      if ($i ~ /^email:/)            { user=clean_user($i); break }
    }
    if (user=="") next

    # Debian 10: from tcp:IP:PORT
    for (i=1; i<=NF; i++) {
      if ($i=="from" && (i+1)<=NF && $(i+1) ~ /^tcp:/) {
        ip = clean_ip($(i+1))
        break
      }
    }

    # Debian 12/13 fallback: kolum ke-3 (cth 113.x.x.x:0 atau tcp:x.x.x.x:0)
    if (ip=="") ip = clean_ip($3)

    if (!looks_like_ip(ip)) next

    key = user SUBSEP ip
    if (!(key in seen)) {
      seen[key]=1
      ips[user] = ips[user] ip "|"
    }
  }

  END {
    # output 1 line per user: user<TAB>ip1|ip2|ip3|
    for (u in ips) {
      printf "%s\t%s\n", u, ips[u]
    }
  }' | \
  sort -t $'\t' -k1,1 | \
  awk -F'\t' '
  BEGIN { user_idx=0 }
  {
    user=$1
    ipstr=$2

    user_idx++
    printf "%d) user : %s\n", user_idx, user

    n = split(ipstr, a, /\|/)
    idx=0
    for (i=1; i<=n; i++) {
      if (a[i] != "") {
        idx++
        printf "%d. %s\n", idx, a[i]
      }
    }
    print ""
    print "------------------------------------------"
  }'
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
exec trojaan
}

# MENU TROJAN
clear
echo -e ""
echo -e "   \e[$line════════════════════════════════════════\e[m"
echo -e "   \e[$back_text          \e[30m═[\e[$box TROJAN TCP TLS\e[30m ]═          \e[m"
echo -e "   \e[$line════════════════════════════════════════\e[m"
echo -e "   \e[$number (•1)\e[m \e[$below Create Trojan TCP TLS Account\e[m"
echo -e "   \e[$number (•2)\e[m \e[$below Trial Trojan TCP TLS Account\e[m"
echo -e "   \e[$number (•3)\e[m \e[$below Deleting Trojan TCP TLS Account\e[m"
echo -e "   \e[$number (•4)\e[m \e[$below Renew Xray Trojan TCP TLS Account\e[m"
echo -e "   \e[$number (•5)\e[m \e[$below Show Config Trojan TCP TLS Account\e[m"
echo -e "   \e[$number (•6)\e[m \e[$below Check User Login Trojan TCP TLS\e[m"
echo -e ""
echo -e "   \e[$number    >> Total :\e[m \e[$below ${total} Client\e[m"
echo -e "   \e[$line════════════════════════════════════════\e[m"
echo -e "   \e[$back_text          \e[30m═[\e[$box TROJAN WS TLS\e[30m ]═           \e[m"
echo -e "   \e[$line════════════════════════════════════════\e[m"
echo -e "   \e[$number (•7)\e[m \e[$below Create Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•8)\e[m \e[$below Trial Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•9)\e[m \e[$below Deleting Trojan WS TLS Account\e[m"
echo -e "   \e[$number (10)\e[m \e[$below Renew Xray Trojan WS TLS Account\e[m"
echo -e "   \e[$number (11)\e[m \e[$below Show Config Trojan WS TLS Account\e[m"
echo -e "   \e[$number (12)\e[m \e[$below Check User Login Trojan WS TLS\e[m"
echo -e ""
echo -e "   \e[$number    >> Total :\e[m \e[$below ${total2} Client\e[m"
echo -e "   \e[$line════════════════════════════════════════\e[m"
echo -e "   \e[$back_text \e[$box x)   MENU                             \e[m"
echo -e "   \e[$line════════════════════════════════════════\e[m"
echo -e "\e[$line"
read -rp "      Please Input Number  [1-12 or x] :  "  num
echo -e ""
if [[ "$num" = "1" ]]; then
menu1
elif [[ "$num" = "2" ]]; then
menu2
elif [[ "$num" = "3" ]]; then
menu3
elif [[ "$num" = "4" ]]; then
menu4
elif [[ "$num" = "5" ]]; then
menu5
elif [[ "$num" = "6" ]]; then
menu6
elif [[ "$num" = "7" ]]; then
menu7
elif [[ "$num" = "8" ]]; then
menu8
elif [[ "$num" = "9" ]]; then
menu9
elif [[ "$num" = "10" ]]; then
menu10
elif [[ "$num" = "11" ]]; then
menu11
elif [[ "$num" = "12" ]]; then
menu12
elif [[ "$num" = "x" ]]; then
menu
else
clear
echo -e "\e[1;31mYou Entered The Wrong Number, Please Try Again!\e[0m"
sleep 1
trojaan
fi
