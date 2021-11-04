#!/bin/sh
########################################################
########################################################
##    Eugene-Paul-Jean-Archlinux-Installer            ##
##                   E-P-J-A-I                        ##
##                        04/November/2021            ##
##    author   :  EPJ                                 ##
##    license  :  ohleck                              ##
##    projet   :  https://github.com/eugenepauljean   ##
########################################################
# VERIFY THE BOOT MODE #################################
check_bootmode () {
    if [[ -d "/sys/firmware/efi/efivars" ]]
    then
        echo -e "${BLU}VERIFY THE BOOT MODE :         GPT"
        bootvar=gpt
    else
        echo -e "{$BLU}VERIFY THE BOOT MODE :         BIOS"
        bootvar=msdos
    fi
}

# CONNECT TO THE INTERNET #################
check_network () {
    if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
        echo -e "${BLU}Check Network Connectivity :   ONLINE"
    else
        echo -e "${BLU}Check Network Connectivity :   OFFLINE"
        echo -e "${RED}Error : Verify NETWORK and retry"
        exit 1
    fi
}

# UPDATE THE SYSTEM CLOCK #################
update_systemclock () {
        timedatectl set-ntp true
        hwclock --systohc
        echo -e "${BLU}Update the system clock :      OK${NC}"
}

# PARTITION THE DISK ######################
check_diskname () {
        clear
        fdisk -l | grep "Disk \/dev\/"
        echo ""
        echo -e "${GRE}ENTER THE TARGET DISKNAME (sda, sdb, vda, nvme0n1...) : ${NC}"
        read disknametarget
}

# DELETE PARTITION TABLE SIGNATURE
erase_disk () {
        clear
        echo -e "${RED}WARNING : "
        echo -e "Be careful, you will erase the content of your hard drive to install Archlinux${GRE}"
        read -p "Are you sure you want to continue? < Yes / No > ? " prompt
    if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" || $prompt == "YES" ]] ; then
        wipefs -a /dev/$disknametarget
        echo "${BLU}Partition table signature wipe off : OK${NC}"
    else
        exit 0
    fi
}

# ENCRYPTED DISK OR NOT
encrypted_choice () {
        clear
        read -p "DO YOU WANT TO USE DISK ENCRYPTION ? < Yes / No > ? " prompt
        echo -e "${NC}"
    if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" || $prompt == "YES" ]] ; then
        encrypteddisk=yes
        create_partition_encrypted
    else
        encrypteddisk=no
        create_partition
    fi
}

# CREATE NEW PARTITION TABLE (ENCRYPTED)
create_partition_encrypted () {
    if [[ $bootvar == "gpt" ]] ; then
        parted -s /dev/$disknametarget mklabel gpt
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart fat32 1MiB 150MiB
        parted -s /dev/$disknametarget set 1 esp
        parted -s /dev/$disknametarget mkpart ext4 150MiB 300MiB
        parted -s /dev/$disknametarget mkpart ext4 300MiB 100%
        cryptsetup luksFormat /dev/${disknametarget}${part3}
        echo -e "${GRE}Mounting the encrypted partition${NC}"
        cryptsetup open /dev/${disknametarget}${part3} cryptroot
        mkfs.vfat /dev/${disknametarget}${part1}
        mkfs.ext4 /dev/${disknametarget}${part2}
        mkfs.ext4 -L root /dev/mapper/cryptroot
        mount /dev/mapper/cryptroot /mnt
        mkdir -p /mnt/boot
        mount /dev/${disknametarget}${part2} /mnt/boot
        mkdir /mnt/boot/efi
        mount /dev/${disknametarget}${part1} /mnt/boot/efi
    elif [[ $bootvar == "msdos" ]] ; then
        parted -s /dev/$disknametarget mklabel msdos
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart primary ext4 1MiB 150MiB
        parted -s /dev/$disknametarget mkpart primary ext4 150Mib 100%
        cryptsetup luksFormat /dev/${disknametarget}${part2}
        echo -e "${GRE}Mounting the encrypted partition${NC}"
        cryptsetup open /dev/${disknametarget}${part2} cryptroot
        mkfs.vfat /dev/${disknametarget}${part1}
        mkfs.ext4 -L root /dev/mapper/cryptroot
        mount /dev/mapper/cryptroot /mnt
        mkdir -p /mnt/boot
        mount /dev/${disknametarget}${part1} /mnt/boot
    fi
}

