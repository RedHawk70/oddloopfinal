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
echo -e   "  \e[$back_text          \e[30m[\e[$box CREATE USER XRAY TROJAN WS\e[30m ]\e[1m          \e[m"
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
echo -e "Port Tls      : ${trws},8443,2083,2096"
echo -e "Port None     : ${trnone},8080,2052,2082,2095"
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
read -rsn1 -p "Press any key to back on menu Trojan or ctrl+x to see config list" keypress
if [[ "$keypress" == $'\x18' ]]; then
CFGMODE="trojan"
config_list_menu
fi
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
	until [[ ${CLIENT_NUMBER} =~ ^[0-9]+$ ]] && \
	      [[ ${CLIENT_NUMBER} -ge 1 ]] && \
	      [[ ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${NUMBER_OF_CLIENTS} == '1' ]]; then
			read -rp "Select one client [1] (or 's' to search): " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}] (or 's' to search): " CLIENT_NUMBER
		fi

		# ---------- SEARCH MODE ----------
		if [[ ${CLIENT_NUMBER} == 's' || ${CLIENT_NUMBER} == 'S' ]]; then
			read -rp "   Masukkan username yang nak dicari: " SEARCH_USER
			SEARCH_NUM=$(grep -E "^#trws " "/usr/local/etc/xray/config.json" | awk -v u="$SEARCH_USER" '$2==u{print NR; exit}')
			if [[ -z "$SEARCH_NUM" ]]; then
				echo ""
				echo "User not found : $SEARCH_USER"
				sleep 3
				menu5
			else
				CLIENT_NUMBER="$SEARCH_NUM"
				break
			fi
		fi
		# ---------- END SEARCH MODE ----------
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
echo -e "Port Tls      : ${trws},8443,2083,2096"
echo -e "Port None     : ${trnone},8080,2052,2082,2095"
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
read -rsn1 -p "Press any key to back on menu Trojan or ctrl+x to see config list" keypress
if [[ "$keypress" == $'\x18' ]]; then
CFGMODE="trojan"
config_list_menu
fi
trojaan
}

# ============ CONFIG LIST FEATURE ============
CONFIGLIST_DIR="/etc/xray/configlist"

config_provider_color () {
	case "$1" in
		1) printf '\033[38;5;208m';;
		2) printf '\033[38;5;93m';;
		3) printf '\033[38;5;226m';;
		4) printf '\033[38;5;33m';;
		5) printf '\033[38;5;196m';;
		6) printf '\033[38;5;51m';;
		7) printf '\033[38;5;46m';;
		8) printf '\033[38;5;197m';;
		9) printf '\033[38;5;44m';;
		10) printf '\033[38;5;160m';;
	esac
}

config_provider_name () {
	case "$1" in
		1) echo "umobile";;
		2) echo "yes";;
		3) echo "digi";;
		4) echo "celcom";;
		5) echo "maxis";;
		6) echo "eastel";;
		7) echo "yoodo";;
		8) echo "tunetalk";;
		9) echo "tonewow";;
		10) echo "redone";;
	esac
}

config_default_path () {
	case "$1" in
		1) echo "/trojanwstls";;
		2) echo "/trojanwsntls";;
	esac
}

config_build_link () {
	local mode="$1" proto="$2" addr="$3" path="$4" extra="$5"
	case "$proto" in
		1) echo "trojan://${user}@${addr}:${trws}?path=${path}&security=tls&host=bug.com&type=ws&sni=${extra}#${user}";;
		2) echo "trojan://${user}@${addr}:${trnone}?path=${path}&security=none&host=${extra}&type=ws#${user}";;
	esac
}

config_edit () {
	local pfile="$1"
	local cname proto addr cpath dpath extra link mode
	mode="${CFGMODE:-trojan}"
	echo ""
	read -rp "   Nama config: " cname
	if [[ -z "$cname" ]]; then echo "   Nama kosong, dibatalkan."; sleep 2; return; fi
	echo ""
	echo "   Pilih protocol:"
	echo "   1) TLS"
	echo "   2) NTLS"
	echo ""
	read -rp "   Protocol [1-2]: " proto
	if ! [[ "$proto" =~ ^[1-2]$ ]]; then echo "   Protocol tidak sah."; sleep 2; return; fi
	read -rp "   Address (Enter untuk ${domain}): " addr
	[[ -z "$addr" ]] && addr="${domain}"
	dpath="$(config_default_path "$proto")"
	read -rp "   Path (Enter untuk ${dpath}): " cpath
	[[ -z "$cpath" ]] && cpath="${dpath}"
	if (( proto % 2 == 1 )); then
		read -rp "   SNI: " extra
	else
		read -rp "   Host: " extra
	fi
	link="$(config_build_link "$mode" "$proto" "$addr" "$cpath" "$extra")"
	mkdir -p "$CONFIGLIST_DIR"
	# Simpan sebagai template (tanpa user) supaya boleh guna semula untuk semua user
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cname" "$mode" "$proto" "$addr" "$cpath" "$extra" >> "$pfile"
	echo ""
	echo "   Config disimpan:"
	echo "   ════════════════════════════════════"
	echo "   Link ${cname}  : ${link}"
	echo "   ════════════════════════════════════"
	echo ""
	read -n 1 -s -r -p "   Press any key to continue"
}

