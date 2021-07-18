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

# Install build packages
echo "[Arch Installer] Installing build packages."
pacstrap /mnt base linux linux-firmware
read -p "Press any key to resume ..."

# Configure the system
echo "[Arch Installer] Configuring system."
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Australia/Adelaide /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i -e "s/#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/g" /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt echo -e "LANG=en_AU.UTF-8\nLANGUAGE=en_AU:en_GB:en" > /etc/locale.conf
arch-chroot /mnt echo "arch" > /etc/hostname
arch-chroot /mnt echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 arch.localdomain arch" >> /etc/hosts
arch-chroot /mnt mkinitcpio -P
arch-chroot /mnt sed -i -e "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers
read -p "Press any key to resume ..."

# Install packages
echo "[Arch Installer] Installing other packages."
pacstrap /mnt vim nano sudo xterm open-vm-tools xorg gnome grub wpa_supplicant wireless_tools networkmanager nm-connection-editor network-manager-applet
read -p "Press any key to resume ..."

# Create accounts
echo "[Arch Installer] Configure accounts (interaction required)."
echo "[Arch Installer] -> Set root password."
arch-chroot /mnt passwd
echo "[Arch Installer] -> Set user password."
arch-chroot /mnt useradd -m user
arch-chroot /mnt passwd user
arch-chroot /mnt usermod -aG wheel user

# Configure boot loader
echo "[Arch Installer] Configuring bootloader."
arch-chroot /mnt grub-install /dev/sda
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Configure services
echo "[Arch Installer] Configuring desktop & network services."
arch-chroot /mnt systemctl enable gdm.service
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl disable dhcpcd.service
arch-chroot /mnt systemctl enable wpa_supplicant.service
arch-chroot /mnt systemctl enable vmtoolsd.service
arch-chroot /mnt systemctl enable vmware-vmblock-fuse.service
read -p "Press any key to resume ..."

# Exit out chroot and restart
echo "[Arch Installer] Completed. Restarting..."
umount -R /mnt
reboot
