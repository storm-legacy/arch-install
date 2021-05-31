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

# COMBINE PACKAGES:
APP_PACKAGE=(base base-devel cryptsetup linux-firmware efibootmgr \
  "${_KERNEL}" "${_KERNEL}-headers" "${_UCODE}" "${_NETWORK_UTILS[@]}" \
  "${_FILESYSTEMS[@]}" "${_SYSTEM[@]}" "${_HARDWARE[@]}" "${_ADMIN_UTILS[@]}" \
  "${_AUDIO[@]}" "${_BLUETOOTH[@]}" "${_FONTS[@]}" "${_INTERNET[@]}" \
  "${_ADDITIONAL_UTILS[@]}" "${_DISPLAYMANAGER[@]}" "${_XORG_SERVER[@]}")

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

# CHECK FOR UEFI
echo -ne "${TEXT[INFO]}[LOG] Checking UEFI..."
if [ -d "/sys/firmware/efi/efivars" ];
then
  echo -e "${TEXT[SUCCESS]}SUCCESS${TEXT[RESET]}"
else
  echo -e "${TEXT[ERR]}ERROR"
	echo -e "[ERR] Installation can be proceed only on UEFI systems!${TEXT[RESET]}"
	exit 2;
fi

# CHECK IF PROPER DISK IS SPECIFIED
echo -ne "${TEXT[INFO]}[LOG] Checking disk..."
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${_DISK} >> $_LOG_FILE 2>&1;
	q
EOF
standard_error_check "Incorrect storage device!" 3

# CHECK INTERNET CONNECTION
echo -ne "${TEXT[INFO]}[LOG] Checking internet connection..."
curl -I https://aur.archlinux.org >> /dev/null 2> /dev/null;
standard_error_check "Problem with internet connection!" 4


# CHECK USERNAME
echo -ne "${TEXT[INFO]}[LOG] Validating linux username..."
_USERNAME=`echo $1 | sed -e 's/^[[:space:]]*//'` # trimm 
VALID_USERNAME=0

ask_username()
{
  echo -ne "\n${TEXT[INFO]}USERNAME: ";
  read _USERNAME
}

check_username()
{
  if ! [[ "$_USERNAME" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]
  then
    echo -e "${TEXT[ERR]}ERROR"
    echo -e "[ERR] It is not a proper linux username!${TEXT[RESET]}"

    VALID_USERNAME=0
  else
    VALID_USERNAME=1
    echo -e "${TEXT[SUCCESS]}SUCCESS${TEXT[RESET]}"
  fi
}

if [[ -z $_USERNAME ]] #check if empty
then
  ask_username
  check_username
  while [ "$VALID_USERNAME" != 1 ]
  do
    ask_username
    check_username
  done

else
  check_username
  while [ "$VALID_USERNAME" != 1 ]
  do
    ask_username
    check_username
  done
fi

# GET USER AGREEMENT
echo -e "\n${TEXT[WARN]}[IMPORTANT INFORMATION]"
echo -e "All data on specified device ${TEXT[SUCCESS]}[${_DISK}]${TEXT[WARN]} will be erased!"
echo -e "${TEXT[WARN]}Your ${TEXT[INFO]}PASSWORD ${TEXT[WARN]} will be the same as your ${TEXT[INFO]}USERNAME${TEXT[WARN]}"
echo -e "It is strongly advised to change it later via attached script!"
echo -e "\nUSERNAME: ${TEXT[SUCCESS]}${_USERNAME}"
echo -e "\n${TEXT[INFO]}Do you wish do proceed?${TEXT[RESET]}"
select yn in "Yes, I do." "No, take me back."
do
	case $yn in
		"Yes, I do." ) break;;
		"No, take me back.") echo -e "Installation aborted!${TEXT[RESET]}"; exit 1;;
    *) echo -e "${TEXT[INFO]}Type either [1] or [2].";;
	esac
done

# SETUP NTP FOR INSTALLATION
echo -ne "${TEXT[INFO]}[LOG] Setting up NTP for installation..."
timedatectl set-ntp true >> $_LOG_FILE 2>&1;
standard_error_check "Problem with set-ntp!" 5

