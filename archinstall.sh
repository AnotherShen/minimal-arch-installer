#!/usr/bin/env bash

# Keyboard settings
echo "[Arch Installer] Console keymap is US by default. Refer to install guide to change."

# Check that it isn't in UEFI mode
echo "[Arch Installer] Verifying installation assumptions..."
BIOS=false
ls /sys/firmware/efi/efivars 2> /dev/null || BIOS=true
if $BIOS ; then
	echo "[Arch Installer] -> System is in BIOS mode."
else
	echo "[Arch Installer] -> System is in UEFI mode. This is not yet supported. Aborting."
	exit 1
fi

# Check internet connection
INTERNET=true
ping google.com -c 4 > /dev/null 2> /dev/null || INTERNET=false
if $INTERNET ; then
	echo "[Arch Installer] -> System is connected to the internet."
else
	echo "[Arch Installer] -> System has no internet connection. Aborting."
	exit 1
fi

# Set-up system clock
echo "[Arch Installer] Updating the system clock."
timedatectl set-ntp true

# Partion disks (BIOS with MBR)
echo "[Arch Installer] Partioning disk."
parted -s -a optimal /dev/sda mklabel msdos
parted -s -a optimal /dev/sda mkpart primary linux-swap 1MiB 1024MiB
parted -s -a optimal /dev/sda mkpart primary 1024MiB 100%MiB
parted -s -a optimal /dev/sda set 1 boot on
sync
partprobe /dev/sda
mkswap /dev/sda1
mkfs.ext4 /dev/sda2

# Mount disks
echo "[Arch Installer] Mounting disk."
swapon /dev/sda1
mount /dev/sda2 /mnt

# Install essential packages
echo "[Arch Installer] Installing essential packages."
pacstrap /mnt base linux linux-firmware vim nano

# Configure the system
echo "[Arch Installer] Configuring system."
genfstab -U /mnt >> /mnt/etc/fstab
# Enter into chroot environment
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Australia/Adelaide /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i -e "s/#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/g" /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo "LANG=en_AU.UTF-8" > /etc/locale.conf
# Set keyboard layout in /etc/vconsole.conf if changed
arch-chroot /mnt echo "arch" > /etc/hostname
arch-chroot /mnt echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 arch.localdomain arch" >> /etc/hosts
arch-chroot /mnt mkinitcpio -P

# Create accounts
echo "[Arch Installer] Set root password."
arch-chroot /mnt passwd
echo "[Arch Installer] Installing sudo."
arch-chroot /mnt pacman -S sudo --noconfirm
echo "[Arch Installer] Set user password."
arch-chroot /mnt useradd -m user
arch-chroot /mnt passwd user
arch-chroot /mnt usermod -aG wheel user

# Install boot loader
echo "[Arch Installer] Installing bootloader."
arch-chroot /mnt pacman -S grub
arch-chroot /mnt grub-install /dev/sda
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Install desktop environment
echo "[Arch Installer] Installing desktop."
arch-chroot /mnt pacman -S xorg --noconfirm
arch-chroot /mnt pacman -S gnome --noconfirm
arch-chroot /mnt systemctl enable gdm.service

# Install network manager
echo "[Arch Installer] Installing network manager."
arch-chroot /mnt pacman -S wpa_supplicant wireless_tools networkmanager --noconfirm
arch-chroot /mnt pacman -S nm-connection-editor network-manager-applet --noconfirm
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl disable dhcpcd.service
arch-chroot /mnt systemctl enable wpa_supplicant.service

# Install basic packages
echo "[Arch Installer] Installing VM tools."
arch-chroot /mnt pacman -S open-vm-tools --noconfirm

# Exit out chroot and restart
echo "[Arch Installer] Completed. Restarting..."
umount -R /mnt
reboot
