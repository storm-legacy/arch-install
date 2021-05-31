#!/bin/env bash

# ARCH INSTALLATION SCRIPT WITH ENCRYPTION FOR NOTEBOOKS
# AUTHOR: storm-legacy (Github)

# CUSTOMIZATION
_KEYMAP='pl'
_FONT='lat2-16'
_ENCODING='8859-2'
_LOCALE='en_US'
_TIMEZONE='Europe/Warsaw'
_HOSTNAME="NTBK"
_MIRRORS_COUNTRY="Poland" # Information for reflector

# PACMAN PACKAGES
_KERNEL='linux-hardened'
_UCODE='intel-ucode'
_NETWORK_UTILS=(networkmanager dhcpcd smbclient nmap)
_FILESYSTEMS=(fuse ntfs-3g gvfs gvfs-mtp gvfs-smb gvfs-nfs)
_SYSTEM=(tmux htop ntp)
_HARDWARE=(xf86-input-evdev xf86-input-libinput xf86-input-synaptics \
  xf86-video-intel)
_ADMIN_UTILS=(vim sudo rsync man man-db mc lsof)
_AUDIO=(pulseaudio alsa pulseaudio-alsa pulseaudio-equalizer )
_BLUETOOTH=(bluez bluez-utils pulseaudio-bluetooth)
_FONTS=(ttf-roboto ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-hack \
  inter-font)
_INTERNET=(firefox aria2 wget)
_ADDITIONAL_UTILS=(ranger flameshot thunar lm_sensors p7zip unzip unrar)
_DISPLAYMANAGER=(awesome picom)
_XORG_SERVER=(xorg-server xorg-server-common xorg-xauth xorg-xbacklight \
  xorg-xinit xorg-xmessage xorg-xmodmap xorg-xprop xorg-xrdb xorg-xset)
#_USER_APPS=(signal-desktop discord syncthing turtl)

# INSTALLATION SETTINGS
# WITH NVME DRIVES PATTERN IS NOT NECESSARILY OBVIOUS
_DISK='/dev/sda' # or /dev/sdX
_PARTITION_PATTERN='/dev/sda' # e.g. /dev/sda2 => /dev/sda[2] => /dev/sda

# PARTITION SIZES:
_EFI_PART="100M" # must be specified
_ROOT_PART="35G" # must be specified
_HOME_PART="" # will take rest of space
_SWAP_PART="8G" # must be specified

# ENCRYPTION SETTINGS
_CRYPTHOME_NAME="crypthome"
_CRYPTSWAP_NAME="cryptswap"

_INSTALL_DIR='/mnt' # Location for partitions mounting and installation
_LOG_FILE="install.log";
# CUSTOMIZATION END




# ! SCRIPT ZONE
# COLORS DECLARATIONS
declare -A TEXT
TEXT[INFO]="\e[0;94m"
TEXT[ERR]="\e[0;91m"
TEXT[SUCCESS]="\e[0;92m"
TEXT[RESET]="\e[0m"
TEXT[WARN]="\e[0;33m"

# Easier naming scheme for DIRs
declare -A DIR
DIR[EFI]=${_INSTALL_DIR}/boot/efi
DIR[ROOT]=${_INSTALL_DIR}
DIR[HOME]=${_INSTALL_DIR}/home

# Easier naming scheme for partitions
declare -A PART
PART[EFI]=${_PARTITION_PATTERN}1 
PART[ROOT]=${_PARTITION_PATTERN}2
PART[ENCRYPTED_HOME]=${_PARTITION_PATTERN}3
PART[ENCRYPTED_SWAP]=${_PARTITION_PATTERN}4
PART[HOME]=/dev/mapper/${_CRYPTHOME_NAME}
PART[SWAP]=/dev/mapper/${_CRYPTSWAP_NAME}

# GENERATE FULL LOCALE VARIABLE
_LOCALE="${_LOCALE}.UTF-8 UTF-8"

# GET SCRIPT LOCATION
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
_LOG_FILE="$SCRIPT_DIR/$_LOG_FILE";
cd $SCRIPT_DIR

# CREATE LOG FILE
echo -e "\n\n\nInstallation from:" >> $_LOG_FILE
echo -e `date` >> $_LOG_FILE;
echo -e "\n"

# STANDARD ERROR WITH ONE CUSTOM DEFINED STRING
standard_error_check()
{
  if [ "${?}" != "0" ]; then
  local message=${1}
  local exit_code=${2}

  echo -e "${TEXT[ERR]}ERROR"
  echo -e "[ERR] ${message} ${TEXT[RESET]}"
  exit ${exit_code}
  else
    echo -e "${TEXT[SUCCESS]}SUCCESS${TEXT[RESET]}"
  fi
}

# CREATE FSTAB'S BACKUP
# ADJUST FSTAB FILE
# configure encryption/decryption
# configure system
# install yay
# ncpamixer install - https://github.com/fulhax/ncpamixer