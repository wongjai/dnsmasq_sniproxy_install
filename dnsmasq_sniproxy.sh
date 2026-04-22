#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

GITHUB_RAW_URL="https://raw.githubusercontent.com/wongjai/dnsmasq_sniproxy_install/master"
DNSMASQ_VER="2.91"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

get_domains_file(){
    case ${profile} in
        youtube) echo "proxy-domains-youtube.txt" ;;
        disney)  echo "proxy-domains-disney.txt" ;;
        *)       echo "proxy-domains.txt" ;;
    esac
}

get_profile_label(){
    case ${profile} in
        youtube) echo "YouTube" ;;
        disney)  echo "Disney+" ;;
        *)       echo "Netflix/Hulu/HBO/Disney+/YouTube" ;;
    esac
}

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

check_sys(){
    local checkType=$1
    local value=$2
    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue 2>/dev/null; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue 2>/dev/null; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue 2>/dev/null; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /proc/version 2>/dev/null; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version 2>/dev/null; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version 2>/dev/null; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        [ "${value}" == "${release}" ] && return 0 || return 1
    elif [[ "${checkType}" == "packageManager" ]]; then
        [ "${value}" == "${systemPackage}" ] && return 0 || return 1
    fi
}

getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE "[0-9.]+" /etc/redhat-release
    else
        grep -oE "[0-9.]+" /etc/issue
    fi
}

centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        [ "$main_ver" == "$code" ] && return 0 || return 1
    else
        return 1
    fi
}

