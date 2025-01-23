#!/bin/bash

# Schritt 1: Vorbereitung
clear
echo -e "\nArch Linux Installation Script für deinen Dell Latitude E7440"
echo -e "Automatische Installation mit minimaler Softwareauswahl Gnome und Cosmicx.\n"
sleep 2

# Schritt 2: Verfügbare Festplatten anzeigen und Auswahl treffen
echo -e "\nVerfügbare Festplatten:"
lsblk -d -e 7,11 -o NAME,SIZE,TYPE | grep disk
echo -e "\nBitte wähle die Festplatte, auf der das System installiert werden soll (z.B. sda): "
read disk

disk="/dev/$disk"
echo -e "\nAusgewählte Festplatte: $disk"

echo -e "\nAlle Daten auf $disk werden gelöscht! Fortfahren? [y/n]: "
read confirm
if [ "$confirm" != "y" ]; then
    echo "Abgebrochen."
    exit 1
fi

# Abfrage, ob die Festplatte verschlüsselt werden soll
echo -e "\nMöchtest du die Root-Partition verschlüsseln? [y/n]: "
read encrypt

# Schritt 3: Festplatte löschen und Partitionieren
echo "Lösche alle vorhandenen Partitionen auf $disk..."
sgdisk --zap-all $disk

echo "Lösche die ersten 100 MB der Festplatte zur Sicherheit..."
dd if=/dev/zero of=$disk bs=1M count=100 status=progress

# Partitionierung
echo "Erstelle Partitionen auf $disk..."
parted $disk -- mklabel gpt
parted $disk -- mkpart ESP fat32 1MiB 513MiB
parted $disk -- set 1 boot on
parted $disk -- mkpart primary linux-swap 513MiB 33.5GiB
if [ "$encrypt" == "y" ]; then
    parted $disk -- mkpart primary 33.5GiB 100%
else
    parted $disk -- mkpart primary ext4 33.5GiB 100%
fi

# Dateisysteme erstellen
echo "Erstelle Dateisysteme..."
mkfs.fat -F32 ${disk}1
mkswap ${disk}2
if [ "$encrypt" == "y" ]; then
    echo "Verschlüsselung der Root-Partition wird eingerichtet..."
    cryptsetup luksFormat ${disk}3
    cryptsetup open ${disk}3 cryptroot
    mkfs.ext4 /dev/mapper/cryptroot
else
    mkfs.ext4 ${disk}3
fi

# Swap aktivieren
swapon ${disk}2

# Schritt 4: Mounten und Systeminstallation
echo "Mounten der Partitionen..."
if [ "$encrypt" == "y" ]; then
    mount /dev/mapper/cryptroot /mnt
else
    mount ${disk}3 /mnt
fi
mkdir -p /mnt/boot
mount ${disk}1 /mnt/boot

pacstrap /mnt base linux linux-firmware nano sudo grub networkmanager pipewire pipewire-pulse mesa intel-ucode xf86-video-intel iwd dhclient

# Schritt 5: System einrichten
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt bash -c "
    ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
    hwclock --systohc
    echo "LANG=de_DE.UTF-8" > /etc/locale.conf
    echo "KEYMAP=de-latin1" > /etc/vconsole.conf
    locale-gen
    echo "arch-laptop" > /etc/hostname
    echo "127.0.0.1   localhost" >> /etc/hosts
    echo "::1         localhost" >> /etc/hosts
    echo "127.0.1.1   arch-laptop.localdomain arch-laptop" >> /etc/hosts
    passwd
    systemctl enable NetworkManager
    systemctl enable iwd
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    if [ "$encrypt" == "y" ]; then
        echo "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$(blkid -s UUID -o value ${disk}3):cryptroot root=/dev/mapper/cryptroot\"" >> /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
"

# Schritt 6: Abschluss
umount -R /mnt
swapoff -a
if [ "$encrypt" == "y" ]; then
    cryptsetup close cryptroot
fi
echo -e "\nInstallation abgeschlossen! Bitte starte das System neu."
reboot