# LOAD KEYMAP AND FONTS FOR INSTALLATION
echo -ne "${TEXT[INFO]}[LOG] Loading keymap and fonts..."
loadkeys ${_KEYMAP} >> $_LOG_FILE 2>&1;
setfont ${_FONT} -m ${_ENCODING} >> $_LOG_FILE 2>&1;
if [ "${?}" != "0" ];
then
  echo -e "${TEXT[ERR]}ERROR"
  echo -e "[ERR] Problem with loading keymap or/and fonts!${TEXT[RESET]}"
  exit 6
else
  echo -e "${TEXT[SUCCESS]}SUCCESS"
  echo -e "${TEXT[INFO]}\tKEYMAP: ${TEXT[RESET]}${_KEYMAP}"
  echo -e "${TEXT[INFO]}\tFONT: ${TEXT[RESET]}${_FONT} ${_ENCODING}"
fi


# UPDATE PACMAN PACKAGES LIST
echo -ne "${TEXT[INFO]}[LOG] Refreshing archlinux-keyring..."
/bin/pacman -Sy --noconfirm archlinux-keyring >> $_LOG_FILE 2>&1;
standard_error_check "Problem occured when updating keyring and/or mirrorlist!" 7

echo -ne "${TEXT[INFO]}[LOG] Updating mirrorlist via reflector..."
/bin/reflector --latest 5 --country $_MIRRORS_COUNTRY --sort rate --save /etc/pacman.d/mirrorlist >> $_LOG_FILE 2>&1
standard_error_check "Problem occured when updating keyring and/or mirrorlist!" 7


# TODO UNMOUNT CHECK //8
# UMOUNT ALL DRIVES
umount -f ${DIR[ROOT]} >> $_LOG_FILE 2>&1
sleep 1;
umount -l ${DIR[ROOT]} >> $_LOG_FILE 2>&1

# AND SWAP
umount -f ${PART[SWAP]} >> $_LOG_FILE 2>&1
sleep 1;
umount -l ${PART[SWAP]} >> $_LOG_FILE 2>&1

# CLOSE ENCRYPTED DEVICES IF OPENED
/bin/cryptsetup close ${_CRYPTHOME_NAME} >> $_LOG_FILE 2>&1
/bin/cryptsetup close ${_CRYPTSWAP_NAME} >> $_LOG_FILE 2>&1


# CHECK IF PACKAGES EXIST IN REPOSITORY
echo -ne "${TEXT[INFO]}[LOG] Confirming packages in repository...";
ERR=0;

for i in ${APP_PACKAGE[@]}; do
  /bin/pacman -Ss "^$i$" >> $_LOG_FILE 2>&1
  if [[ "$?" != "0" ]]; then ERR=1; fi
done

if [ "$ERR" ==  "1" ];
then
  echo -e "${TEXT[ERR]} ERROR"
  echo -e "[ERR] Missing repository packages!${TEXT[RESET]}"
  exit 9
else
  echo -e "${TEXT[SUCCESS]}SUCCESS${TEXT[RESET]}"
fi

# CHECK FOR INSTALLATION FOLDER
echo -ne "${TEXT[INFO]}[LOG] Checking installation directory [${_INSTALL_DIR}]...";
# check if folder exists
if ! [[ -d ${_INSTALL_DIR} ]]
then
  echo -e "${TEXT[ERR]} ERROR"
  echo -e "${TEXT[WARN]}[WARN] Missing installation directory [${_INSTALL_DIR}]"
  echo -e "Do you want to make that directory?${TEXT[RESET]}"
  select yn in "Yes, make a directory." "No, cancel installation."
  do
    case $yn in
      "Yes, make a directory." ) mkdir -p ${_INSTALL_DIR};;
      "No, cancel installation." ) echo -e "Installation aborted!${TEXT[RESET]}"; exit 1;;
      * ) echo -e "${TEXT[INFO]}Type either [1] or [2].";;
    esac
  done
else
  echo -e "${TEXT[SUCCESS]}SUCCESS${TEXT[RESET]}"
fi

