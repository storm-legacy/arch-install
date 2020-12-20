#!/bin/bash

# Customization
_KEYMAP='pl'
_FONT='lat2-16'
_ENCODING='8859-2'
_LOCALE='en_US'
_TIMEZONE='Europe/Warsaw'
_HOSTNAME="NTBK"

# PACKAGES
KERNEL='linux-lts' #KERNEL
UCODE='intel-ucode' #MICROCODE
NETWORK=(networkmanager dhcpcd) #NETWORK UTILITIES
ADDITIONAL=(ntfs-3g) #OTHERS

# Disk
_DISK=""
_PART_PATTERN="";


##########DANGER ZONE###########
_SUCCESS="\033[1;32m"
_ERR="\033[0;31m"
_PURPLE="\033[0;35m"
_RESET="\033[0m"

BASE=(base base-devel "${KERNEL}" "${KERNEL}-headers" linux-firmware "${NETWORK[@]}" "${UCODE}" vim efibootmgr man man-db mc sudo ecryptfs-utils rsync lsof ufw "${ADDITIONAL[@]}") #Base
INSTALL_DIR='/mnt'
_USER="credentials.remember-to-delete"

# Locale full name
_LOCALE="${_LOCALE}.UTF-8 UTF-8"

err_check () {
	if ! [ "${?}" == "0" ]; then
		echo -e "${_ERR}[ERR] Error occured! Installation aborted! ${_RESET}"
		exit 1;
	fi
}

echo -e "\n"
echo -e "${_PURPLE} Arch installation script by storm-legacy ${_RESET}";
echo -e "\n"

cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo -e "${_PURPLE}[LOG] Checking disk ${_RESET}"
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${_DISK} > /dev/null 2> /dev/null
	q
EOF

if ! [ "${?}" == "0" ]; then
	echo -e "${_ERR}[ERR] Incorrect storage device!"
	exit 1;
fi

echo -e "${_ERR}[ERR] All data on specified device [${_DISK}] will be erased!${_RESET}"
echo -e "Continue?";
select yn in "Yes" "No"
do
	case $yn in
		Yes ) break;;
		No ) echo -e "Operation aborted!"; exit 0;;
	esac
done

echo -e "${_PURPLE}[LOG] Setting System Clock ${_RESET}"
timedatectl set-ntp true
err_check

echo -e "${_PURPLE}[LOG] Loading keymap and fonts${_RESET}"
loadkeys ${_KEYMAP};
setfont ${_FONT} -m ${_ENCODING}
err_check

echo -e "${_PURPLE}Username: ${_RESET}";
read _USERNAME


echo -e "${_PURPLE}Placeholder password (Change it later):${_RESET}";
read -s _PASSWD
echo -e "${_PURPLE}Confirm password: ${_RESET}";
read -s _CONFIRM

while ! [ "${_PASSWD}" == "${_CONFIRM}" ]
do
	echo -e "${_ERR}[ERR] Passwords do not match!${_RESET}"
	echo -e "${_PURPLE}Placeholder password (Change it later):${_RESET}";
	read -s _PASSWD
	echo -e "${_PURPLE}Confirm password: ${_RESET}";
	read -s _CONFIRM
done

echo "${_USERNAME}:${_PASSWD}" > ${_USER}
_USERNAME=""
_PASSWD=""
_CONFIRM=""


#umount all drives
umount -f $_DISK*;
sleep 1;
umount -l $_DISK*;

if [ -d "/sys/firmware/efi/efivars" ]; then
	echo -e "${_SUCCESS}[SUCCESS] Confirmed UEFI system! ${_RESET}"
else
	echo -e "${_ERR}[ERR] Installation can be proceed only on UEFI systems!${_RESET}"
	exit 1;
fi


echo -e "${_PURPLE}[LOG] Checking internet connection${_RESET}"
curl -I https://aur.archlinux.org >> /dev/null 2> /dev/null
if ! [ "$?" == '0' ]; then
  echo -e "${_ERR}[ERR] Problem with internet connection!${_RESET}"
  exit 1;
else
  echo -e "${_SUCCESS}[SUCCESS] Internet connection confirmed!${_RESET}"
fi

echo -e "${_PURPLE}[LOG] Updating pacman packages list${_RESET}"
pacman -Sy --noconfirm archlinux-keyring;
reflector --verbose --latest 15 --country 'Poland' --sort rate --save /etc/pacman.d/mirrorlist
err_check


echo -e "${_PURPLE}[LOG] Device partitioning ${_RESET}"
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk -w always  ${_DISK}
	g
	n		#new part EFI
	1		#part 1
			#default first sector
	+500M	#efi part size
	t		#type
	1		#EFI System type
	n		#new part ROOT
	2		#part 2
			#default first sector
	+35G	#root Size
	t		#type
	2		#part 2
	20		#Linux filesystem type
	n		#new part Home
	3		#part number 3
			#default first sector
	+60G	#home part size
	t
	3
	20
	w		#save changes to disk
EOF
err_check
echo -e "${_PURPLE}[LOG] Partitions formating ${_RESET}"

mkfs.fat -F32 ${_PART_PATTERN}1;err_check 			#EFI
mkfs.ext4 -F ${_PART_PATTERN}2;err_check			#ROOT + BOOT
mkfs.ext4 -F ${_PART_PATTERN}3;err_check			#HOME

echo -e "${_PURPLE}[LOG] Mounting partitions ${_RESET}"
mount ${_PART_PATTERN}2 ${INSTALL_DIR}
mkdir -p "${INSTALL_DIR}/boot"
mount ${_PART_PATTERN}1 "${INSTALL_DIR}/boot"
mkdir -p "${INSTALL_DIR}/home"
mount ${_PART_PATTERN}3 "${INSTALL_DIR}/home"