# CREATE NEW PARTITION TABLE (CLASSIC)
create_partition () {
    if [[ $bootvar == "gpt" ]] ; then
        parted -s /dev/$disknametarget mklabel gpt
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart primary fat32 1MiB 150MiB
        parted -s /dev/$disknametarget mkpart primary ext4 150MiB 100%
        mkfs.vfat /dev/${disknametarget}${part1}
        mkfs.ext4 /dev/${disknametarget}${part2}
        mount /dev/${disknametarget}${part2} /mnt
        mkdir -p /mnt/boot/efi
        mount /dev/${disknametarget}${part1} /mnt/boot/efi
    elif [[ $bootvar == "msdos" ]] ; then
        parted -s /dev/$disknametarget mklabel msdos
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart primary ext4 1MiB 150MiB
        parted -s /dev/$disknametarget mkpart primary 150MiB 100%
        mkfs.ext4 /dev/${disknametarget}${part1}
        mkfs.ext4 /dev/${disknametarget}${part2}
        mount /dev/${disknametarget}${part2} /mnt
        mkdir -p /mnt/boot
        mount /dev/${disknametarget}${part1} /mnt/boot
    fi
}

# ENTER THE USERNAME
enter_username () {
        clear
        echo -e "${GRE}Create the username : ${NC}"
        read username
}

# SELECT MIRRORS
select_mirrors () {
        echo "Server = http://ftp-stud.hs-esslingen.de/pub/Mirrors/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
}

# INSTALL ESSENTIAL PACKAGES
essential_packages () {
        pacstrap /mnt base linux linux-firmware grub
}

# DETECT CPU  (intel or amd)
detect_cpu () {
        varcpu="`grep -m 1 'model name' /proc/cpuinfo | grep -oh "Intel"`"
    if [[ $varcpu == "Intel" ]] ; then
        pacstrap /mnt intel-ucode
    else
        pacstrap /mnt amd-ucode
    fi
}

# GENERATE AN FSTAB WITH UUID
generate_fstab () {
        genfstab -U /mnt >> /mnt/etc/fstab
}

# SET THE TIMEZONE
set_timezone () {
        clear
        echo -e "${GRE}-- SET THE TIMEZONE${BLU}"
        ls -C /usr/share/zoneinfo/
        echo -e "${GRE}   ENTER THE REGION : ${NC}"
        echo -e "${BLU}   (examples : Europe  Australia  Africa  Hongkong  Mexico ....)${NC}"
        read tzregion
        echo -e "${BLU}"
        clear
        ls -C /usr/share/zoneinfo/$tzregion
        echo -e "${GRE}   ENTER THE CITY : ${NC}"
        echo -e "${BLU}   (examples :  Paris   Oslo   Sofia   Kiev ....)${NC}"
        read tzcity
        arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/$tzregion/$tzcity /etc/localtime"
}

# LOCALIZATION
set_localization () {
        clear
        echo -e "${GRE}-- SEARCH THE LOCALES"
        echo -e "${BLU}   (examples :  fr_FR   en_US   de_DE   ca_FR   en_CA ....)${NC}"
        echo ""
        read searchlocaleUTF
        clear
        cat /mnt/etc/locale.gen | awk '{if (NR>=24) print}' | grep UTF-8 | grep $searchlocaleUTF | sed 's/^.\{1\}//'
        echo -e "${GRE}   ENTER THE LOCALE : "
        echo -e "${BLU}   (examples :  fr_FR.UTF-8 UTF-8    it_IT.UTF-8 UTF-8    en_US.UTF-8 UTF-8....${NC}"
        echo ""
        read setlocaleUTF
        sed -i "s|#$setlocaleUTF|$setlocaleUTF|g" /mnt/etc/locale.gen
        arch-chroot /mnt bash -c "locale-gen"

# CREATE locale.conf and set the LANG variable
        setlocaleconf="`echo $setlocaleUTF | awk '{print $1}'`"
        arch-chroot /mnt bash -c "echo 'LANG=$setlocaleconf' >> /etc/locale.conf"

# Create vconsole.conf and set keyboard layout
        clear
        echo -e "${GRE}-- SET THE CONSOLE KEYBOARD LAYOUT${NC}"
        echo -e "  1/    qwerty   (internatinal)"
        echo -e "  2/    azerty   (french)"
        echo -e "  3/    qwertz   (german)"
        read setkeyboardtype
        echo ""
        if [[ $setkeyboardtype == "1" ]] ; then
            ls -C /usr/share/kbd/keymaps/i386/qwerty | sed -n 's/\.map.gz$//p' | pr -3 -t
            echo -e "${GRE}   ENTER THE CONSOLE KEYBOARD LAYOUT : ${NC}"
            read setvconsole
            arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        elif [[ $setkeyboardtype == "2" ]] ; then
            ls /usr/share/kbd/keymaps/i386/azerty | sed -n 's/\.map.gz$//p' | pr -3 -t
            echo -e "${GRE}   ENTER THE CONSOLE KEYBOARD LAYOUT : ${NC}"
            read setvconsole
            arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        elif [[ $setkeyboardtype == "3" ]] ; then
            ls /usr/share/kbd/keymaps/i386/qwertz | sed -n 's/\.map.gz$//p' | pr -3 -t
            echo -e "${GRE}   ENTER THE CONSOLE KEYBOARD LAYOUT : ${NC}"
            read setvconsole
            arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        fi
}

