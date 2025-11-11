#!/bin/sh

#if [[ $EUID -ne 0 ]]; then
#    clear
#   echo "Error: This script must be run as root!" 1>&2
#    exit 1
#fi

if [ -f "/usr/bin/yum" ] && [ -d "/etc/yum.repos.d" ]; then
    yum update -y
    yum install -y wget curl
    
elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
    apt-get update --fix-missing
    apt install -y curl wget
    
fi

function CopyRight() {
  clear
  echo "########################################################"
  echo "#                                                      #"
  echo "#               Auto Reinstall Script                  #"
  echo "#                                                      #"
  echo "#               Author: AKUMAVM                        #"
  echo "#               Last Modified: 11-11-2025              #"
  echo "#                                                      #"
  echo "#               Inspired by bin456789                  #"
  echo "#                                                      #"
  echo "########################################################"
  echo -e "\n"
}

function Start() {
  CopyRight
  
curl -O https://raw.githubusercontent.com/AKUMAVM/launch/main/mark.sh || wget -O mark.sh $_


  echo -e "\nPlease select an OS:"
  echo "  1) Latest Debian"
  echo "  2) Latest Ubuntu"
  echo "  3) Latest Almalinux"
  echo "  4) Latest Alpine Linux"
  echo "  5) Latest CentOS"
  echo "  6) Kali Linux"
  echo "  7) Windows 10 Pro"
  echo "  8) Windows 11 Pro"
  echo "  9) Windows Server 2012 R2 DC"
  echo "  10) Windows Server 2016 DC"
  echo "  11) Windows Server 2019 DC"
  echo "  12) Windows Server 2022 DC"
  echo "  13) Windows Server 2025 DC"
  echo "  14) Windows 10 Pro Lite"
  echo "  15) Windows 11 Pro Lite"
  echo "  16) Netboot"
  echo "  99) Custom DD image"
  echo "  0) Exit"
  echo -ne "\nYour option: "
  read N
  case $N in
    1) bash mark.sh debian --password 123@@@ ;;
    2) bash mark.sh ubuntu --password 123@@@ ;;
    3) bash mark.sh alma --password 123@@@ ;;
    4) bash mark.sh alpine --password 123@@@ ;;
    5) bash mark.sh centos --password 123@@@ ;;
    6) bash mark.sh kali --password 123@@@ ;;
    7) bash mark.sh windows --image-name='Windows 10 Pro' --iso='https://iso.akumavm.com/win10-new.iso' --password Akuma12345 --allow-ping ;;
    8) bash mark.sh windows --image-name='Windows 11 Pro' --iso='https://iso.akumavm.com/win11.iso' --password Akuma12345 --allow-ping ;;
    9) bash mark.sh windows --image-name='Windows Server 2012 R2 SERVERDATACENTER' --iso='https://go.microsoft.com/fwlink/p/?LinkID=2195443' --password Akuma12345 --allow-ping ;;
    10) bash mark.sh windows --image-name='Windows Server 2016 SERVERDATACENTER' --iso='https://go.microsoft.com/fwlink/p/?LinkID=2195174' --password Akuma12345 --allow-ping ;;
    11) bash mark.sh windows --image-name='Windows Server 2019 SERVERDATACENTER' --iso='https://go.microsoft.com/fwlink/p/?LinkID=2195167' --password Akuma12345 --allow-ping ;;
    12) bash mark.sh windows --image-name='Windows Server 2022 SERVERDATACENTER' --iso='https://go.microsoft.com/fwlink/p/?LinkID=2195280' --password Akuma12345 --allow-ping ;;
    13) bash mark.sh windows --image-name='Windows Server 2025 SERVERDATACENTER' --iso='https://go.microsoft.com/fwlink/p/?LinkID=2293312' --password Akuma12345 --allow-ping ;;
    14) bash mark.sh windows --image-name='Windows 10 Pro' --iso='https://iso.akumavm.com/tiny10.iso' --password Akuma12345 --allow-ping ;;
    15) bash mark.sh windows --image-name='Windows 11 Pro' --iso='https://iso.akumavm.com/tiny11.iso' --password Akuma12345 --allow-ping ;;
    16) bash mark.sh netboot.xyz ;;
    99)
      echo -e "\n"
      read -r -p "Custom DD image URL: " imgURL
      echo -e "\n"
      read -r -p "Are you sure start reinstall? [y/N]: " input
      case $input in
        [yY][eE][sS]|[yY]) bash mark.sh dd --img $imgURL ;;
        *) clear; echo "Canceled by user!"; exit 1;;
      esac
      ;;
    0) exit 0;;
    *) echo "Wrong input!"; exit 1;;
esac
}
Start