get_ip(){
    local IP=$(ip addr | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -vE "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
    [ -z "${IP}" ] && IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
    [ -z "${IP}" ] && IP=$(wget -qO- -t1 -T2 ipinfo.io/ip)
    if [ -z "${IP}" ]; then
        echo -e "[${red}Error${plain}] Failed to detect public IP address." >&2
        exit 1
    fi
    echo "${IP}"
}

check_ip(){
    local checkip=$1
    local valid_check=$(echo "$checkip" | awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
    if echo "$checkip" | grep -qE "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"; then
        if [ "${valid_check:-no}" == "yes" ]; then
            return 0
        else
            echo -e "[${red}Error${plain}] IP $checkip not available!"
            return 1
        fi
    else
        echo -e "[${red}Error${plain}] IP format error!"
        return 1
    fi
}

download(){
    local filename=${1}
    echo -e "[${green}Info${plain}] Downloading ${filename}..."
    wget --no-check-certificate -q -t3 -T60 -O "${1}" "${2}"
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Download ${filename} failed."
        exit 1
    fi
}

error_detect_depends(){
    local command=$1
    local depend=$(echo "${command}" | awk '{print $4}')
    echo -e "[${green}Info${plain}] Installing package ${depend}..."
    ${command} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Failed to install ${red}${depend}${plain}"
        exit 1
    fi
}

config_firewall(){
    systemctl status firewalld > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        local default_zone=$(firewall-cmd --get-default-zone)
        for port in ${ports}; do
            firewall-cmd --permanent --zone="${default_zone}" --add-port="${port}/tcp" > /dev/null 2>&1
            if [ "${port}" == "53" ]; then
                firewall-cmd --permanent --zone="${default_zone}" --add-port="${port}/udp" > /dev/null 2>&1
            fi
        done
        firewall-cmd --reload > /dev/null 2>&1
    else
        echo -e "[${yellow}Warning${plain}] firewalld is not running. Please enable ports ${ports} manually if necessary."
    fi
}

install_dependencies(){
    echo -e "[${green}Info${plain}] Installing dependencies..."
    if check_sys packageManager yum; then
        echo -e "[${green}Info${plain}] Checking the EPEL repository..."
        if [ ! -f /etc/yum.repos.d/epel.repo ]; then
            yum install -y epel-release > /dev/null 2>&1
        fi
        [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Install EPEL repository failed, please check it." && exit 1
        [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils > /dev/null 2>&1
        yum-config-manager --enable epel > /dev/null 2>&1
        echo -e "[${green}Info${plain}] EPEL repository OK."

        if [[ ${fastmode} = "1" ]]; then
            yum_depends=(
                curl gettext-devel libev-devel pcre-devel perl udns-devel
            )
        else
            yum_depends=(
                autoconf automake curl gettext-devel libev-devel pcre-devel perl udns-devel
            )
        fi
        for depend in ${yum_depends[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
        if [[ ${fastmode} = "0" ]]; then
            yum config-manager --set-enabled powertools > /dev/null 2>&1
            yum groups list development 2>/dev/null | grep Installed > /dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                yum groups mark remove development -y > /dev/null 2>&1
            fi
            error_detect_depends "yum -y groupinstall development"
        fi
    elif check_sys packageManager apt; then
        if [[ ${fastmode} = "1" ]]; then
            apt_depends=(
                curl gettext libev-dev libpcre3-dev libudns-dev
            )
        else
            apt_depends=(
                autotools-dev cdbs curl gettext libev-dev libpcre3-dev libudns-dev autoconf devscripts
            )
        fi
        apt-get -y update > /dev/null 2>&1
        for depend in ${apt_depends[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
        if [[ ${fastmode} = "0" ]]; then
            error_detect_depends "apt-get -y install build-essential"
        fi
    fi
}

compile_dnsmasq(){
    if check_sys packageManager yum; then
        error_detect_depends "yum -y install epel-release"
        error_detect_depends "yum -y install make"
        error_detect_depends "yum -y install gcc-c++"
        error_detect_depends "yum -y install nettle-devel"
        error_detect_depends "yum -y install gettext"
        error_detect_depends "yum -y install libidn-devel"
        error_detect_depends "yum -y install libnetfilter_conntrack-devel"
        error_detect_depends "yum -y install dbus-devel"
    elif check_sys packageManager apt; then
        error_detect_depends "apt-get -y install make"
        error_detect_depends "apt-get -y install gcc"
        error_detect_depends "apt-get -y install g++"
        error_detect_depends "apt-get -y install pkg-config"
        error_detect_depends "apt-get -y install nettle-dev"
        error_detect_depends "apt-get -y install gettext"
        error_detect_depends "apt-get -y install libidn11-dev"
        error_detect_depends "apt-get -y install libnetfilter-conntrack-dev"
        error_detect_depends "apt-get -y install libdbus-1-dev"
    fi
    if [ -e /tmp/dnsmasq-${DNSMASQ_VER} ]; then
        rm -rf /tmp/dnsmasq-${DNSMASQ_VER}
    fi
    cd /tmp/
    download dnsmasq-${DNSMASQ_VER}.tar.gz https://thekelleys.org.uk/dnsmasq/dnsmasq-${DNSMASQ_VER}.tar.gz
    tar -zxf dnsmasq-${DNSMASQ_VER}.tar.gz
    cd dnsmasq-${DNSMASQ_VER}
    make all-i18n V=s COPTS='-DHAVE_DNSSEC -DHAVE_IDN -DHAVE_CONNTRACK -DHAVE_DBUS'
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] dnsmasq compile failed."
        rm -rf /tmp/dnsmasq-${DNSMASQ_VER} /tmp/dnsmasq-${DNSMASQ_VER}.tar.gz
        exit 1
    fi
}

install_dnsmasq(){
    (ss -tlnp | grep -q ":53 " || ss -ulnp | grep -q ":53 ") && echo -e "[${red}Error${plain}] Port 53 is already in use." && exit 1
    echo -e "[${green}Info${plain}] Installing Dnsmasq..."
    if check_sys packageManager yum; then
        error_detect_depends "yum -y install dnsmasq"
    elif check_sys packageManager apt; then
        error_detect_depends "apt-get -y install dnsmasq"
    fi
    if [[ ${fastmode} = "0" ]]; then
        compile_dnsmasq
        yes | cp -f /tmp/dnsmasq-${DNSMASQ_VER}/src/dnsmasq /usr/sbin/dnsmasq && chmod +x /usr/sbin/dnsmasq
    fi
    [ ! -f /usr/sbin/dnsmasq ] && echo -e "[${red}Error${plain}] dnsmasq installation failed." && exit 1

    local domains_file=$(get_domains_file)
    download /etc/dnsmasq.d/custom_netflix.conf "${GITHUB_RAW_URL}/dnsmasq.conf"
    download /tmp/${domains_file} "${GITHUB_RAW_URL}/${domains_file}"
    for domain in $(cat /tmp/${domains_file}); do
        printf "address=/${domain}/${publicip}\n" | tee -a /etc/dnsmasq.d/custom_netflix.conf > /dev/null 2>&1
    done
    [ "$(grep -x -E "(conf-dir=/etc/dnsmasq.d|conf-dir=/etc/dnsmasq.d,.bak|conf-dir=/etc/dnsmasq.d/,\*.conf|conf-dir=/etc/dnsmasq.d,.rpmnew,.rpmsave,.rpmorig)" /etc/dnsmasq.conf)" ] || echo -e "\nconf-dir=/etc/dnsmasq.d" >> /etc/dnsmasq.conf

    echo -e "[${green}Info${plain}] Starting Dnsmasq..."
    if check_sys packageManager apt; then
        if grep -q "^#IGNORE_RESOLVCONF=yes" /etc/default/dnsmasq 2>/dev/null; then
            sed -i 's/^#IGNORE_RESOLVCONF=yes/IGNORE_RESOLVCONF=yes/' /etc/default/dnsmasq
        elif ! grep -q "^IGNORE_RESOLVCONF=yes" /etc/default/dnsmasq 2>/dev/null; then
            echo "IGNORE_RESOLVCONF=yes" >> /etc/default/dnsmasq
        fi
    fi
    systemctl enable dnsmasq > /dev/null 2>&1
    systemctl restart dnsmasq || { echo -e "[${red}Error${plain}] Failed to start dnsmasq."; exit 1; }

    cd /tmp
    rm -rf /tmp/dnsmasq-${DNSMASQ_VER} /tmp/dnsmasq-${DNSMASQ_VER}.tar.gz /tmp/${domains_file}
    echo -e "[${green}Info${plain}] Dnsmasq installation complete."
}

install_sniproxy(){
    for aport in 80 443; do
        ss -tlnp | grep -q ":${aport} " && echo -e "[${red}Error${plain}] Port ${aport} is already in use." && exit 1
    done
    install_dependencies
    echo -e "[${green}Info${plain}] Installing SNI Proxy..."

    if check_sys packageManager yum; then
        rpm -qa | grep -q sniproxy && rpm -e sniproxy
    elif check_sys packageManager apt; then
        dpkg -s sniproxy > /dev/null 2>&1 && dpkg -r sniproxy
    fi

    local bit=$(uname -m)
    cd /tmp
    if [[ ${fastmode} = "0" ]]; then
        [ -e sniproxy-0.6.1 ] && rm -rf sniproxy-0.6.1
        download /tmp/sniproxy-0.6.1.tar.gz https://github.com/dlundquist/sniproxy/archive/refs/tags/0.6.1.tar.gz
        tar -zxf sniproxy-0.6.1.tar.gz
        cd sniproxy-0.6.1
    fi
    if check_sys packageManager yum; then
        if [[ ${fastmode} = "1" ]]; then
            if [[ ${bit} = "x86_64" ]]; then
                download /tmp/sniproxy-0.6.1-1.el8.x86_64.rpm "${GITHUB_RAW_URL}/sniproxy/sniproxy-0.6.1-1.el8.x86_64.rpm"
                error_detect_depends "yum -y install /tmp/sniproxy-0.6.1-1.el8.x86_64.rpm"
                rm -f /tmp/sniproxy-0.6.1-1.el8.x86_64.rpm
            else
                echo -e "${red}Architecture ${bit} is not supported in fast mode. Use compile mode (-i).${plain}" && exit 1
            fi
        else
            ./autogen.sh && ./configure --prefix=/usr && make && make install
        fi
    elif check_sys packageManager apt; then
        if [[ ${fastmode} = "1" ]]; then
            if [[ ${bit} = "x86_64" ]]; then
                download /tmp/sniproxy_0.6.1_amd64.deb "${GITHUB_RAW_URL}/sniproxy/sniproxy_0.6.1_amd64.deb"
                error_detect_depends "dpkg -i --no-debsig /tmp/sniproxy_0.6.1_amd64.deb"
                rm -f /tmp/sniproxy_0.6.1_amd64.deb
            else
                echo -e "${red}Architecture ${bit} is not supported in fast mode. Use compile mode (-i).${plain}" && exit 1
            fi
        else
            env NAME="sniproxy" DEBFULLNAME="sniproxy" DEBEMAIL="sniproxy@example.com" EMAIL="sniproxy@example.com" ./autogen.sh && ./configure --prefix=/usr && make && make install
        fi
    fi

    [ ! -f /usr/sbin/sniproxy ] && echo -e "[${red}Error${plain}] SNI Proxy installation failed." && exit 1

    download /etc/systemd/system/sniproxy.service "${GITHUB_RAW_URL}/sniproxy.service"
    systemctl daemon-reload
    [ ! -f /etc/systemd/system/sniproxy.service ] && echo -e "[${red}Error${plain}] Failed to download sniproxy service file." && exit 1

    local domains_file=$(get_domains_file)
    download /etc/sniproxy.conf "${GITHUB_RAW_URL}/sniproxy.conf"
    download /tmp/sniproxy-domains.txt "${GITHUB_RAW_URL}/${domains_file}"
    sed -i -e 's/\./\\\./g' -e 's/^/    \.\*/' -e 's/$/\$ \*/' /tmp/sniproxy-domains.txt || { echo -e "[${red}Error${plain}] Failed to configure sniproxy domains."; exit 1; }
    sed -i '/table {/r /tmp/sniproxy-domains.txt' /etc/sniproxy.conf || { echo -e "[${red}Error${plain}] Failed to configure sniproxy."; exit 1; }

    [ ! -e /var/log/sniproxy ] && mkdir -p /var/log/sniproxy

    echo -e "[${green}Info${plain}] Starting SNI Proxy..."
    systemctl enable sniproxy > /dev/null 2>&1
    systemctl restart sniproxy || { echo -e "[${red}Error${plain}] Failed to start sniproxy."; exit 1; }

    cd /tmp
    rm -rf /tmp/sniproxy-0.6.1/ /tmp/sniproxy-0.6.1.tar.gz /tmp/sniproxy-domains.txt
    echo -e "[${green}Info${plain}] SNI Proxy installation complete."
}

health_check(){
    local check_dns=$1
    local check_sni=$2
    echo ""
    echo -e "[${green}Info${plain}] Running health checks..."
    local failed=0

    if [ "${check_dns}" = "1" ]; then
        if systemctl is-active --quiet dnsmasq; then
            echo -e "  [${green}OK${plain}] dnsmasq is running"
        else
            echo -e "  [${red}FAIL${plain}] dnsmasq is not running"
            echo -e "        Check logs: journalctl -u dnsmasq"
            failed=1
        fi
        if ss -ulnp 2>/dev/null | grep -q ":53 "; then
            echo -e "  [${green}OK${plain}] port 53 (DNS/UDP) is listening"
        else
            echo -e "  [${red}FAIL${plain}] port 53 (DNS/UDP) is not listening"
            failed=1
        fi
    fi

    if [ "${check_sni}" = "1" ]; then
        if systemctl is-active --quiet sniproxy; then
            echo -e "  [${green}OK${plain}] sniproxy is running"
        else
            echo -e "  [${red}FAIL${plain}] sniproxy is not running"
            echo -e "        Check logs: journalctl -u sniproxy"
            failed=1
        fi
        for port in 80 443; do
            if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
                echo -e "  [${green}OK${plain}] port ${port} is listening"
            else
                echo -e "  [${red}FAIL${plain}] port ${port} is not listening"
                failed=1
            fi
        done
    fi

    echo ""
    if [ ${failed} -eq 0 ]; then
        echo -e "[${green}Info${plain}] All health checks passed!"
    else
        echo -e "[${yellow}Warning${plain}] Some health checks failed. Review the output above."
    fi
}

install_check(){
    if check_sys packageManager yum || check_sys packageManager apt; then
        if check_sys sysRelease centos; then
            local version="$(getversion)"
            local main_ver=${version%%.*}
            if [ "${main_ver}" -lt 7 ] 2>/dev/null; then
                return 1
            fi
        fi
        return 0
    else
        return 1
    fi
}

ready_install(){
    echo -e "[${green}Info${plain}] Checking system..."
    if ! install_check; then
        echo -e "[${red}Error${plain}] Your OS is not supported!"
        echo -e "Please use CentOS 7+/Debian 8+/Ubuntu 16+ and try again."
        exit 1
    fi
    if check_sys packageManager yum; then
        yum makecache > /dev/null 2>&1
        error_detect_depends "yum -y install wget"
    elif check_sys packageManager apt; then
        apt-get -y update > /dev/null 2>&1
        error_detect_depends "apt-get -y install wget"
    fi
    disable_selinux
    if check_sys packageManager yum; then
        config_firewall
    fi
    echo -e "[${green}Info${plain}] System check complete."
}

hello(){
    echo ""
    echo -e "${yellow}Dnsmasq + SNI Proxy Install Script${plain}"
    echo -e "${yellow}Supported: CentOS 7+, Debian 8+, Ubuntu 16+${plain}"
    echo -e "${yellow}Profile: $(get_profile_label)${plain}"
    echo ""
}

show_help(){
    echo ""
    echo -e "${yellow}Dnsmasq + SNI Proxy Install Script${plain}"
    echo -e "${yellow}Supported: CentOS 7+, Debian 8+, Ubuntu 16+${plain}"
    echo ""
    echo "Usage: bash $0 <action> [-p <profile>]"
    echo ""
    echo "Actions:"
    echo "  -i , --install             Install Dnsmasq + SNI Proxy (compile)"
    echo "  -f , --fastinstall         Fast install Dnsmasq + SNI Proxy (pre-built)"
    echo "  -id, --installdnsmasq      Install Dnsmasq only"
    echo "  -fd, --fastinstalldnsmasq  Fast install Dnsmasq only"
    echo "  -is, --installsniproxy     Install SNI Proxy only"
    echo "  -fs, --fastinstallsniproxy Fast install SNI Proxy only"
    echo "  -r , --refresh             Refresh domain lists (no reinstall)"
    echo "  -u , --uninstall           Uninstall Dnsmasq + SNI Proxy"
    echo "  -ud, --undnsmasq           Uninstall Dnsmasq"
    echo "  -us, --unsniproxy          Uninstall SNI Proxy"
    echo "  -h , --help                Show this help"
    echo ""
    echo "Options:"
    echo "  -p , --profile <name>      Domain profile (default: all)"
    echo "                             all     - Netflix/Hulu/HBO/Disney+/YouTube etc."
    echo "                             youtube - YouTube only"
    echo "                             disney  - Disney+ only"
    echo ""
    echo "Examples:"
    echo "  bash $0 -f                     # Fast install with all domains"
    echo "  bash $0 -f -p youtube          # Fast install YouTube only"
    echo "  bash $0 -i -p disney           # Compile install Disney+ only"
    echo "  bash $0 -r                     # Refresh domains (re-download latest list)"
    echo "  bash $0 -r -p youtube          # Refresh with YouTube profile"
    echo ""
}

install_all(){
    ports="53 80 443"
    publicip=$(get_ip)
    hello
    ready_install
    install_dnsmasq
    install_sniproxy
    health_check 1 1
    echo ""
    echo -e "${yellow}Dnsmasq + SNI Proxy installed successfully!${plain}"
    echo -e "${yellow}Change your DNS to ${publicip} to start streaming.${plain}"
    echo -e "${yellow}Profile: $(get_profile_label)${plain}"
    echo ""
}

only_dnsmasq(){
    ports="53"
    hello
    ready_install
    local inputipcount=1
    echo -e "Enter the SNI Proxy server IP address"
    read -e -p "(leave empty to auto-detect public IP): " inputip
    while true; do
        if [ "${inputipcount}" == 3 ]; then
            echo -e "[${red}Error${plain}] Too many invalid IP attempts."
            exit 1
        fi
        if [ -z "${inputip}" ]; then
            publicip=$(get_ip)
            break
        else
            check_ip "${inputip}"
            if [ $? -eq 0 ]; then
                publicip=${inputip}
                break
            else
                echo -e "Please re-enter the SNI Proxy server IP address"
                read -e -p "(leave empty to auto-detect public IP): " inputip
            fi
        fi
        inputipcount=$((inputipcount + 1))
    done
    install_dnsmasq
    health_check 1 0
    echo ""
    echo -e "${yellow}Dnsmasq installed successfully!${plain}"
    echo -e "${yellow}Change your DNS to $(get_ip) to start streaming.${plain}"
    echo ""
}

only_sniproxy(){
    ports="80 443"
    hello
    ready_install
    install_sniproxy
    health_check 0 1
    echo ""
    echo -e "${yellow}SNI Proxy installed successfully!${plain}"
    echo -e "${yellow}Point streaming domains to $(get_ip) to start.${plain}"
    echo ""
}

undnsmasq(){
    echo -e "[${green}Info${plain}] Stopping dnsmasq..."
    systemctl disable dnsmasq > /dev/null 2>&1
    systemctl stop dnsmasq || echo -e "[${red}Error${plain}] Failed to stop dnsmasq."
    echo -e "[${green}Info${plain}] Uninstalling dnsmasq..."
    if check_sys packageManager yum; then
        yum remove dnsmasq -y > /dev/null 2>&1
    elif check_sys packageManager apt; then
        apt-get remove dnsmasq -y > /dev/null 2>&1
        apt-get remove dnsmasq-base -y > /dev/null 2>&1
    fi
    rm -rf /etc/dnsmasq.d/custom_netflix.conf
    echo -e "[${green}Info${plain}] Dnsmasq uninstalled."
}

unsniproxy(){
    echo -e "[${green}Info${plain}] Stopping sniproxy..."
    systemctl disable sniproxy > /dev/null 2>&1
    systemctl stop sniproxy || echo -e "[${red}Error${plain}] Failed to stop sniproxy."
    echo -e "[${green}Info${plain}] Uninstalling sniproxy..."
    if check_sys packageManager yum; then
        yum remove sniproxy -y > /dev/null 2>&1
    elif check_sys packageManager apt; then
        apt-get remove sniproxy -y > /dev/null 2>&1
    fi
    rm -rf /etc/sniproxy.conf /etc/systemd/system/sniproxy.service
    systemctl daemon-reload > /dev/null 2>&1
    echo -e "[${green}Info${plain}] SNI Proxy uninstalled."
}

refresh_domains(){
    publicip=$(get_ip)
    hello
    echo -e "[${green}Info${plain}] Refreshing domain lists..."

    local domains_file=$(get_domains_file)
    local has_dnsmasq=0
    local has_sniproxy=0

    [ -f /etc/dnsmasq.d/custom_netflix.conf ] && has_dnsmasq=1
    [ -f /etc/sniproxy.conf ] && has_sniproxy=1

    if [ ${has_dnsmasq} -eq 0 ] && [ ${has_sniproxy} -eq 0 ]; then
        echo -e "[${red}Error${plain}] Neither dnsmasq nor sniproxy config found. Please install first."
        exit 1
    fi

    download /tmp/${domains_file} "${GITHUB_RAW_URL}/${domains_file}"

    if [ ${has_dnsmasq} -eq 1 ]; then
        echo -e "[${green}Info${plain}] Updating dnsmasq domains..."
        download /etc/dnsmasq.d/custom_netflix.conf "${GITHUB_RAW_URL}/dnsmasq.conf"
        for domain in $(cat /tmp/${domains_file}); do
            printf "address=/${domain}/${publicip}\n" | tee -a /etc/dnsmasq.d/custom_netflix.conf > /dev/null 2>&1
        done
        systemctl restart dnsmasq || { echo -e "[${red}Error${plain}] Failed to restart dnsmasq."; exit 1; }
        echo -e "[${green}Info${plain}] Dnsmasq domains updated."
    fi

    if [ ${has_sniproxy} -eq 1 ]; then
        echo -e "[${green}Info${plain}] Updating sniproxy domains..."
        download /etc/sniproxy.conf "${GITHUB_RAW_URL}/sniproxy.conf"
        cp /tmp/${domains_file} /tmp/sniproxy-domains.txt
        sed -i -e 's/\./\\\./g' -e 's/^/    \.\*/' -e 's/$/\$ \*/' /tmp/sniproxy-domains.txt || { echo -e "[${red}Error${plain}] Failed to process sniproxy domains."; exit 1; }
        sed -i '/table {/r /tmp/sniproxy-domains.txt' /etc/sniproxy.conf || { echo -e "[${red}Error${plain}] Failed to update sniproxy config."; exit 1; }
        rm -f /tmp/sniproxy-domains.txt
        systemctl restart sniproxy || { echo -e "[${red}Error${plain}] Failed to restart sniproxy."; exit 1; }
        echo -e "[${green}Info${plain}] SNI Proxy domains updated."
    fi

    rm -f /tmp/${domains_file}
    health_check ${has_dnsmasq} ${has_sniproxy}
    echo ""
    echo -e "${yellow}Domain lists refreshed successfully!${plain}"
    echo -e "${yellow}Profile: $(get_profile_label)${plain}"
    echo -e "${yellow}Server IP: ${publicip}${plain}"
    echo ""
}

confirm(){
    echo -e "${yellow}Continue? (y/n)${plain}"
    read -e -p "(default: n): " selection
    [ -z "${selection}" ] && selection="n"
    if [ "${selection}" != "y" ]; then
        exit 0
    fi
}

action=""
profile="all"
fastmode=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--install)              action="install_all"; fastmode=0; shift ;;
        -f|--fastinstall)          action="install_all"; fastmode=1; shift ;;
        -id|--installdnsmasq)      action="only_dnsmasq"; fastmode=0; shift ;;
        -fd|--fastinstalldnsmasq)  action="only_dnsmasq"; fastmode=1; shift ;;
        -is|--installsniproxy)     action="only_sniproxy"; fastmode=0; shift ;;
        -fs|--fastinstallsniproxy) action="only_sniproxy"; fastmode=1; shift ;;
        -r|--refresh)              action="refresh"; shift ;;
        -u|--uninstall)            action="uninstall"; shift ;;
        -ud|--undnsmasq)           action="undnsmasq"; shift ;;
        -us|--unsniproxy)          action="unsniproxy"; shift ;;
        -p|--profile)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo -e "[${red}Error${plain}] --profile requires a value (all, youtube, disney)"
                exit 1
            fi
            profile="$2"; shift 2 ;;
        -h|--help)                 action="help"; shift ;;
        *)
            echo -e "[${red}Error${plain}] Unknown option: $1"
            show_help
            exit 1 ;;
    esac
done

case ${profile} in
    all|youtube|disney) ;;
    *) echo -e "[${red}Error${plain}] Invalid profile: ${profile}. Valid options: all, youtube, disney" && exit 1 ;;
esac

case ${action} in
    install_all)  install_all ;;
    only_dnsmasq) only_dnsmasq ;;
    only_sniproxy) only_sniproxy ;;
    refresh) refresh_domains ;;
    uninstall)
        hello
        echo -e "${yellow}Uninstalling Dnsmasq and SNI Proxy...${plain}"
        confirm
        undnsmasq
        unsniproxy
        ;;
    undnsmasq)
        hello
        echo -e "${yellow}Uninstalling Dnsmasq...${plain}"
        confirm
        undnsmasq
        ;;
    unsniproxy)
        hello
        echo -e "${yellow}Uninstalling SNI Proxy...${plain}"
        confirm
        unsniproxy
        ;;
    help|"") show_help ;;
esac