# CREATE THE HOSTNAME and HOSTS
set_hostname () {
        arch-chroot /mnt bash -c "echo $username >> /etc/hostname"

# CREATE HOSTS FILE
        arch-chroot /mnt bash -c "echo '127.0.0.1     localhost $username' >> /etc/hosts"
        arch-chroot /mnt bash -c "echo '::1           localhost $username' >> /etc/hosts"
}

# DEFINE ROOT PASSWORD
define_rootpwd () {
        clear
        echo -e "${GRE}-- DEFINE THE SUPERUSER PASSWORD ${NC}"
        arch-chroot /mnt bash -c "passwd"
}

part1=1
part2=2
part3=3
# INSTALL BOOTLOADER GRUB
install_grub () {
    if [[ $bootvar == "gpt" ]] && [[ $encrypteddisk == "yes" ]] ; then
        pacstrap /mnt efibootmgr
        uuidblk="`blkid -o value -s UUID /dev/${disknametarget}${part3}`"
        echo $uuidblk
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$uuidblk:cryptroot root=\/dev\/mapper\/cryptroot\"|g" /mnt/etc/default/grub
        sed -i "s|#GRUB_ENABLE_CRYPTODISK=y|GRUB_ENABLE_CRYPTODISK=y|g" /mnt/etc/default/grub
        hookold="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
        hooknew="HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)"
        sed -i "s|$hookold|$hooknew|g" /mnt/etc/mkinitcpio.conf
        arch-chroot /mnt bash -c "mkinitcpio -P linux"
        arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --bootloader-id=ArchDev --efi-directory=/boot/efi"
        arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    elif [[ $bootvar == "gpt" ]] && [[ $encrypteddisk == "no" ]] ; then
        pacstrap /mnt efibootmgr
        arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --bootloader-id=ArchDev --efi-directory=/boot/efi"
    elif [[ $bootvar == "msdos" ]] && [[ $encrypteddisk == "yes" ]] ; then
        uuidblk="`blkid -o value -s UUID /dev/${disknametarget}${part2}`"
        echo $uuidblk
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$uuidblk:cryptroot root=\/dev\/mapper\/cryptroot\"|g" /mnt/etc/default/grub
        sed -i "s|#GRUB_ENABLE_CRYPTODISK=y|GRUB_ENABLE_CRYPTODISK=y|g" /mnt/etc/default/grub
        hookold="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
        hooknew="HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)"
        sed -i "s|$hookold|$hooknew|g" /mnt/etc/mkinitcpio.conf
        arch-chroot /mnt bash -c "mkinitcpio -P linux"
        arch-chroot /mnt bash -c "grub-install --target=i386-pc /dev/$disknametarget"
        arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    elif [[ $bootvar == "msdos" ]] && [[ $encrypteddisk == "no" ]] ; then
        arch-chroot /mnt bash -c "grub-install --target=i386-pc /dev/$disknametarget"
        arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    fi
}

# DEFINE KEYBOARD for X
set_xkeyboard () {
        xkeyboard=`echo $setlocaleUTF | cut -d _ -f 1`
        arch-chroot /mnt bash -c "mkdir --parent /etc/X11/xorg.conf.d"
        arch-chroot /mnt bash -c "echo 'Section \"InputClass\"' > /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo '    Identifier \"system-keyboard\"' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo '    MatchIsKeyboard \"on\"' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo '    Option \"XkbLayout\" \"$xkeyboard\"' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo 'EndSection' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
}