config_list () {
	local pfile="$1"
	local cname mode proto addr cpath extra link found curmode
	clear
	echo ""
	if [[ -z "$user" ]]; then
		echo "   Tiada user semasa. Sila create user dahulu."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	if [[ ! -s "$pfile" ]]; then
		echo "   Tiada config tersimpan."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	curmode="${CFGMODE:-trojan}"
	found=0
	while IFS=$'\t' read -r cname mode proto addr cpath extra; do
		[[ -z "$cname" ]] && continue
		# Sokong format lama tanpa medan mode: anggap trojan.
		# Abaikan template mod lain (vmess/vless/xtls) yang berkongsi folder config.
		if [[ "$mode" != "trojan" && "$mode" != "vmess" && "$mode" != "vless" && "$mode" != "xtls" ]]; then
			extra="$cpath"; cpath="$addr"; addr="$proto"; proto="$mode"; mode="trojan"
		fi
		[[ "$mode" != "$curmode" ]] && continue
		# Bina semula link ikut user semasa
		link="$(config_build_link "$mode" "$proto" "$addr" "$cpath" "$extra")"
		echo "══════════════════════════════════"
		echo "Link ${cname}  : ${link}"
		found=1
	done < "$pfile"
	echo "══════════════════════════════════"
	if [[ "$found" == "0" ]]; then
		echo "   Tiada config tersimpan."
		echo "══════════════════════════════════"
	fi
	echo ""
	read -n 1 -s -r -p "   Press any key to continue"
}

config_delete () {
	local pfile="$1"
	local dnum cname mode proto addr cpath extra curmode lineno i realline
	local -a map names
	clear
	echo ""
	if [[ ! -s "$pfile" ]]; then
		echo "   Tiada config tersimpan."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	curmode="${CFGMODE:-trojan}"
	lineno=0
	map=()
	names=()
	while IFS=$'\t' read -r cname mode proto addr cpath extra; do
		lineno=$((lineno+1))
		[[ -z "$cname" ]] && continue
		if [[ "$mode" != "trojan" && "$mode" != "vmess" && "$mode" != "vless" && "$mode" != "xtls" ]]; then
			mode="trojan"
		fi
		[[ "$mode" != "$curmode" ]] && continue
		map+=("$lineno")
		names+=("$cname")
	done < "$pfile"
	if [[ ${#map[@]} -eq 0 ]]; then
		echo "   Tiada config tersimpan."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	echo "   Senarai config:"
	for i in "${!names[@]}"; do
		printf '%2d) %s\n' "$((i+1))" "${names[$i]}"
	done
	echo ""
	read -rp "   Nombor config untuk delete: " dnum
	[[ -z "$dnum" ]] && return
	if ! [[ "$dnum" =~ ^[0-9]+$ ]] || [[ "$dnum" -lt 1 ]] || [[ "$dnum" -gt ${#map[@]} ]]; then
		echo ""
		echo "   Nombor tidak sah."
		echo ""
		read -n 1 -s -r -p "   Press any key to continue"
		return
	fi
	realline="${map[$((dnum-1))]}"
	cname="${names[$((dnum-1))]}"
	sed -i "${realline}d" "$pfile"
	echo ""
	echo "   Config '$cname' telah dipadam."
	echo ""
	read -n 1 -s -r -p "   Press any key to continue"
}

config_provider_submenu () {
	local pnum="$1" provider pfile sub
	local R=$'\e[0m'
	provider="$(config_provider_name "$pnum")"
	pfile="${CONFIGLIST_DIR}/${provider}.conf"
	mkdir -p "$CONFIGLIST_DIR"
	while true; do
		clear
		echo ""
		echo "   Provider: $(config_provider_color "$pnum")${provider^}${R}"
		echo "   a) Edit config"
		echo "   b) List config"
		echo "   c) Delete config"
		echo "   x) Back"
		echo ""
		read -rp "   Pilih [a/b/c/x]: " sub
		case "$sub" in
			a|A) config_edit "$pfile";;
			b|B) config_list "$pfile";;
			c|C) config_delete "$pfile";;
			x|X) break;;
			*) ;;
		esac
	done
}

config_list_menu () {
	local prov
	local R=$'\e[0m'
	while true; do
		clear
		echo ""
		echo "   CONFIG LIST"
		echo "   1. $(config_provider_color 1)Umobile${R}"
		echo "   2. $(config_provider_color 2)Yes${R}"
		echo "   3. $(config_provider_color 3)Digi${R}"
		echo "   4. $(config_provider_color 4)Celcom${R}"
		echo "   5. $(config_provider_color 5)Maxis${R}"
		echo "   6. $(config_provider_color 6)Eastel${R}"
		echo "   7. $(config_provider_color 7)Yoodo${R}"
		echo "   8. $(config_provider_color 8)Tunetalk${R}"
		echo "   9. $(config_provider_color 9)Tonewow${R}"
		echo "   10. $(config_provider_color 10)Redone${R}"
		echo "   x. Back to menu trojan"
		echo ""
		read -rp "   Pilih [1-10, x]: " prov
		case "$prov" in
			1|2|3|4|5|6|7|8|9|10) config_provider_submenu "$prov";;
			x|X) break;;
			*) ;;
		esac
	done
}
# ============ END CONFIG LIST FEATURE ============

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
