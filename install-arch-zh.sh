#!/usr/bin/env bash

# 判断是否为Live环境中执行此脚本
if [ $(cat /etc/hostname) != "archiso" ]; then
  echo "请在Arch Live环境中运行此脚本！"
  read -p "当前环境不是Arch Live，存在风险，是否继续？[y/n] " choose
  if [[ "$choose" =~ ^[Yy]$ ]]; then
    echo "接下来的风险需自行承担！"
  else
    exit 1
  fi
fi

# 判断是否为root权限执行此程序
if [ "$EUID" != "0" ]; then
  echo "需使用root权限运行！"
  exit 1
fi

# 检查是否连接网络
if ! ping -c 1 8.8.8.8 &>/dev/null; then
  echo "未连接到网络！"
  exit 1
fi

echo "欢迎使用此安装程序，此程序将帮助你快速安装archlinux！"
echo "免责声明：本工具为开源工具，一切造成的损失由个人承担，与开发者无关"

printf "\n"

# 分区
read -p "是否进行分区操作？[y/n] " choose
if [[ "$choose" =~ ^[Yy]$ ]]; then
  read -p "请输入需要分区硬盘设备的路径（例如/dev/sda）：" path
  fdisk $path
else
  echo "本程序将视为你已经分区完成"
fi

printf "\n"

echo "lsblk输出："
lsblk

printf "\n"

# 获取分区设备路径
echo "接下来需要输入分区路径（例如/dev/sda1）"
read -p "输入ESP分区：" esp
read -p "输入根分区：" root

printf "\n"

# 格式化分区
echo "即将格式化分区"
sleep 2
mkfs.ext4 $root
mkfs.fat -F32 $esp

printf "\n"

# 挂载分区
mount $root /mnt
mount $esp /mnt/boot --mkdir

# 写入vconsole.conf
mkdir /mnt/etc
printf "KEYMAP=\"us\"\n" > /mnt/etc/vconsole.conf

# 安装基础系统
echo "接下来会安装基础系统，包括一些基础工具"
read -p "安装之前，需要先确定一下你的cpu类型[amd/intel]：" cpu_type
pacstrap /mnt base base-devel vim vi sudo linux linux-headers linux-firmware networkmanager $cpu_type-ucode mesa grub efibootmgr

printf "\n"

# 确认显卡类型是否为NVIDIA，如果是就安装驱动
read -p "你的显卡是否为NVIDIA？[y/n] " gpu_type
if [[ "$gpu_type" =~ ^[Yy]$ ]]; then
  pacstrap /mnt nvidia nvidia-utils
fi

# 确认是否安装sof固件
read -p "是否安装sof固件？[y/n] " install_sof_firmware
if [[ "$install_sof_firmware" =~ ^[Yy]$ ]]; then
  pacstrap /mnt sof-firmware
fi

# 配置主机名
read -p "输入主机名：" host_name
echo "$host_name" >/mnt/etc/hostname

# 生成fstab
genfstab -U /mnt >/mnt/etc/fstab

# 取消一些注释
sed -i 's/#Color/Color/g' /mnt/etc/pacman.conf

# 确认root密码
echo "即将设置root密码"
arch-chroot /mnt passwd root

# 确认是否创建普通用户
read -p "是否创建普通用户？[y/n] " creater_user
if [[ "$creater_user" =~ ^[Yy]$ ]]; then
  read -p "输入用户名：" user_name
  arch-chroot /mnt useradd -m -s /bin/bash -G wheel $user_name
  echo "即将设置$user_name的密码"
  arch-chroot /mnt passwd $user_name
fi

# 必要配置
sed -i 's|# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|g' /mnt/etc/sudoers
sed -i 's|#en_US.UTF-8|en_US.UTF-8|g' /mnt/etc/locale.gen
sed -i 's|#zh_CN.UTF-8|zh_CN.UTF-8|g' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=zh_CN.UTF-8" >/mnt/etc/locale.conf
arch-chroot /mnt ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 启用networkmanager
arch-chroot /mnt systemctl enable NetworkManager

printf "\n"

# 安装引导
echo "即将安装引导"
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=ArchLinux --efi-directory=/boot
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# 卸载分区
umount -R /mnt

echo "安装完成！"
