#!/bin/bash

# Variables
disk="/dev/sdX"  # Modifier selon le disque cible
hostname="archlinux"
username="user"
shared_folder="/home/shared"
password="azerty123"

echo "--- Début de l'installation automatisée d'Arch Linux ---"

# Étape 1: Partitionnement et chiffrement
parted $disk --script mklabel gpt
parted $disk --script mkpart ESP fat32 1MiB 512MiB
parted $disk --script set 1 boot on
parted $disk --script mkpart primary 512MiB 100%

# Chiffrement avec LUKS
cryptsetup luksFormat ${disk}2 --type luks2 --key-file <(echo -n "$password")
cryptsetup open ${disk}2 cryptroot --key-file <(echo -n "$password")

# Configuration LVM
pvcreate /dev/mapper/cryptroot
vgcreate vg0 /dev/mapper/cryptroot
lvcreate -L 70G vg0 -n root
lvcreate -L 10G vg0 -n encrypted
lvcreate -L 5G vg0 -n shared

# Formattage
mkfs.fat -F32 ${disk}1
mkfs.ext4 /dev/vg0/root
mkfs.ext4 /dev/vg0/shared
mkfs.ext4 /dev/vg0/encrypted

# Montage des partitions
mount /dev/vg0/root /mnt
mkdir -p /mnt/boot /mnt$shared_folder
mount ${disk}1 /mnt/boot
mount /dev/vg0/shared /mnt$shared_folder

# Étape 2: Installation des paquets de base
pacstrap /mnt base linux linux-firmware grub lvm2 sudo vim networkmanager

# Génération de fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot dans le système installé
arch-chroot /mnt /bin/bash <<EOF

# Configuration de base
echo "$hostname" > /etc/hostname
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Création utilisateur
useradd -m -G wheel -s /bin/bash $username
echo "$username:$password" | chpasswd
echo "root:$password" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Installation de GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Activation des services
systemctl enable NetworkManager

# Sortie du chroot
exit
EOF

# Démontage et reboot
umount -R /mnt
echo "Installation terminée, redémarrage dans 5 secondes..."
sleep 5
reboot
