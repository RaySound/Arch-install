#!/bin/bash

set -e

### Schritt 1: Grundlegende Einstellungen ###
loadkeys de-latin1
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
sed -i 's/#de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=de_DE.UTF-8" > /etc/locale.conf

### Schritt 2: Festplattenpartitionierung ###
read -p "Welche Festplatte soll verwendet werden? (z.B. /dev/sda): " disk

# Partitionierung (Root und optional Home)
echo "Partitionierung wird durchgeführt..."
parted --script "$disk" mklabel gpt
parted --script "$disk" mkpart primary 1MiB 512MiB
parted --script "$disk" mkpart primary 512MiB 100%
parted --script "$disk" set 1 boot on

# Root-Verschlüsselung
read -p "Soll die Root-Partition verschlüsselt werden? (y/n): " luks_encrypt
if [ "$luks_encrypt" = "y" ]; then
    echo "Verschlüsselung wird eingerichtet..."
    echo -n "Geben Sie ein Passwort für LUKS ein: "
    cryptsetup luksFormat ${disk}2
    cryptsetup open ${disk}2 cryptroot
    mkfs.ext4 /dev/mapper/cryptroot
    mount /dev/mapper/cryptroot /mnt
else
    mkfs.ext4 ${disk}2
    mount ${disk}2 /mnt
fi

mkfs.fat -F32 ${disk}1
mkdir -p /mnt/boot
mount ${disk}1 /mnt/boot

# Home-Verzeichnis
read -p "Möchten Sie eine separate Home-Partition erstellen? (y/n): " home_partition
if [ "$home_partition" = "y" ]; then
    read -p "Welches Dateisystem soll für /home verwendet werden? (ext4/btrfs/xfs): " home_fs
    parted --script "$disk" mkpart primary 100%
    case $home_fs in
        ext4)
            mkfs.ext4 ${disk}3
            ;;
        btrfs)
            mkfs.btrfs ${disk}3
            ;;
        xfs)
            mkfs.xfs ${disk}3
            ;;
        *)
            echo "Ungültige Eingabe. Standardmäßig ext4 wird verwendet."
            mkfs.ext4 ${disk}3
            ;;
    esac
    mkdir /mnt/home
    mount ${disk}3 /mnt/home
fi

### Schritt 3: Basisinstallation ###
pacstrap /mnt base linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt bash <<EOF

### Schritt 4: Systemkonfiguration ###
echo "ArchLinux" > /etc/hostname
cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   ArchLinux.localdomain ArchLinux
EOL

### Schritt 5: Bootloader ###
if [ "$luks_encrypt" = "y" ]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID=$(blkid -s UUID -o value ${disk}2):cryptroot root=/dev/mapper/cryptroot"/' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
else
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
fi

### Schritt 6: Treiber und minimalistische Desktop-Umgebung ###
pacman -S --noconfirm amd-ucode mesa xf86-video-amdgpu

# Minimal KDE Plasma
pacman -S --noconfirm plasma-desktop sddm
systemctl enable sddm
systemctl enable NetworkManager

### Schritt 7: Zusätzliche Konfiguration ###
# Multilib aktivieren
sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
pacman -Sy

# Flatpak für Discover
pacman -S --noconfirm flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

EOF

umount -R /mnt
echo "Installation abgeschlossen! Starten Sie das System neu."
