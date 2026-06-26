#!/bin/bash

GitUser="RedHawk70"
# wget https://github.com/${GitUser}/

MYIP=$(curl -sS ipv4.icanhazip.com)

RED='\033[0;31m'
NC='\033[0m'

LOG=/root/log-install.txt
CONFIG_TLS=/usr/local/etc/xray/config.json
CONFIG_NONE=/usr/local/etc/xray/none.json

kill_port_if_used() {
    local port="$1"
    local net_lines pidprog pid prog unit ans

    net_lines=$(netstat -nutlp 2>/dev/null | awk -v p=":$port" '$4 ~ p"$" {print}')

    if [[ -n "$net_lines" ]]; then
        echo -e "${RED}[WARNING]${NC} port in used : $port"
        echo -e "\e[1;33m[INFO]\e[0m Service/Process yang guna port $port:"

        while IFS= read -r line; do
            pidprog=$(echo "$line" | awk '{print $7}')
            pid="${pidprog%%/*}"
            prog="${pidprog#*/}"

            if [[ -z "$pidprog" || "$pidprog" == "-" ]]; then
                echo -e "  - $line"
                echo -e "    PID: - | Program: - | Service: -"
                continue
            fi

            unit="-"
            if [[ -n "$pid" && "$pid" != "-" ]]; then
                unit=$(systemctl status "$pid" --no-pager --plain 2>/dev/null | head -n1 | sed 's/^●[[:space:]]*//')
                [[ -z "$unit" ]] && unit="-"
            fi

            echo -e "  - $line"
            echo -e "    PID: $pid | Program: $prog | Service: $unit"
        done <<< "$net_lines"

        echo ""
        echo -e "Pilihan:"
        echo -e "  [1] Kill port tersebut dan teruskan tukar port"
        echo -e "  [2] Cancel"
        read -p "Pilih [1-2]: " ans

        case "$ans" in
            1)
                echo -e "\e[1;33m[INFO]\e[0m Killing processes on port $port..."

                for entry in $(echo "$net_lines" | awk '{print $7}' | sort -u); do
                    pid="${entry%%/*}"
                    if [[ -n "$pid" && "$pid" != "-" ]]; then
                        kill "$pid" 2>/dev/null || true
                    fi
                done

                sleep 1

                net_lines=$(netstat -nutlp 2>/dev/null | awk -v p=":$port" '$4 ~ p"$" {print}')

                if [[ -n "$net_lines" ]]; then
                    echo -e "\e[1;33m[INFO]\e[0m Force killing remaining PIDs on port $port..."

                    for entry in $(echo "$net_lines" | awk '{print $7}' | sort -u); do
                        pid="${entry%%/*}"
                        if [[ -n "$pid" && "$pid" != "-" ]]; then
                            kill -9 "$pid" 2>/dev/null || true
                        fi
                    done

                    sleep 1
                fi

                net_lines=$(netstat -nutlp 2>/dev/null | awk -v p=":$port" '$4 ~ p"$" {print}')

                if [[ -n "$net_lines" ]]; then
                    echo -e "${RED}[ERROR]${NC} Port $port masih digunakan. Batal."
                    exit 1
                fi
                ;;
            *)
                echo -e "${RED}[CANCEL]${NC} Dibatalkan oleh user."
                exit 0
                ;;
        esac
    fi
}

restart_all() {
    for svc in \
        xray \
        xray@config \
        xray@none
    do
        systemctl restart "$svc" >/dev/null 2>&1
    done
}

change_ports_in_config() {
    local config_file="$1"
    local new_port="$2"
    shift 2

    local old_port

    if [[ ! -f "$config_file" ]]; then
        return
    fi

    for old_port in "$@"; do
        if [[ -n "$old_port" ]]; then
            sed -i -E "s/\"port\"[[:space:]]*:[[:space:]]*$old_port/\"port\": $new_port/g" "$config_file"
        fi
    done
}

is_old_port() {
    local new_port="$1"
    shift

    local old_port

    for old_port in "$@"; do
        if [[ -n "$old_port" && "$new_port" == "$old_port" ]]; then
            return 0
        fi
    done

    return 1
}

is_ws_ssl_port() {
    local check_port="$1"
    local p

    for p in $ws_ssl_ports; do
        if [[ "$check_port" == "$p" ]]; then
            return 0
        fi
    done

    return 1
}

update_iptables_ports() {
    local new_port="$1"
    shift

    local old_port

    for old_port in "$@"; do
        if [[ -n "$old_port" && "$old_port" != "$new_port" ]]; then
            if ! is_ws_ssl_port "$old_port"; then
                iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport "$old_port" -j ACCEPT 2>/dev/null
                iptables -D INPUT -m state --state NEW -m udp -p udp --dport "$old_port" -j ACCEPT 2>/dev/null
            fi
        fi
    done

    iptables -C INPUT -m state --state NEW -m tcp -p tcp --dport "$new_port" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport "$new_port" -j ACCEPT

    iptables -C INPUT -m state --state NEW -m udp -p udp --dport "$new_port" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport "$new_port" -j ACCEPT

    iptables-save > /etc/iptables.up.rules

    for old_port in "$@"; do
        if [[ -n "$old_port" && "$old_port" != "$new_port" ]]; then
            if ! is_ws_ssl_port "$old_port"; then
                sed -i "/--dport $old_port /d" /etc/iptables.up.rules
            fi
        fi
    done

    iptables-restore < /etc/iptables.up.rules

    netfilter-persistent save >/dev/null 2>&1
    netfilter-persistent reload >/dev/null 2>&1
}

