#!/bin/bash
set -e # Exit on error

echo "==> Localization"
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf

echo "==> Configuring pacman"
sed -i 's/^#Color/Color\nILoveCandy/g' /etc/pacman.conf
sed -i 's/^#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf

echo "==> Updating and installing base packages"
pacman -Syu --noconfirm
pacman -S --needed --noconfirm base base-devel git unzip man-db sudo

echo "==> User Setup"
[ -z "$username" ] && read -r -p "Enter username: " username
useradd -m -G wheel -s /bin/bash "$username"

read -rs -p "Enter password for $username and root: " password
echo "" # New line after silent read
echo "$username:$password" | chpasswd
echo "root:$password" | chpasswd
unset password

echo "==> Enabling sudo for wheel group"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "Setting $username as default WSL user"
tee -a /etc/wsl.conf <<EOF
[user]
default=$username
EOF

echo "==> Setup complete!"
