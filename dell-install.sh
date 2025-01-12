#!/bin/bash

# Schritt 1: Vorbereitung
clear
echo -e "\nArch Linux Installation Script für deinen Dell Latitude E7440"
echo -e "Automatische Installation mit minimaler Softwareauswahl Gnome und Cosmicx.\n"
sleep 2

# Schritt 2: Benutzereingabe - Festplatte auswählen
echo -n "Bitte wähle die Festplatte, auf der das System installiert werden soll (z.B. /dev/sda): "
read disk
echo -n "Möchtest du die Festplatte verschlüsseln (LUKS)? [y/n]: "
read encrypt_choice

# Schritt 3: Partitionierung und Dateisystem
if [ "$encrypt_choice" == "y" ]; then
    # LUKS Verschlüsselung einrichten
    echo "Einrichten von LUKS Verschlüsselung..."
    cryptsetup luksFormat $disk
    cryptsetup open $disk crypt
    disk="/dev/mapper/crypt"
fi

# Standard partitionieren mit ext4
echo "Partitioniere die Festplatte..."
parted $disk -- mklabel gpt
parted $disk -- mkpart primary ext4 0% 100%
mkfs.ext4 ${disk}1

# Schritt 4: Mounten und Systeminstallation
mount ${disk}1 /mnt
pacstrap /mnt base linux linux-firmware nano sudo grub networkmanager pipewire pipewire-pulse

# Schritt 5: System anpassen (fstab, locale, etc.)
genfstab -U /mnt >> /mnt/etc/fstab

# Schritt 6: Deutsch als Sprache und Tastaturlayout
arch-chroot /mnt locale-gen
echo "LANG=de_DE.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=de-latin1" > /mnt/etc/vconsole.conf
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# Schritt 7: Hostname und Benutzer erstellen
echo -n "Bitte gib einen Hostnamen für dein System ein: "
read hostname
echo "$hostname" > /mnt/etc/hostname

# Benutzer erstellen
echo -n "Bitte gib einen Benutzernamen ein: "
read username
arch-chroot /mnt useradd -m -G wheel -s /bin/bash $username
echo -n "Bitte gib ein Passwort für den Benutzer ein: "
arch-chroot /mnt passwd $username
echo -n "Bitte gib ein Passwort für den Root-Account ein: "
arch-chroot /mnt passwd

# Schritt 8: GRUB installieren (UEFI)
arch-chroot /mnt pacman -S grub efibootmgr
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Schritt 9: Netzwerk-Setup (NetworkManager)
arch-chroot /mnt systemctl enable NetworkManager

# Schritt 10: Zusätzliche Software installieren
arch-chroot /mnt pacman -S gdm gnome gnome-tweaks gnome-shell-extensions

# Schritt 11: Treiber für die Hardware optimieren
# Blacklist unnötiger Treiber für Dell Latitude E7440
echo "blacklist nouveau" >> /mnt/etc/modprobe.d/blacklist.conf  # Nvidia-Grafikkarten
echo "blacklist amdgpu" >> /mnt/etc/modprobe.d/blacklist.conf  # AMD-Grafikkarten
echo "blacklist radeon" >> /mnt/etc/modprobe.d/blacklist.conf  # AMD-Grafikkarten
echo "blacklist ath9k" >> /mnt/etc/modprobe.d/blacklist.conf   # Atheros-WLAN (falls nicht benötigt)
echo "blacklist b43" >> /mnt/etc/modprobe.d/blacklist.conf     # Broadcom-WLAN (falls nicht benötigt)
echo "blacklist b43legacy" >> /mnt/etc/modprobe.d/blacklist.conf  # Alte Broadcom-WLAN-Karten
echo "blacklist rtl8192cu" >> /mnt/etc/modprobe.d/blacklist.conf  # Realtek-WLAN (falls nicht benötigt)
echo "blacklist btusb" >> /mnt/etc/modprobe.d/blacklist.conf   # Bluetooth-Adapter (falls nicht benötigt)
echo "blacklist r8169" >> /mnt/etc/modprobe.d/blacklist.conf   # Realtek-Ethernet (falls nicht benötigt)
echo "blacklist tg3" >> /mnt/etc/modprobe.d/blacklist.conf     # Broadcom-Ethernet (falls nicht benötigt)
echo "blacklist usb_storage" >> /mnt/etc/modprobe.d/blacklist.conf  # USB-Speicher (falls nicht benötigt)
echo "blacklist hid_logitech" >> /mnt/etc/modprobe.d/blacklist.conf  # Logitech-Peripheriegeräte (falls nicht benötigt)
echo "blacklist usbhid" >> /mnt/etc/modprobe.d/blacklist.conf   # USB-HID (falls nicht benötigt)

# Schritt 12: Systemoptimierungen
# Swappiness anpassen (Wert für Swap-Nutzung)
echo "vm.swappiness=10" > /mnt/etc/sysctl.d/99-swappiness.conf

# CPU Governor auf maximale Leistung setzen
echo "performance" > /mnt/sys/class/drm/card0/device/power_profile

# SSD Optimierung (fstrim)
arch-chroot /mnt systemctl enable fstrim.timer

# Schritt 13: NTP aktivieren
arch-chroot /mnt systemctl enable systemd-timesyncd

# Schritt 14: AppArmor installieren und aktivieren
arch-chroot /mnt pacman -S apparmor
arch-chroot /mnt systemctl enable apparmor

# Schritt 15: Blacklist PipeWire
# Wenn PulseAudio installiert werden soll, PipeWire nicht aktivieren
# arch-chroot /mnt systemctl enable pipewire.service

# Schritt 16: Abschluss
echo -e "\nInstallation abgeschlossen. Du kannst das System nun neu starten."
