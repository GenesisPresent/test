#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} โปรดรันสคริปต์ด้วยคำสั่งผู้ใช้ root \n " && exit 1

# Check OS and set release variable
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    release=$ID
elif [[ -f /usr/lib/os-release ]]; then
    source /usr/lib/os-release
    release=$ID
else
    echo "ไม่สามารถตรวจสอบระบบปฏิบัติการของระบบได้โปรดติดต่อผู้ดูแล!" >&2
    exit 1
fi
echo "The OS release is: $release"

arch3xui() {
    case "$(uname -m)" in
    x86_64 | x64 | amd64) echo 'amd64' ;;
    armv8 | arm64 | aarch64) echo 'arm64' ;;
    *) echo -e "${green}ไม่รองรับ CPU สถาปัตยกรรม! ${plain}" && rm -f install.sh && exit 1 ;;
    esac
}
echo "arch: $(arch3xui)"

os_version=""
os_version=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)

if [[ "${release}" == "centos" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}รองรับ CentOS 8 หรือสูงกว่านี้ ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "${red}รองรับ Ubuntu 20 หรือสูงกว่านี้ version!${plain}\n" && exit 1
    fi

elif [[ "${release}" == "fedora" ]]; then
    if [[ ${os_version} -lt 36 ]]; then
        echo -e "${red}รองรับ Fedora 36 หรือสูงกว่านี้ version!${plain}\n" && exit 1
    fi

elif [[ "${release}" == "debian" ]]; then
    if [[ ${os_version} -lt 10 ]]; then
        echo -e "${red}รองรับ Debian 10 หรือสูงกว่านี้ ${plain}\n" && exit 1
    fi
elif [[ "${release}" == "arch" ]]; then
    echo "OS is ArchLinux"

else
    echo -e "${red}ไม่สามารถตรวจสอบเวอร์ชันของระบบปฏิบัติการได้ !${plain}" && exit 1
fi

install_base() {
    case "${release}" in
        centos|fedora)
            yum install -y -q wget curl tar
            ;;
        arch)
            pacman -Syu --noconfirm wget curl tar
            ;;
        *)
            apt install -y -q wget curl tar
            ;;
    esac
}


# This function will be called when user installed x-ui out of security
config_after_install() {
    echo -e "${yellow}Install/update สำเร็จแล้ว! เพื่อความปลอดภัย ขอแนะนำให้แก้ไขการตั้งค่าแผงควบคุม ${plain}"
    read -p "Confirm [y/n]? ": config_confirm
    if [[ "${config_confirm}" == "y" || "${config_confirm}" == "Y" ]]; then
        read -p "Set username login:" config_account
        echo -e "${yellow}Username คุณคือ: ${config_account}${plain}"
        read -p "Set password login:" config_password
        echo -e "${yellow}Password คุณคือ: ${config_password}${plain}"
        read -p "Set webpanel port:" config_port
        echo -e "${yellow}webpanel พอร์ตคือ: ${config_port}${plain}"
        echo -e "${yellow}กำลังติดตั้ง โปรดรอสักครู่...${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}ตั้งชื่อบัญชีและรหัสผ่านสำเร็จแล้ว!${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}ตั้งค่าพอร์ต webpanel เรียบร้อยแล้ว!${plain}"
    else
        echo -e "${red}cancel...${plain}"
        if [[ ! -f "/etc/x-ui/x-ui.db" ]]; then
            local usernameTemp=$(head -c 6 /dev/urandom | base64)
            local passwordTemp=$(head -c 6 /dev/urandom | base64)
            /usr/local/x-ui/x-ui setting -username ${usernameTemp} -password ${passwordTemp}
            echo -e "นี่เป็นการติดตั้งใหม่ จะสร้างข้อมูลการเข้าสู่ระบบแบบสุ่มเพื่อความปลอดภัย:"
            echo -e "###############################################"
            echo -e "${green}username:${usernameTemp}${plain}"
            echo -e "${green}password:${passwordTemp}${plain}"
            echo -e "###############################################"
            echo -e "${red}หากคุณลืมข้อมูลการเข้าสู่ระบบ คุณสามารถพิมพ์ x-ui จากนั้นพิมพ์ 7 เพื่อตรวจสอบหลังการติดตั้ง${plain}"
        else
            echo -e "${red}นี่คือการอัปเกรดของคุณ จะเก็บการตั้งค่าเก่าไว้ หากคุณลืมข้อมูลการเข้าสู่ระบบ คุณสามารถพิมพ์ x-ui แล้วพิมพ์ 7 เพื่อตรวจสอบ${plain}"
        fi
    fi
    /usr/local/x-ui/x-ui migrate
}

install_x-ui() {
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/MHSanaei/3x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to fetch x-ui version, it maybe due to Github API restrictions, please try it later${plain}"
            exit 1
        fi
        echo -e "Got x-ui latest version: ${last_version}, beginning the installation..."
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch3xui).tar.gz https://github.com/MHSanaei/3x-ui/releases/download/${last_version}/x-ui-linux-$(arch3xui).tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Downloading x-ui failed, please be sure that your server can access Github ${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/MHSanaei/3x-ui/releases/download/${last_version}/x-ui-linux-$(arch3xui).tar.gz"
        echo -e "Begining to install x-ui $1"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-$(arch3xui).tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui $1 failed,please check the version exists ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        systemctl stop x-ui
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-$(arch3xui).tar.gz
    rm x-ui-linux-$(arch3xui).tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-$(arch3xui)
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/MHSanaei/3x-ui/main/x-ui.sh
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "If it is a new installation, the default web port is ${green}2053${plain}, The username and password are ${green}admin${plain} by default"
    #echo -e "Please make sure that this port is not occupied by other procedures,${yellow} And make sure that port 2053 has been released${plain}"
    #    echo -e "If you want to modify the 2053 to other ports and enter the x-ui command to modify it, you must also ensure that the port you modify is also released"
    #echo -e ""
    #echo -e "If it is updated panel, access the panel in your previous way"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${last_version}${plain} การติดตั้งเสร็จสิ้น..."
    echo -e ""
    echo -e "x-ui เมนูคำสั่งใช้งานผ่าน VPS: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Enter     เปิดเมนู.   "
    echo -e "x-ui start        - เปิดใช้งาน   "
    echo -e "x-ui stop         - ปิดใช้งาน      "
    echo -e "x-ui restart      - รีสตาร์ท  "
    echo -e "x-ui status       - แสดงสถานะ   "
    echo -e "x-ui enable       - เปิดเซอร์วิส x-ui ในการเริ่มต้นระบบ"
    echo -e "x-ui disable      - ปิดเซอร์วิส x-ui ในการเริ่มต้นระบบ"
    echo -e "x-ui log          - ข้อมูล.  "
    echo -e "x-ui banlog       - เช็ค Fail2ban ban logs"
    echo -e "x-ui update       - อัปเดต x-ui"
    echo -e "x-ui install      - ติดตั้ง x-ui"
    echo -e "x-ui uninstall    - ถอนติดตั้ง x-ui"
    echo -e "----------------------------------------------"
}

echo -e "${green}Running...${plain}"
install_base
install_x-ui $1
