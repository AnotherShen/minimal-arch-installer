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

# Configure the system
echo "[Arch Installer] Configuring system."
genfstab -U /mnt >> /mnt/etc/fstab
# Heredoc to run commands in arch-chroot. Needed for echos.
arch-chroot /mnt /bin/bash <<END
ln -sf /usr/share/zoneinfo/Australia/Adelaide /etc/localtime
hwclock --systohc
sed -i -e "s/#en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/g" /etc/locale.gen
locale-gen
echo -e "LANG=en_AU.UTF-8\nLANGUAGE=en_AU:en_GB:en" > /etc/locale.conf
echo "arch" > /etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 arch.localdomain arch" >> /etc/hosts
END
#arch-chroot /mnt mkinitcpio -P

# Install other packages
echo "[Arch Installer] Installing other packages."
pacstrap /mnt vim nano sudo xterm open-vm-tools xorg gnome grub wpa_supplicant wireless_tools networkmanager nm-connection-editor network-manager-applet

# Create accounts
echo "[Arch Installer] Configure accounts (interaction required)."
echo "[Arch Installer] -> Set root password."
arch-chroot /mnt passwd
echo "[Arch Installer] -> Set user password."
arch-chroot /mnt useradd -m user
arch-chroot /mnt passwd user
arch-chroot /mnt usermod -aG wheel user
arch-chroot /mnt sed -i -e "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers

# Configure services
echo "[Arch Installer] Configuring bootloader, desktop & network services."
# Heredoc to run commands in arch-chroot. Not needed but cleaner.
arch-chroot /mnt /bin/bash <<END
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable gdm.service
systemctl enable NetworkManager.service
systemctl disable dhcpcd.service
systemctl enable wpa_supplicant.service
systemctl enable vmtoolsd.service
systemctl enable vmware-vmblock-fuse.service
END

# Exit out chroot and restart
echo "[Arch Installer] Install complete."
read -p "Press any key to reboot..."
umount -R /mnt
reboot
