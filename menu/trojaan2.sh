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
export total=$(grep -c -E "^#trx " "/usr/local/etc/xray/config.json")

# // TOTAL ACC CREATE  TROJAN WS TLS
export total2=$(grep -c -E "^#trws " "/usr/local/etc/xray/config.json")
if [[ "$IP" = "" ]]; then
    domain=$(cat /usr/local/etc/xray/domain)
else
    domain=$IP
fi

# // FUCTION CREATE USER TROJAN
function menu1 () {
clear
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line-------------------------------------------------------\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box CREATE USER XRAY TROJAN WS TLS\e[30m ]\e[1m          \e[m"
echo -e   "  \e[$line-------------------------------------------------------\e[m"
until [[ $user =~ ^[a-zA-Z0-9_]+$ && ${user_EXISTS} == '0' ]]; do
		read -rp "   Password: " -e user
		user_EXISTS=$(grep -w $user /usr/local/etc/xray/config.json | wc -l)

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
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/config.json
sed -i '/#xray-trojan-nontls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/none.json

systemctl restart xray@config
systemctl restart xray@none

export trojanlink="trojan://${user}@${sts}${domain}:$trnone?host=$sni&security=none&type=ws&path=${patchnone}#${user}";
export trojanlink1="trojan://${user}@${sts}${domain}:$trws?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"

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
echo -e "\e[$line--------[XRAY TROJAN WS TLS]--------\e[m"
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
echo -e "\e[$line---------------------------------\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
trojaan
}

# FUCTION TRIAL USER TROJAN
function menu2 () {
clear
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
echo -e   "  \e[$line-------------------------------------------------------\e[m"
echo -e   "  \e[$back_text          \e[30m[\e[$box TRIAL USER XRAY TROJAN WS TLS\e[30m ]\e[1m           \e[m"
echo -e   "  \e[$line-------------------------------------------------------\e[m"

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
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/config.json
sed -i '/#xray-trojan-nontls$/a\#trws '"$user $exp $harini $uuid"'\
},{"id": "'""$uuid""'","password": "'""$user""'","email": "'""$user""'"' /usr/local/etc/xray/none.json

systemctl restart xray@config
systemctl restart xray@none

export trojanlink="trojan://${user}@${sts}${domain}:$trnone?path=$patchnone&security=none&host=$sni&type=ws#${user}"
export trojanlink1="trojan://${user}@${sts}${domain}:$trws?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"

clear
echo -e ""
echo -e "\e[$line-----[TRIAL XRAY TROJAN WS TLS]-----\e[m"
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
echo -e "\e[$line---------------------------------\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
trojaan
}

function menu3 () {
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#trws " "/usr/local/etc/xray/config.json")
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
	grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
export harini=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)
export CLIENT_NAME=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 2-3 | sed -n "${CLIENT_NUMBER}"p)
export user=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)

sed -i "/^#trws $user $exp $harini $uuid/,/^},{/d" /usr/local/etc/xray/config.json
sed -i "/^#trws $user $exp $harini $uuid/,/^},{/d" /usr/local/etc/xray/none.json

systemctl restart xray@none
systemctl restart xray@config
service cron restart

clear
echo " Xray Trojan WS TLS Account Deleted Successfully"
echo " =========================="
echo " Client Name : $user"
echo " Expired On  : $exp"
echo " =========================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
trojaan
}

function menu4 () {
clear
NUMBER_OF_CLIENTS=$(grep -c -E "^#trws " "/usr/local/etc/xray/config.json")
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
	grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
read -p "Expired (days): " masaaktif
export harini=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)
export user=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
export now=$(date +%Y-%m-%d)
export d1=$(date -d "$exp" +%s)
export d2=$(date -d "$now" +%s)
export exp2=$(( (d1 - d2) / 86400 ))
export exp3=$(($exp2 + $masaaktif))
export exp4=`date -d "$exp3 days" +"%Y-%m-%d"`

sed -i "s/#trws $user $exp $harini $uuid/#trws $user $exp4 $harini $uuid/g" /usr/local/etc/xray/config.json
sed -i "s/#trws $user $exp $harini $uuid/#trws $user $exp4 $harini $uuid/g" /usr/local/etc/xray/none.json

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
trojaan
}

function menu5 () {
clear
trnone="$(cat ~/log-install.txt | grep -w "Xray Trojan Ws None Tls" | cut -d: -f2|sed 's/ //g')"
trws="$(cat ~/log-install.txt | grep -w "Trojan Ws Tls" | cut -d: -f2|sed 's/ //g')"
NUMBER_OF_CLIENTS=$(grep -c -E "^#trws " "/usr/local/etc/xray/config.json")
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
	grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
export patchtls=/trojanwstls
export patchnone=/trojanwsntls
export user=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
export harini=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 4 | sed -n "${CLIENT_NUMBER}"p)
export exp=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
export uuid=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | cut -d ' ' -f 5 | sed -n "${CLIENT_NUMBER}"p)

export trojanlink1="trojan://${user}@${sts}${domain}:$trws?path=$patchtls&security=tls&host=bug.com&type=ws&sni=$sni#${user}"
export trojanlink="trojan://${user}@${sts}${domain}:$trnone?path=$patchnone&security=none&host=$sni&type=ws#${user}"

clear
echo -e ""
echo -e "\e[$line--------[XRAY TROJAN WS TLS]--------\e[m"
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
echo -e "\e[$line---------------------------------\e[m"
echo -e "Script By $creditt"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link TLS        : ${trojanlink1}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Link None TLS   : ${trojanlink}"
echo -e "\e[$line---------------------------------\e[m"
echo -e "Created : $harini"
echo -e "Expired : $exp"
echo ""
echo ""
read -n 1 -s -r -p "Press any key to back on menu Trojan"
trojaan
}

# MENU TROJAN
clear
echo -e ""
echo -e "   \e[$line----------------------------------------\e[m"
echo -e "   \e[$back_text          \e[30m-[\e[$box TROJAN WS TLS\e[30m ]-           \e[m"
echo -e "   \e[$line----------------------------------------\e[m"
echo -e "   \e[$number (•1)\e[m \e[$below Create Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•2)\e[m \e[$below Trial Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•3)\e[m \e[$below Deleting Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•4)\e[m \e[$below Renew Xray Trojan WS TLS Account\e[m"
echo -e "   \e[$number (•5)\e[m \e[$below Show Config Trojan WS TLS Account\e[m"
echo -e ""
echo -e "   \e[$number    >> Total :\e[m \e[$below ${total2} Client\e[m"
echo -e "   \e[$line----------------------------------------\e[m"
echo -e "   \e[$back_text \e[$box x)   MENU                             \e[m"
echo -e "   \e[$line----------------------------------------\e[m"
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
elif [[ "$num" = "x" ]]; then
menu
else
clear
echo -e "\e[1;31mYou Entered The Wrong Number, Please Try Again!\e[0m"
sleep 1
exec trojaan
fi