echo -e "${_PURPLE}[LOG] Creating swapfile ${_RESET}"
RAM_SIZE=$(expr `cat /proc/meminfo |grep MemTotal | cut -d":" -f2 | cut -d"k" -f1` / 1024 \* 15 / 10)
dd if=/dev/zero of=${INSTALL_DIR}/swapfile bs=1M count=${RAM_SIZE} status=progress
chmod 600 ${INSTALL_DIR}/swapfile
mkswap ${INSTALL_DIR}/swapfile
swapon ${INSTALL_DIR}/swapfile

echo -e "${_PURPLE}[LOG] System installation ${_RESET}"
pacstrap ${INSTALL_DIR} ${BASE[@]}
err_check

echo -e "${_PURPLE}[LOG] FSTAB file generation ${_RESET}"
genfstab -U ${INSTALL_DIR} >> ${INSTALL_DIR}/etc/fstab

echo -e "${_PURPLE}[LOG] Generating arch-chroot configuration script ${_RESET}"
mv ${_USER} ${INSTALL_DIR}/root/${_USER} #move user-credentials to chroot
_USERNAME=`cat ${INSTALL_DIR}/root/${_USER} | cut -d":" -f1`
BOOT_ITEMS=(`efibootmgr | grep -e "^Boot....[* ]" | cut -c 5-8`)
cat > ${INSTALL_DIR}/root/install-script.sh  << EOF
#!/bin/bash
err_check () {
	if ! [ "${?}" == "0" ]; then
		echo -e "${_ERR}[ERR] Error occured! Installation aborted! ${_RESET}"
		exit 1;
	fi
}
cd "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo -e "${_PURPLE}[LOG] Setting up timezone [${_TIMEZONE}] ${_RESET}"
ln -sf /usr/share/zoneinfo/${_TIMEZONE} /etc/localtime
err_check

echo -e "${_PURPLE}[LOG] Setting up system time ${_RESET}"
hwclock --systohc
err_check

echo -e "${_PURPLE}[LOG] Generating locales [${_LOCALE}]${_RESET}"
cp /etc/locale.gen /etc/locale.gen.bak
echo "#Original file location is /etc/locale.gen.bak" > /etc/locale.gen
echo "${_LOCALE}" >> /etc/locale.gen
locale-gen
echo "KEYMAP=${_KEYMAP}" > /etc/vconsole.conf
echo "FONT=${_FONT}" >> /etc/vconsole.conf

echo -e "${_PURPLE}[LOG] Setting up hostname [${_HOSTNAME}]${_RESET}"
echo $_HOSTNAME > /etc/hostname

echo -e "${_PURPLE}[LOG] Setting up host file ${_RESET}"
echo "127.0.0.1 localhost" > /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 ${_HOSTNAME}.localdomain ${_HOSTNAME}" >> /etc/hosts

echo -e "${_PURPLE}[LOG] Creating administrator group${_RESET}"
groupadd admin
echo "%admin ALL=(ALL) ALL" > /etc/sudoers.d/admin
err_check

echo -e "${_PURPLE}[LOG] Setting up user and password [${_USERNAME}]${_RESET}"
useradd -m -G admin ${_USERNAME}
cat ${_USER} | chpasswd
rm -f ${_USER}
err_check

echo -e "${_PURPLE}[LOG] Cleaning Boot Manager${_RESET}"
for i in "${BOOT_ITEMS[@]}"
do
	efibootmgr -b "\$i" -B
done

echo -e "${_PURPLE}[LOG] Bootloader configuration${_RESET}"
bootctl install
err_check

cat > /boot/loader/loader.conf << EOF1
	deafult		default.conf
	timeout 		0
	console-mode	max
	editor		no
EOF1

cat > /boot/loader/entries/default.conf << EOF2
	title   Arch
	linux   /vmlinuz-${KERNEL}
	initrd  /${UCODE}.img
	initrd  /initramfs-${KERNEL}.img
	options root=\`blkid | grep ${_PART_PATTERN}2 | cut -d' ' -f2 | sed 's/\"//g'\` rw
EOF2
 
rm ./install-script.sh
EOF
arch-chroot ${INSTALL_DIR} /bin/bash -c "bash /root/install-script.sh";

#TODO link to system customization script

cat > ${INSTALL_DIR}/root/desk-install.sh << EOF
echo 'yeiks'
mv /home/${_USERNAME}/.bashrc.bak /home/${_USERNAME}/.bashrc
rm /root/desk-install.sh
EOF

# Backup bashrc
if [ -f "${INSTALL_DIR}/home/${_USERNAME}/.bashrc" ]; then
	cp ${INSTALL_DIR}/home/${_USERNAME}/.bashrc ${INSTALL_DIR}/home/${_USERNAME}/.bashrc.bak
	arch-chroot ${INSTALL_DIR} /bin/bash -c "chown ${_USERNAME}:${_USERNAME} /home/${_USERNAME}/.bashrc.bak"
fi

cat >> ${INSTALL_DIR}/home/${_USERNAME}/.bashrc << EOF
echo -e "\n${_PURPLE}[INFO] After establishing network connection continue installation with:"
echo -e "${_PURPLE}installdesk${_RESET}\n"
alias installdesk="sudo bash /root/desk-install.sh"
EOF
arch-chroot ${INSTALL_DIR} /bin/bash -c "chown ${_USERNAME}:${_USERNAME} /home/${_USERNAME}/.bashrc"

reboot;