# PARTITIONING
echo -ne "${TEXT[INFO]}[LOG] Partitioning device [$_DISK]..."
sed -e 's/\s*\([-\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk -w always ${_DISK} >> $_LOG_FILE 2>&1
	g
	n		#new part EFI     -- EFI PART
	1		#part 1
			#default first sector
	+${_EFI_PART}	#efi part size
	t		#type
	1		#EFI System type
	n		#new part ROOT    -- ROOT PART
	2		#part 2
			#default first sector
	+${_ROOT_PART}	#root Size
	t		#type
	2		#part 2
	23	#rootfs
	n		#new part Home    -- HOME PART
	3		#part number 3
			#default first sector
	-${_SWAP_PART}	#home part size
	t   	#type
	3   	#part 3
	28  	#homefs
	n   	#new              -- SWAP PART
	4   	#part 4
			#default first sector
			#rest of space
	t   	#type
	4   	#part 4
	19  	#linux swap
	w		#save changes to disk
EOF
standard_error_check "Problem occured while partitioning!" 10

# ENCRYPTING PARTITIONS
# encrypting home partition
echo -ne "${TEXT[INFO]}[LOG] Encrypting home partition..."
echo $_USERNAME | /bin/cryptsetup -q -h sha512 -i 2500 -s 512 luksFormat ${PART[ENCRYPTED_HOME]} >> ${_LOG_FILE} 2>&1
standard_error_check "Problem occured while encrypting home partition!" 11

# encrypting swap partition
echo -ne "${TEXT[INFO]}[LOG] Encrypting swap partition..."
echo $_USERNAME | /bin/cryptsetup -q -h sha512 -i 2500 -s 512 luksFormat ${PART[ENCRYPTED_SWAP]} >> ${_LOG_FILE} 2>&1
standard_error_check "Problem occured while encrypting swap partition!" 11


# OPENING ENCRYPTED DEVICES
echo -ne "${TEXT[INFO]}[LOG] Opening encrypted home partition..."
echo $_USERNAME | /bin/cryptsetup open ${PART[ENCRYPTED_HOME]}  ${_CRYPTHOME_NAME} >> ${_LOG_FILE} 2>&1 #home partition
standard_error_check "Problem occured while opening encrypted home partition!" 12

echo -ne "${TEXT[INFO]}[LOG] Opening encrypted swap partition..."
echo $_USERNAME | /bin/cryptsetup open ${PART[ENCRYPTED_SWAP]}  ${_CRYPTSWAP_NAME} >> ${_LOG_FILE} 2>&1 #swap partition
standard_error_check "Problem occured while opening encrypted swap partition!" 12


# FORMATTING PARTITIONS
# efi
echo -ne "${TEXT[INFO]}[LOG] Formating EFI partition..."
mkfs.vfat ${PART[EFI]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while formatting efi partition!" 13
# root
echo -ne "${TEXT[INFO]}[LOG] Formating root partition..."
mkfs.ext4 ${PART[ROOT]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while formatting root partition!" 13
# home
echo -ne "${TEXT[INFO]}[LOG] Formating home partition..."
mkfs.ext4 ${PART[HOME]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while formatting home partition!" 13
#swap
echo -ne "${TEXT[INFO]}[LOG] Formating swap partition..."
mkswap ${PART[SWAP]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while formatting swap partition!" 13

# MOUNTING PARTITIONS
# root
echo -ne "${TEXT[INFO]}[LOG] Mounting root partition..."
mount ${PART[ROOT]} ${DIR[ROOT]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while mounting root partition!" 14
# efi
echo -ne "${TEXT[INFO]}[LOG] Mounting efi partition..."
mkdir -p ${DIR[EFI]} >> ${_LOG_FILE} 2>&1
mount ${PART[EFI]} ${DIR[EFI]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while mounting efi partition!" 14
# home
echo -ne "${TEXT[INFO]}[LOG] Mounting home partition..."
mkdir -p ${DIR[HOME]} >> ${_LOG_FILE} 2>&1
mount ${PART[HOME]} ${DIR[HOME]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while mounting home partition!" 14
# swap
echo -ne "${TEXT[INFO]}[LOG] Enabling swap partition..."
swapon ${PART[SWAP]} >> ${_LOG_FILE} 2>&1
standard_error_check "Encountered problem while enabling swap partition!" 14


# SYSTEM INSTALLATION
echo -ne "${TEXT[INFO]}[LOG] System installation...${TEXT[WARN]}STARTED"
echo -e "${TEXT[INFO]}"
pacstrap ${DIR[ROOT]} ${APP_PACKAGE} | tee $_LOG_FILE
standard_error_check "Encountered errors while installing system!" 15

# ncpamixer install - https://github.com/fulhax/ncpamixer