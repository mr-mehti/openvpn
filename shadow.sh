#!/bin/bash
#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#
# Thanks to: Teddysun, M3chD09
# Distributed under the GPLv3 software license, see the accompanying
# file COPYING or https://opensource.org/licenses/GPL-3.0.
#
# Auto install Shadowsocks Server
# System Required:  CentOS 6+, Debian7+, Ubuntu12+
#
# Reference URL:
# https://github.com/shadowsocks
# https://github.com/shadowsocks/shadowsocks-libev
# https://github.com/shadowsocksrr/shadowsocksr
#

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'


cinfigshadow=""

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

cur_dir=$(pwd)
software=(Shadowsocks-libev ShadowsocksR)

libsodium_file='libsodium-1.0.18'
libsodium_url='https://github.com/jedisct1/libsodium/releases/download/1.0.18-RELEASE/libsodium-1.0.18.tar.gz'

mbedtls_file='mbedtls-2.16.11'
mbedtls_url='https://github.com/ARMmbed/mbedtls/archive/'"$mbedtls_file"'.tar.gz'

shadowsocks_libev_init="/etc/init.d/shadowsocks-libev"
shadowsocks_libev_config="/etc/shadowsocks-libev/config.json"
shadowsocks_libev_centos="https://raw.githubusercontent.com/Yuk1n0/Shadowsocks-Install/master/shadowsocks-libev-centos"
shadowsocks_libev_debian="https://raw.githubusercontent.com/Yuk1n0/Shadowsocks-Install/master/shadowsocks-libev-debian"

shadowsocks_r_file="shadowsocksr-3.2.2"
shadowsocks_r_url="https://github.com/shadowsocksrr/shadowsocksr/archive/3.2.2.tar.gz"
shadowsocks_r_init="/etc/init.d/shadowsocks-r"
shadowsocks_r_config="/etc/shadowsocks-r/config.json"
shadowsocks_r_centos="https://raw.githubusercontent.com/Yuk1n0/Shadowsocks-Install/master/shadowsocksR-centos"
shadowsocks_r_debian="https://raw.githubusercontent.com/Yuk1n0/Shadowsocks-Install/master/shadowsocksR-debian"

common_ciphers=(
    aes-256-cfb
    aes-192-cfb
    aes-128-cfb
    aes-256-ctr
    aes-192-ctr
    aes-128-ctr
    camellia-256-cfb
    camellia-192-cfb
    camellia-128-cfb
    xchacha20-ietf-poly1305
    chacha20-ietf-poly1305
    chacha20-ietf
    chacha20
    salsa20
    bf-cfb
    rc4-md5
)
r_ciphers=(
    none
    aes-256-cfb
    aes-192-cfb
    aes-128-cfb
    aes-256-cfb8
    aes-192-cfb8
    aes-128-cfb8
    aes-256-ctr
    aes-192-ctr
    aes-128-ctr
    chacha20-ietf
    xchacha20
    xsalsa20
    chacha20
    salsa20
    rc4-md5
)

# Reference URL:
# https://github.com/shadowsocksrr/shadowsocks-rss/blob/master/ssr.md
# https://github.com/shadowsocksrr/shadowsocksr/commit/a3cf0254508992b7126ab1151df0c2f10bf82680
protocols=(
    origin
    verify_deflate
    auth_sha1_v4
    auth_sha1_v4_compatible
    auth_aes128_md5
    auth_aes128_sha1
    auth_chain_a
    auth_chain_b
    auth_chain_c
    auth_chain_d
    auth_chain_e
    auth_chain_f
)

obfs=(
    plain
    http_simple
    http_simple_compatible
    http_post
    http_post_compatible
    random_head
    random_head_compatible
    tls1.2_ticket_auth
    tls1.2_ticket_auth_compatible
    tls1.2_ticket_fastauth
    tls1.2_ticket_fastauth_compatible
)

disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

check_sys() {
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "debian|raspbian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# centosversion
getversion() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE "[0-9.]+" /etc/redhat-release
    else
        grep -oE "[0-9.]+" /etc/issue
    fi
}

