#!/usr/bin/env bash

# Check whether it is executed in Live environment
if [ $(cat /etc/hostname) != "archiso" ]; then
  echo "Please run this script in Arch Live environment!"
  read -p "Current environment is not Arch Live, there is risk. Continue? [y/n] " choose
  if [[ "$choose" =~ ^[Yy]$ ]]; then
    echo "Subsequent risks must be borne by yourself!"
  else
    exit 1
  fi
fi

# Check whether the program is executed with root privileges
if [ "$EUID" != "0" ]; then
  echo "Need to run with root privileges!"
  exit 1
fi

# Check whether network is connected
if ! ping -c 1 8.8.8.8 &>/dev/null; then
  echo "Not connected to the network!"
  exit 1
fi

echo "Welcome to use this installation program, this program will help you quickly install archlinux!"
echo "Disclaimer: This tool is open source, all losses caused are borne by the individual, unrelated to the developer"

printf "\n"

# Partitioning
read -p "Do you want to perform partitioning operation? [y/n] " choose
if [[ "$choose" =~ ^[Yy]$ ]]; then
  read -p "Please enter the path of the hard disk device to be partitioned (e.g. /dev/sda): " path
  fdisk $path
else
  echo "This program will assume that you have completed partitioning"
fi

printf "\n"

echo "lsblk output:"
lsblk

printf "\n"

# Obtain partition device path
echo "Next, you need to enter the partition path (e.g. /dev/sda1)"
read -p "Enter ESP partition: " esp
read -p "Enter root partition: " root

printf "\n"

# Format partitions
echo "About to format partitions"
sleep 2
mkfs.ext4 $root
mkfs.fat -F32 $esp

printf "\n"

# Mount partitions
mount $root /mnt
mount $esp /mnt/boot --mkdir

# Write vconsole.conf
mkdir /mnt/etc
printf "KEYMAP=\"us\"\n" > /mnt/etc/vconsole.conf

# Install base system
echo "Next, the base system will be installed, including some basic tools"
read -p "Before installation, you need to confirm your cpu type [amd/intel]: " cpu_type
pacstrap /mnt base base-devel vim vi sudo linux linux-headers linux-firmware networkmanager $cpu_type-ucode mesa grub efibootmgr

printf "\n"

# Confirm whether the graphics card type is NVIDIA, if yes install the driver
read -p "Is your graphics card NVIDIA? [y/n] " gpu_type
if [[ "$gpu_type" =~ ^[Yy]$ ]]; then
  pacstrap /mnt nvidia nvidia-utils
fi

# Confirm whether to install sof firmware
read -p "Do you want to install sof firmware? [y/n] " install_sof_firmware
if [[ "$install_sof_firmware" =~ ^[Yy]$ ]]; then
  pacstrap /mnt sof-firmware
fi

# Configure hostname
read -p "Enter hostname: " host_name
echo "$host_name" >/mnt/etc/hostname

# Generate fstab
genfstab -U /mnt >/mnt/etc/fstab

# Uncomment some lines
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf

# Confirm root password
echo "About to set root password"
arch-chroot /mnt passwd root

# Confirm whether to create a regular user
read -p "Do you want to create a regular user? [y/n] " creater_user
if [[ "$creater_user" =~ ^[Yy]$ ]]; then
  read -p "Enter username: " user_name
  arch-chroot /mnt useradd -m -s /bin/bash -G wheel $user_name
  echo "About to set password for $user_name"
  arch-chroot /mnt passwd $user_name
fi

# Necessary configurations
sed -i 's|# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|g' /mnt/etc/sudoers
sed -i 's|#en_US.UTF-8|en_US.UTF-8|g' /mnt/etc/locale.gen
sed -i 's|#zh_CN.UTF-8|zh_CN.UTF-8|g' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=zh_CN.UTF-8" >/mnt/etc/locale.conf
arch-chroot /mnt ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# Enable networkmanager
arch-chroot /mnt systemctl enable NetworkManager

printf "\n"

# Install bootloader
echo "About to install bootloader"
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=ArchLinux --efi-directory=/boot
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Unmount partitions
umount -R /mnt

echo "Installation complete!"