# DEFINE USER PASSWORD
define_userpwd () {
        clear
        arch-chroot /mnt bash -c "useradd -m $username"
        echo -e "${GRE}-- DEFINE $username PASSWORD ${NC}"
        arch-chroot /mnt bash -c "passwd $username"
}

# INSTALL PACKAGES
install_packages () {
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed base-devel \
                                                                laptop-detect \
                                                                nano \
                                                                netctl \
                                                                networkmanager \
                                                                htop \
                                                                dialog"
        arch-chroot /mnt bash -c "systemctl enable NetworkManager.service"
        clear
        echo -e "${GRE}-- DESKTOP ENVIRONMENT : "
        echo -e "${GRE}  1/ PLASMA-DESKTOP (without KDE)            plasma-desktop"
        echo -e "${GRE}  2/ XFCE                                    xfce4"
        echo -e "${GRE}  3/ GNOME                                   gnome"
        echo -e "${GRE}  4/ MATE                                    mate"
        echo ""
        echo -e "${GRE}  Enter the DESKTOP ENVIRONMENT Number to install : ${NC}"
        read desktopenv
    if [[ $desktopenv == "1" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xorg-server plasma-desktop plasma-nm plasma-pa powerdevil bluedevil dolphin konsole kate kscreen sddm sddm-kcm"
        arch-chroot /mnt bash -c "systemctl enable sddm.service"
    elif [[ $desktopenv == "2" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xorg-server xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
        arch-chroot /mnt bash -c "systemctl enable lightdm.service"
    elif [[ $desktopenv == "3" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xorg-server gnome gnome-extra lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
        arch-chroot /mnt bash -c "systemctl enable lightdm.service"
    elif [[ $desktopenv == "4" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xorg-server mate mate-extra lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
        arch-chroot /mnt bash -c "systemctl enable lightdm.service"
    fi
}

# GPU VIDEO CARDS
install_videocard () {
        clear
        echo -e "${GRE}--  VIDEO GRAPHICS DRIVER : "
        echo -e "${GRE}  1/ AMD                                     xf86-video-amdgpu"
        echo -e "${GRE}  2/ ATI                                     xf86-video-ati"
        echo -e "${GRE}  3/ INTEL i810/i830/i915/945G/965G+         xf86-video-intel"
        echo -e "${GRE}  4/ Nvidia (proprietary)                    nvidia + nvidia-dkms"
        echo -e "${GRE}  5/ Nvidia (open source)                    xf86-video-nouveau"
        echo -e "${GRE}  6/ Virtual Machine (vmware, esxi)          xf86-video-vmware"
        echo -e "${GRE}  7/ Virtual Machine (virtualbox)            virtualbox-guest-utils"
        echo -e "${GRE}  8/ Virtual Machine (Qxl virtio Qemu)       xf86-video-qxl"
        echo -e "${GRE}  9/ Vesa                                    xf86-video-vesa"
        echo ""
        echo -e "${GRE}  Enter Driver Number to install : ${NC}"
        read vgacard
    if [[ $vgacard == "1" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-amdgpu"
    elif [[ $vgacard == "2" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-ati"
    elif [[ $vgacard == "3" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-intel"
    elif [[ $vgacard == "4" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed nvidia nvidia-dkms linux-headers nvidia-settings"
    elif [[ $vgacard == "5" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-nouveau"
    elif [[ $vgacard == "6" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-vmware"
    elif [[ $vgacard == "7" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed virtualbox-guest-utils"
    elif [[ $vgacard == "8" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-qxl virglrenderer spice-vdagent celt0.5.1"
    elif [[ $vgacard == "9" ]]; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-vesa"
    fi
}

# CLEAN RESTART
clean_restart () {
        umount -R /mnt/boot/efi
        umount -R /mnt/boot/
        umount -R /mnt
        reboot
}


#################################
#           DEFINE COLOR FOR BASH
NC='\033[0m'           # No Color
RED='\033[0;31m'       # Red
GRE='\033[0;32m'       # Green
BLU='\033[0;36m'       # Blue
check_bootmode
check_network
update_systemclock
check_diskname
erase_disk
encrypted_choice
enter_username
select_mirrors
essential_packages
detect_cpu
generate_fstab
set_timezone
set_localization
set_hostname
define_rootpwd
install_grub
set_xkeyboard
define_userpwd
install_packages
install_videocard
clean_restart
#################################