tls=$(grep -w "Xray Vmess Ws Tls" "$LOG" 2>/dev/null | head -n1 | cut -d: -f2 | sed 's/ //g')
none=$(grep -w "Xray Vmess Ws None Tls" "$LOG" 2>/dev/null | head -n1 | cut -d: -f2 | sed 's/ //g')
xhttp_tls=$(grep -w "Xray Vless Xhttp Tls" "$LOG" 2>/dev/null | head -n1 | cut -d: -f2 | sed 's/ //g')
xhttp_none=$(grep -w "Xray Vless Xhttp None Tls" "$LOG" 2>/dev/null | head -n1 | cut -d: -f2 | sed 's/ //g')
ws_ssl_ports=$(grep -w "Websocket SSL(HTTPS)" "$LOG" 2>/dev/null | head -n1 | cut -d: -f2- | tr ',' ' ' | sed 's/[^0-9 ]/ /g')

[[ -z "$tls" ]] && tls="$xhttp_tls"
[[ -z "$none" ]] && none="$xhttp_none"

clear
echo -e "\e[0;34m.-----------------------------------------.\e[0m"
echo -e "\e[0;34m|             \e[1;33mCHANGE PORT XRAY\e[m            \e[0;34m|\e[0m"
echo -e "\e[0;34m'-----------------------------------------'\e[0m"
echo -e " \e[1;31m>>\e[0m\e[0;32mChange Port For Xray :\e[0m"
echo -e "  [1]  Change Port Xray Core TLS        [ ${RED}${tls:-N/A}${NC} ]"
echo -e "  [2]  Change Port Xray Core None TLS   [ ${RED}${none:-N/A}${NC} ]"
echo -e " ============================================="
echo -e "  [x]  Back To Menu Change Port"
echo -e "  [y]  Go To Main Menu"
echo -e ""
read -p "   Select From Options [1-2 or x & y] :  " prot
echo -e ""

case "$prot" in
1)
    read -p " New Port Xray Vmess, Vless & Trojan (TLS): " tls1
    if [ -z "$tls1" ]; then
        echo "Please Input Port"
        exit 0
    fi

    if ! is_old_port "$tls1" "$tls" "$xhttp_tls"; then
        kill_port_if_used "$tls1"
    fi

    change_ports_in_config "$CONFIG_TLS" "$tls1" "$tls" "$xhttp_tls"

    if [[ -f "$LOG" ]]; then
        sed -i "s/^.*Xray Vmess Ws Tls.*/   - Xray Vmess Ws Tls         : $tls1/" "$LOG"
        sed -i "s/^.*Xray Vless Ws Tls.*/   - Xray Vless Ws Tls         : $tls1/" "$LOG"
        sed -i "s/^.*Xray HttpUpgrade Tls.*/   - Xray HttpUpgrade Tls      : $tls1/" "$LOG"
        sed -i "s/^.*Xray Trojan Ws Tls.*/   - Xray Trojan Ws Tls        : $tls1/" "$LOG"
        sed -i "s/^.*Xray Vless Xtls Vision.*/   - Xray Vless Xtls Vision    : $tls1/" "$LOG"
        sed -i "s/^.*Xray Trojan Tcp Tls.*/   - Xray Trojan Tcp Tls       : $tls1/" "$LOG"
        sed -i "s/^.*Xray Vless Xhttp Tls.*/   - Xray Vless Xhttp Tls      : $tls1/" "$LOG"
    fi

    update_iptables_ports "$tls1" "$tls" "$xhttp_tls"

    restart_all

    clear
    echo -e "\e[032;1mPort TLS $tls -> $tls1 modified successfully\e[0m"
    ;;

2)
    read -p " New Port Xray Vmess, Vless & Trojan (NONE): " none1
    if [ -z "$none1" ]; then
        echo "Please Input Port"
        exit 0
    fi

    if ! is_old_port "$none1" "$none" "$xhttp_none"; then
        kill_port_if_used "$none1"
    fi

    change_ports_in_config "$CONFIG_NONE" "$none1" "$none" "$xhttp_none"

    if [[ -f "$LOG" ]]; then
        sed -i "s/^.*Xray Vmess Ws None Tls.*/   - Xray Vmess Ws None Tls    : $none1/" "$LOG"
        sed -i "s/^.*Xray Vless Ws None Tls.*/   - Xray Vless Ws None Tls    : $none1/" "$LOG"
        sed -i "s/^.*Xray Trojan Ws None Tls.*/   - Xray Trojan Ws None Tls   : $none1/" "$LOG"
        sed -i "s/^.*Xray HttpUpgrade None Tls.*/   - Xray HttpUpgrade None Tls : $none1/" "$LOG"
        sed -i "s/^.*Xray Vless Xhttp None Tls.*/   - Xray Vless Xhttp None Tls : $none1/" "$LOG"
    fi

    update_iptables_ports "$none1" "$none" "$xhttp_none"

    restart_all

    clear
    echo -e "\e[032;1mPort NONE $none -> $none1 modified successfully\e[0m"
    ;;

x)
    clear
    change-port
    ;;

y)
    clear
    menu
    ;;

*)
    echo "Please enter a correct number"
    ;;
esac