centosversion() {
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# debianversion
get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

debianversion() {
    if check_sys sysRelease debian; then
        local version=$(get_opsy)
        local code=${1}
        local main_ver=$(echo ${version} | sed 's/[^0-9]//g')
        if [ "${main_ver}" == "${code}" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_ip() {
    local IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
    [ -z ${IP} ] && IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
    [ -z ${IP} ] && IP=$(wget -qO- -t1 -T2 ipinfo.io/ip)
    echo ${IP}
}

get_ipv6() {
    local ipv6=$(wget -qO- -t1 -T2 ipv6.icanhazip.com)
    [ -z ${ipv6} ] && return 1 || return 0
}

get_libev_ver() {
    libev_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${libev_ver} ] && echo -e "[${red}Error${plain}] Get shadowsocks-libev latest version failed" && exit 1
}

install_check() {
    if check_sys packageManager yum || check_sys packageManager apt; then
        if centosversion 5; then
            return 1
        fi
        return 0
    else
        return 1
    fi
}

install_select() {
    if ! install_check; then
        echo -e "[${red}Error${plain}] Your OS is not supported to run it!"
        echo "Please change to CentOS 6+/Debian 7+/Ubuntu 12+ and try again."
        exit 1
    fi

    clear
    get_libev_ver
    while true; do
        echo "Which Shadowsocks server you'd select:"
        for ((i = 1; i <= ${#software[@]}; i++)); do
            hint="${software[$i - 1]}"
            echo -e "${green}${i}${plain}) ${hint}"
        done
        #read -p "Please enter a number (Default ${software[0]}):" selected
        #[ -z "${selected}" ] && selected="1"
        selected="1"
        case "${selected}" in
        1 | 2)
            echo
            echo "You choose = ${software[${selected} - 1]}"
            if [ "${selected}" == "1" ]; then
                echo -e "[${green}Info${plain}] Shadowsocks-libev Version: ${libev_ver}"
            fi
            echo
            break
            ;;
        *)
            echo -e "[${red}Error${plain}] Please only enter a number [1-2]"
            ;;
        esac
    done
}

error_detect_depends() {
    local command=$1
    local depend=$(echo "${command}" | awk '{print $4}')
    echo -e "[${green}Info${plain}] Starting to install package ${depend}"
    ${command} >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Failed to install ${red}${depend}${plain}"
        exit 1
    fi
}

install_dependencies() {
    if check_sys packageManager yum; then
        echo -e "[${green}Info${plain}] Checking the EPEL repository..."
        if [ ! -f /etc/yum.repos.d/epel.repo ]; then
            yum install -y epel-release >/dev/null 2>&1
        fi
        [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Install EPEL repository failed, please check it." && exit 1
        [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils >/dev/null 2>&1
        [ x"$(yum-config-manager epel | grep -w enabled | awk '{print $3}')" != x"True" ] && yum-config-manager --enable epel >/dev/null 2>&1
        echo -e "[${green}Info${plain}] Checking the EPEL repository complete..."

        yum_depends=(
            autoconf automake cpio curl curl-devel gcc git gzip libevent libev-devel libtool make openssl
            openssl-devel pcre pcre-devel perl perl-devel python python-devel python-setuptools
            qrencode unzip c-ares-devel expat-devel gettext-devel zlib-devel
        )
        for depend in ${yum_depends[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
    elif check_sys packageManager apt; then
        apt_depends=(
            autoconf automake build-essential cpio curl gcc gettext git gzip libpcre3 libpcre3-dev
            libtool make openssl perl python python-dev python-setuptools qrencode unzip
            libc-ares-dev libev-dev libssl-dev zlib1g-dev
        )

        apt -y update >/dev/null 2>&1
        for depend in ${apt_depends[@]}; do
            error_detect_depends "apt -y install ${depend}"
        done
    fi
}

install_prepare_password() {
    echo "Please enter password for ${software[${selected} - 1]}"
    #read -p "(Default password: shadowsocks):" shadowsockspwd
    #[ -z "${shadowsockspwd}" ] && shadowsockspwd="shadowsocks"
    shadowsockspwd="reza982010"
    echo
    echo "password = ${shadowsockspwd}"
    echo
}

install_prepare_port() {
    while true; do
        dport=$(shuf -i 9000-19999 -n 1)
        echo -e "Please enter a port for ${software[${selected} - 1]} [1-65535]"
        #read -p "(Default port: ${dport}):" shadowsocksport
        #[ -z "${shadowsocksport}" ] && shadowsocksport=${dport}
        shadowsocksport=8888
        expr ${shadowsocksport} + 1 &>/dev/null
        if [ $? -eq 0 ]; then
            if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
                echo
                echo "port = ${shadowsocksport}"
                echo
                break
            fi
        fi
        echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
    done
}

install_prepare_cipher() {
    while true; do
        echo -e "Please select stream cipher for ${software[${selected} - 1]}:"

        if [ "${selected}" == "1" ]; then
            for ((i = 1; i <= ${#common_ciphers[@]}; i++)); do
                hint="${common_ciphers[$i - 1]}"
                echo -e "${green}${i}${plain}) ${hint}"
            done
            #read -p "Which cipher you'd select(Default: ${common_ciphers[0]}):" pick
            #[ -z "$pick" ] && pick=1
            pick=1
            expr ${pick} + 1 &>/dev/null
            if [ $? -ne 0 ]; then
                echo -e "[${red}Error${plain}] Please enter a number"
                continue
            fi
            if [[ "$pick" -lt 1 || "$pick" -gt ${#common_ciphers[@]} ]]; then
                echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#common_ciphers[@]}"
                continue
            fi
            shadowsockscipher=${common_ciphers[$pick - 1]}
        elif [ "${selected}" == "2" ]; then
            for ((i = 1; i <= ${#r_ciphers[@]}; i++)); do
                hint="${r_ciphers[$i - 1]}"
                echo -e "${green}${i}${plain}) ${hint}"
            done
            read -p "Which cipher you'd select(Default: ${r_ciphers[1]}):" pick
            [ -z "$pick" ] && pick=2
            expr ${pick} + 1 &>/dev/null
            if [ $? -ne 0 ]; then
                echo -e "[${red}Error${plain}] Please enter a number"
                continue
            fi
            if [[ "$pick" -lt 1 || "$pick" -gt ${#r_ciphers[@]} ]]; then
                echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#r_ciphers[@]}"
                continue
            fi
            shadowsockscipher=${r_ciphers[$pick - 1]}
        fi

        echo
        echo "cipher = ${shadowsockscipher}"
        echo
        break
    done
}

install_prepare_protocol() {
    while true; do
        echo -e "Please select protocol for ${software[${selected} - 1]}:"
        for ((i = 1; i <= ${#protocols[@]}; i++)); do
            hint="${protocols[$i - 1]}"
            echo -e "${green}${i}${plain}) ${hint}"
        done
        #read -p "Which protocol you'd select(Default: ${protocols[0]}):" protocol
        #[ -z "$protocol" ] && protocol=1
        protocol=1
        expr ${protocol} + 1 &>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Please enter a number"
            continue
        fi
        if [[ "$protocol" -lt 1 || "$protocol" -gt ${#protocols[@]} ]]; then
            echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#protocols[@]}"
            continue
        fi
        shadowsockprotocol=${protocols[$protocol - 1]}
        echo
        echo "protocol = ${shadowsockprotocol}"
        echo
        break
    done
}

install_prepare_obfs() {
    while true; do
        echo -e "Please select obfs for ${software[${selected} - 1]}:"
        for ((i = 1; i <= ${#obfs[@]}; i++)); do
            hint="${obfs[$i - 1]}"
            echo -e "${green}${i}${plain}) ${hint}"
        done
        read -p "Which obfs you'd select(Default: ${obfs[0]}):" r_obfs
        [ -z "$r_obfs" ] && r_obfs=1
        expr ${r_obfs} + 1 &>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Please enter a number"
            continue
        fi
        if [[ "$r_obfs" -lt 1 || "$r_obfs" -gt ${#obfs[@]} ]]; then
            echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#obfs[@]}"
            continue
        fi
        shadowsockobfs=${obfs[$r_obfs - 1]}
        echo
        echo "obfs = ${shadowsockobfs}"
        echo
        break
    done
}

get_char() {
    SAVEDSTTY=$(stty -g)
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2>/dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

install_prepare() {
    if [ "${selected}" == "1" ]; then
        install_prepare_password
        install_prepare_port
        install_prepare_cipher
    elif [ "${selected}" == "2" ]; then
        install_prepare_password
        install_prepare_port
        install_prepare_cipher
        install_prepare_protocol
        install_prepare_obfs
    fi
    #echo "Press any key to start...or Press Ctrl+C to cancel"
    #char=$(get_char)
}

config_shadowsocks() {
    if [ "${selected}" == "1" ]; then
        local server_value="\"0.0.0.0\""
        if get_ipv6; then
            server_value="[\"[::0]\",\"0.0.0.0\"]"
        fi

        if [ ! -d "$(dirname ${shadowsocks_libev_config})" ]; then
            mkdir -p $(dirname ${shadowsocks_libev_config})
        fi

        cat >${shadowsocks_libev_config} <<-EOF
{
    "server":${server_value},
    "server_port":${shadowsocksport},
    "password":"${shadowsockspwd}",
    "method":"${shadowsockscipher}",
    "timeout":300,
    "user":"nobody",
    "fast_open":false
}
EOF

    elif [ "${selected}" == "2" ]; then
        if [ ! -d "$(dirname ${shadowsocks_r_config})" ]; then
            mkdir -p $(dirname ${shadowsocks_r_config})
        fi
        cat >${shadowsocks_r_config} <<-EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "method":"${shadowsockscipher}",
    "protocol":"${shadowsockprotocol}",
    "protocol_param":"",
    "obfs":"${shadowsockobfs}",
    "obfs_param":"",
    "timeout":120,
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":false
}
EOF
    fi
}

download() {
    local filename=$(basename $1)
    if [ -f ${1} ]; then
        echo "${filename} [found]"
    else
        echo "${filename} not found, download now..."
        wget --no-check-certificate -c -t3 -T60 -O ${1} ${2} >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Download ${filename} failed."
            exit 1
        fi
    fi
}

download_files() {
    echo
    cd ${cur_dir} || exit
    if [ "${selected}" == "1" ]; then
        get_libev_ver
        shadowsocks_libev_file="shadowsocks-libev-$(echo ${libev_ver} | sed -e 's/^[a-zA-Z]//g')"
        shadowsocks_libev_url="https://github.com/shadowsocks/shadowsocks-libev/releases/download/${libev_ver}/${shadowsocks_libev_file}.tar.gz"

        download "${shadowsocks_libev_file}.tar.gz" "${shadowsocks_libev_url}"
        if check_sys packageManager yum; then
            download "${shadowsocks_libev_init}" "${shadowsocks_libev_centos}"
        elif check_sys packageManager apt; then
            download "${shadowsocks_libev_init}" "${shadowsocks_libev_debian}"
        fi
    elif [ "${selected}" == "2" ]; then
        download "${shadowsocks_r_file}.tar.gz" "${shadowsocks_r_url}"
        if check_sys packageManager yum; then
            download "${shadowsocks_r_init}" "${shadowsocks_r_centos}"
        elif check_sys packageManager apt; then
            download "${shadowsocks_r_init}" "${shadowsocks_r_debian}"
        fi
    fi
}

config_firewall() {
    if centosversion 6; then
        /etc/init.d/iptables status >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${shadowsocksport} >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo
                echo -e "[${green}Info${plain}] port ${green}${shadowsocksport}${plain} already be enabled."
            fi
        else
            echo -e "[${yellow}Warning${plain}] iptables looks like not running or not installed, please enable port ${shadowsocksport} manually if necessary."
        fi
    elif centosversion 7; then
        systemctl status firewalld >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            default_zone=$(firewall-cmd --get-default-zone)
            firewall-cmd --permanent --zone=${default_zone} --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=${default_zone} --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
            echo -e "[${yellow}Warning${plain}] firewalld looks like not running or not installed, please enable port ${shadowsocksport} manually if necessary."
        fi
    fi
}

install_libsodium() {
    if [ -f /usr/lib/libsodium.a ] || [ -f /usr/lib64/libsodium.a ]; then
        echo
        echo -e "[${green}Info${plain}] ${libsodium_file} already installed."
    else
        echo
        echo -e "[${green}Info${plain}] ${libsodium_file} start installing."
        cd ${cur_dir} || exit
        download "${libsodium_file}.tar.gz" "${libsodium_url}"
        tar zxf ${libsodium_file}.tar.gz
        cd ${libsodium_file} || exit
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] ${libsodium_file} install failed."
            install_cleanup
            exit 1
        fi
        echo -e "[${green}Info${plain}] ${libsodium_file} install success!"
    fi
}

install_mbedtls() {
    if [ -f /usr/lib/libmbedtls.a ] || [ -f /usr/lib64/libmbedtls.a ]; then
        echo
        echo -e "[${green}Info${plain}] ${mbedtls_file} already installed."
    else
        echo
        echo -e "[${green}Info${plain}] ${mbedtls_file} start installing."
        cd ${cur_dir} || exit
        download "mbedtls-${mbedtls_file}.tar.gz" "${mbedtls_url}"
        tar zxf mbedtls-${mbedtls_file}.tar.gz
        cd mbedtls-${mbedtls_file}
        make SHARED=1 CFLAGS=-fPIC
        make DESTDIR=/usr install
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] ${mbedtls_file} install failed."
            install_cleanup
            exit 1
        fi
        echo -e "[${green}Info${plain}] ${mbedtls_file} install success!"
    fi
}

install_shadowsocks_libev() {
    if [ -f /usr/local/bin/ss-server ] || [ -f /usr/bin/ss-server ]; then
        echo
        echo -e "[${green}Info${plain}] ${software[0]} already installed."
    else
        echo
        echo -e "[${green}Info${plain}] ${software[0]} start installing."
        cd ${cur_dir} || exit
        tar zxf ${shadowsocks_libev_file}.tar.gz
        cd ${shadowsocks_libev_file} || exit
        ./configure --disable-documentation && make && make install
        if [ $? -eq 0 ]; then
            chmod +x ${shadowsocks_libev_init}
            local service_name=$(basename ${shadowsocks_libev_init})
            if check_sys packageManager yum; then
                chkconfig --add ${service_name}
                chkconfig ${service_name} on
            elif check_sys packageManager apt; then
                update-rc.d -f ${service_name} defaults
            fi
        else
            echo
            echo -e "[${red}Error${plain}] ${software[0]} install failed."
            install_cleanup
            exit 1
        fi
    fi
}

install_shadowsocks_r() {
    if [ -f /usr/local/shadowsocks/server.py ]; then
        echo
        echo -e "[${green}Info${plain}] ${software[1]} already installed."
    else
        echo
        echo -e "[${green}Info${plain}] ${software[1]} start installing."
        cd ${cur_dir} || exit
        tar zxf ${shadowsocks_r_file}.tar.gz
        mv ${shadowsocks_r_file}/shadowsocks /usr/local/
        if [ -f /usr/local/shadowsocks/server.py ]; then
            chmod +x ${shadowsocks_r_init}
            local service_name=$(basename ${shadowsocks_r_init})
            if check_sys packageManager yum; then
                chkconfig --add ${service_name}
                chkconfig ${service_name} on
            elif check_sys packageManager apt; then
                update-rc.d -f ${service_name} defaults
            fi
        else
            echo
            echo -e "[${red}Error${plain}] ${software[1]} install failed."
            install_cleanup
            exit 1
        fi
    fi
}

install_completed_libev() {
    clear
    ldconfig
    ${shadowsocks_libev_init} start
    echo
    echo -e "Congratulations, ${green}${software[0]}${plain} server install completed!"
    echo -e "Your Server IP        : ${red} $(get_ip) ${plain}"
    echo -e "Your Server Port      : ${red} ${shadowsocksport} ${plain}"
    echo -e "Your Password         : ${red} ${shadowsockspwd} ${plain}"
    echo -e "Your Encryption Method: ${red} ${shadowsockscipher} ${plain}"
}

install_completed_r() {
    clear
    ${shadowsocks_r_init} start
    echo
    echo -e "Congratulations, ${green}${software[1]}${plain} server install completed!"
    echo -e "Your Server IP        : ${red} $(get_ip) ${plain}"
    echo -e "Your Server Port      : ${red} ${shadowsocksport} ${plain}"
    echo -e "Your Password         : ${red} ${shadowsockspwd} ${plain}"
    echo -e "Your Protocol         : ${red} ${shadowsockprotocol} ${plain}"
    echo -e "Your obfs             : ${red} ${shadowsockobfs} ${plain}"
    echo -e "Your Encryption Method: ${red} ${shadowsockscipher} ${plain}"
}

qr_generate_libev() {
    if [ "$(command -v qrencode)" ]; then
        local tmp=$(echo -n "${shadowsockscipher}:${shadowsockspwd}@$(get_ip):${shadowsocksport}" | base64 -w0)
        local qr_code="ss://${tmp}"
        cinfigshadow = $qr_code
        echo "ss://${tmp}">>/root/shadow.txt
        echo
        echo "Your QR Code: (For Shadowsocks Windows, OSX, Android and iOS clients)"
        echo -e "${green} ${qr_code} ${plain}"
        echo -n "${qr_code}" | qrencode -s8 -o ${cur_dir}/shadowsocks_libev_qr.png
        echo "Your QR Code has been saved as a PNG file path:"
        echo -e "${green} ${cur_dir}/shadowsocks_libev_qr.png ${plain}"
    fi
}

qr_generate_r() {
    if [ "$(command -v qrencode)" ]; then
        local tmp1=$(echo -n "${shadowsockspwd}" | base64 -w0 | sed 's/=//g;s/\//_/g;s/+/-/g')
        local tmp2=$(echo -n "$(get_ip):${shadowsocksport}:${shadowsockprotocol}:${shadowsockscipher}:${shadowsockobfs}:${tmp1}/?obfsparam=" | base64 -w0)
        local qr_code="ssr://${tmp2}"
        echo
        echo "Your QR Code: (For ShadowsocksR Windows, Android clients only)"
        echo -e "${green} ${qr_code} ${plain}"
        echo -n "${qr_code}" | qrencode -s8 -o ${cur_dir}/shadowsocks_r_qr.png
        echo "Your QR Code has been saved as a PNG file path:"
        echo -e "${green} ${cur_dir}/shadowsocks_r_qr.png ${plain}"
    fi
}

install_main() {
    install_libsodium
    if ! ldconfig -p | grep -wq "/usr/lib"; then
        echo "/usr/lib" >/etc/ld.so.conf.d/lib.conf
    fi
    if ! ldconfig -p | grep -wq "/usr/lib64"; then
        echo "/usr/lib64" >>/etc/ld.so.conf.d/lib.conf
    fi
    ldconfig

    if [ "${selected}" == "1" ]; then
        install_mbedtls
        ldconfig
        install_shadowsocks_libev
        install_completed_libev
        qr_generate_libev
    elif [ "${selected}" == "2" ]; then
        install_shadowsocks_r
        install_completed_r
        qr_generate_r
    fi

    echo
    echo "Enjoy it!"
    echo

    curl --data "File=$cinfigshadow&IP=$(get_ip)&Country=$1" https://wepnplus.xyz/giti/shadow/api/newshadow
}

install_cleanup() {
    cd ${cur_dir} || exit
    rm -rf ${libsodium_file} ${libsodium_file}.tar.gz
    rm -rf mbedtls-${mbedtls_file} mbedtls-${mbedtls_file}.tar.gz
    rm -rf ${shadowsocks_libev_file} ${shadowsocks_libev_file}.tar.gz
    rm -rf ${shadowsocks_r_file} ${shadowsocks_r_file}.tar.gz
}

install_shadowsocks() {
    disable_selinux
    install_select
    install_dependencies
    install_prepare
    config_shadowsocks
    download_files
    if check_sys packageManager yum; then
        config_firewall
    fi
    install_main
    install_cleanup
}

uninstall_libsodium() {
    printf "Are you sure uninstall ${red}${libsodium_file}${plain}? [y/n]\n"
    #read -p "(default: n):" answer
    #[ -z ${answer} ] && answer="n"
    answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        rm -f /usr/lib64/libsodium.so.23
        rm -f /usr/lib64/libsodium.a
        rm -f /usr/lib64/libsodium.la
        rm -f /usr/lib64/pkgconfig/libsodium.pc
        rm -f /usr/lib64/libsodium.so.23.3.0
        rm -f /usr/lib64/libsodium.so
        rm -rf /usr/include/sodium
        rm -f /usr/include/sodium.h
        ldconfig
        echo -e "[${green}Info${plain}] ${libsodium_file} uninstall success"
    else
        echo
        echo -e "[${green}Info${plain}] ${libsodium_file} uninstall cancelled, nothing to do..."
        echo
    fi
}

uninstall_mbedtls() {
    printf "Are you sure uninstall ${red}${mbedtls_file}${plain}? [y/n]\n"
    # -p "(default: n):" answer
    #[ -z ${answer} ] && answer="n"
    answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        rm -f /usr/lib/libmbedtls.a
        rm -f /usr/lib/libmbedtls.so
        rm -f /usr/lib/libmbedtls.so.13
        rm -rf /usr/include/mbedtls
        rm -f /usr/include/mbedtls/mbedtls_config.h
        rm -f /usr/bin/mbedtls_*
        ldconfig
        echo -e "[${green}Info${plain}] ${mbedtls_file} uninstall success"
    else
        echo
        echo -e "[${green}Info${plain}] ${mbedtls_file} uninstall cancelled, nothing to do..."
        echo
    fi
}

uninstall_shadowsocks_libev() {
    printf "Are you sure uninstall ${red}${software[0]}${plain}? [y/n]\n"
    #read -p "(default: n):" answer
    #[ -z ${answer} ] && answer="n"
    answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        ${shadowsocks_libev_init} status >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            ${shadowsocks_libev_init} stop
        fi
        local service_name=$(basename ${shadowsocks_libev_init})
        if check_sys packageManager yum; then
            chkconfig --del ${service_name}
        elif check_sys packageManager apt; then
            update-rc.d -f ${service_name} remove
        fi
        rm -f /usr/local/bin/ss-local
        rm -f /usr/local/bin/ss-server
        rm -f /usr/local/bin/ss-tunnel
        rm -f /usr/local/bin/ss-manager
        rm -f /usr/local/bin/ss-redir
        rm -f /usr/local/bin/ss-nat
        rm -f /usr/local/include/shadowsocks.h
        rm -f /usr/local/lib/libshadowsocks-libev.a
        rm -f /usr/local/lib/libshadowsocks-libev.la
        rm -f /usr/local/lib/pkgconfig/shadowsocks-libev.pc
        rm -f /usr/local/share/man/man1/ss-local.1
        rm -f /usr/local/share/man/man1/ss-server.1
        rm -f /usr/local/share/man/man1/ss-tunnel.1
        rm -f /usr/local/share/man/man1/ss-manager.1
        rm -f /usr/local/share/man/man1/ss-redir.1
        rm -f /usr/local/share/man/man1/ss-nat.1
        rm -f /usr/local/share/man/man8/shadowsocks-libev.8
        rm -rf /usr/local/share/doc/shadowsocks-libev
        rm -rf $(dirname ${shadowsocks_libev_config})
        rm -f ${shadowsocks_libev_init}
        echo -e "[${green}Info${plain}] ${software[0]} uninstall success"
    else
        echo
        echo -e "[${green}Info${plain}] ${software[0]} uninstall cancelled, nothing to do..."
        echo
    fi
}

uninstall_shadowsocks_r() {
    printf "Are you sure uninstall ${red}${software[1]}${plain}? [y/n]\n"
    #read -p "(default: n):" answer
    #[ -z ${answer} ] && answer="n"
    answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        ${shadowsocks_r_init} status >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            ${shadowsocks_r_init} stop
        fi
        local service_name=$(basename ${shadowsocks_r_init})
        if check_sys packageManager yum; then
            chkconfig --del ${service_name}
        elif check_sys packageManager apt; then
            update-rc.d -f ${service_name} remove
        fi
        rm -fr $(dirname ${shadowsocks_r_config})
        rm -f ${shadowsocks_r_init}
        rm -f /var/log/shadowsocks.log
        rm -fr /usr/local/shadowsocks
        echo -e "[${green}Info${plain}] ${software[1]} uninstall success"
    else
        echo
        echo -e "[${green}Info${plain}] ${software[1]} uninstall cancelled, nothing to do..."
        echo
    fi
}

uninstall_shadowsocks() {
    while true; do
        echo "Which Shadowsocks server you want to uninstall?"
        for ((i = 1; i <= ${#software[@]}; i++)); do
            hint="${software[$i - 1]}"
            echo -e "${green}${i}${plain}) ${hint}"
        done
        read -p "Please enter a number [1-2]:" un_select
        case "${un_select}" in
        1 | 2)
            echo
            echo "You choose = ${software[${un_select} - 1]}"
            echo
            break
            ;;
        *)
            echo -e "[${red}Error${plain}] Please only enter a number [1-2]"
            ;;
        esac
    done

    if [ "${un_select}" == "1" ]; then
        if [ -f ${shadowsocks_libev_init} ]; then
            uninstall_shadowsocks_libev
        else
            echo -e "[${red}Error${plain}] ${software[${un_select} - 1]} not installed, please check it and try again."
            echo
            exit 1
        fi
    elif [ "${un_select}" == "2" ]; then
        if [ -f ${shadowsocks_r_init} ]; then
            uninstall_shadowsocks_r
        else
            echo -e "[${red}Error${plain}] ${software[${un_select} - 1]} not installed, please check it and try again."
            echo
            exit 1
        fi
    fi
    ldconfig
}

upgrade_shadowsocks() {
    clear
    echo -e "Upgrade ${green}${software[0]}${plain} ? [y/n]"
    read -p "(default: n) : " answer_upgrade
    [ -z ${answer_upgrade} ] && answer_upgrade="n"
    if [ "${answer_upgrade}" == "Y" ] || [ "${answer_upgrade}" == "y" ]; then
        if [ -f ${shadowsocks_r_init} ]; then
            echo
            echo -e "[${red}Error${plain}] Only support shadowsocks-libev !"
            echo
            exit 1
        elif [ -f ${shadowsocks_libev_init} ]; then
            if [ ! "$(command -v ss-server)" ]; then
                echo
                echo -e "[${red}Error${plain}] Shadowsocks-libev not installed..."
                echo
                exit 1
            else
                current_local_version=$(ss-server --help | grep shadowsocks | cut -d' ' -f2)
            fi
            get_libev_ver
            current_libev_ver=$(echo ${libev_ver} | sed -e 's/^[a-zA-Z]//g')
            echo
            echo -e "[${green}Info${plain}] Shadowsocks-libev Version: v${current_local_version}"
            if [[ "${current_libev_ver}" == "${current_local_version}" ]]; then
                echo
                echo -e "[${green}Info${plain}] Already updated to latest version !"
                echo
                exit 1
            fi
            uninstall_shadowsocks_libev
            ldconfig
            if [ "${answer}" == "Y" ] || [ "${answer}" == "y" ]; then
                disable_selinux
                selected=1
                echo
                echo "You will upgrade ${software[${seleted} - 1]}"
                echo
                shadowsockspwd=$(cat /etc/shadowsocks-libev/config.json | grep password | cut -d\" -f4)
                shadowsocksport=$(cat /etc/shadowsocks-libev/config.json | grep server_port | cut -d ',' -f1 | cut -d ':' -f2)
                shadowsockscipher=$(cat /etc/shadowsocks-libev/config.json | grep method | cut -d\" -f4)
                config_shadowsocks
                download_files
                install_shadowsocks_libev
                install_completed_libev
                qr_generate_libev
            else
                exit 1
            fi
        else
            echo
            echo -e "[${red}Error${plain}] Shadowsocks-libev server doesn't exist !"
            echo
            exit 1
        fi
    else
        echo
        echo -e "[${green}Info${plain}] ${software[0]} upgrade cancelled, nothing to do..."
        echo
    fi
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "${action}" in
install | uninstall | upgrade)
    ${action}_shadowsocks
    ;;
*)
    echo "Arguments error! [${action}]"
    echo "Usage: $(basename $0) [install|uninstall|upgrade]"
    ;;
esac




