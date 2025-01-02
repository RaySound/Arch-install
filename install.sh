#!/bin/bash

# Warnung, dass dieses Skript beim Ausführen das System konfiguriert!
echo "Achtung: Dieses Skript wird das System gemäß den angegebenen Einstellungen konfigurieren."
read -p "Drücke Enter, um fortzufahren..."

# 1. Systemkonfiguration

# 1.1 Sprache und Tastatur
echo "Setze Sprache auf de_DE.UTF-8"
echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
export LANG=de_DE.UTF-8
echo "Sprache auf de_DE.UTF-8 gesetzt"

echo "Setze Tastaturlayout auf de-latin1"
localectl set-keymap de-latin1
echo "Tastaturlayout auf de-latin1 gesetzt"

# 1.2 Zeitzone und Uhrzeit
echo "Setze Zeitzone auf Europe/Berlin"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc --utc
echo "Zeitzone auf Europe/Berlin gesetzt"

# 1.3 Hostname und Netzwerkname
echo "Setze Hostname auf ray-arch"
echo "ray-arch" > /etc/hostname
echo "Hostname auf ray-arch gesetzt"

# 1.4 Benutzerkonten und Passwörter
echo "Erstelle Benutzer ray und setze Passwort"
useradd -m -G wheel -s /bin/bash ray
echo "Benutzer 'ray' wurde erstellt"
passwd ray
echo "Passwort für Benutzer 'ray' gesetzt"

echo "Setze Root-Passwort"
passwd
echo "Root-Passwort gesetzt"

# Sudo-Rechte für den Benutzer 'ray'
echo "Füge Benutzer 'ray' zur sudo-Gruppe hinzu"
echo "ray ALL=(ALL) ALL" >> /etc/sudoers.d/ray
echo "Benutzer 'ray' hat Sudo-Rechte"

# 2. Festplattenpartitionierung (Automatisch)
echo "Partitioniere Festplatte (SSD)"
# Formatieren der Festplatte (nehmen wir an, die Festplatte ist /dev/nvme0n1p1, oder stanrd /dev/sda ersetze dies ggf.)
parted /dev/sda mklabel gpt
parted /dev/sda mkpart primary ext4 1MiB 100%
cryptsetup luksFormat /dev/sda1
cryptsetup luksOpen /dev/sda1 cryptroot
mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
echo "Festplatte partitioniert und verschlüsselt"

# 3. Desktop-Umgebung und Window Manager
echo "Installiere KDE Plasma mit Wayland"
pacman -S --noconfirm plasma plasma-wayland-session sddm
echo "KDE Plasma und Wayland-Session installiert"

# XWayland installieren
echo "Installiere XWayland"
pacman -S --noconfirm xorg-xwayland
echo "XWayland installiert"

# 4. Zusätzliche Softwarepakete

# 4.1 Standardpakete
echo "Installiere essentielle Pakete"
pacman -S --noconfirm base linux linux-firmware pacman-contrib base-devel nano git btop fastfetch neofetch
echo "Essentielle Pakete installiert"

# 4.2 Desktop-Software
echo "Installiere Desktop-Software"
pacman -S --noconfirm thunderbird firefox vlc spectacle
echo "Desktop-Software installiert"

# 4.3 Weitere Software
echo "Installiere Flatpak, VirtualBox, Lutris, Wine, JDownloader2 und gnome-disk-utility"
pacman -S --noconfirm flatpak virtualbox lutris wine jdownloader2 gnome-disk-utility
echo "Weitere Software installiert"

# 4.4 Gaming-Software
echo "Installiere Gaming-Software"
pacman -S --noconfirm steam
echo "Gaming-Software installiert"

# 5. Bootloader und Startoptionen

echo "Installiere GRUB Bootloader und aktiviere UEFI"
pacman -S --noconfirm grub efibootmgr
mount /dev/sda1 /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
echo "GRUB Bootloader installiert und konfiguriert"

# 6. Netzwerk und Kommunikation
echo "WLAN ist nicht erforderlich, Ethernet wird über dhclient oder NetworkManager verwendet."
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager
echo "NetworkManager aktiviert"

# 7. Sicherheit und Optimierung
echo "AppArmor oder SELinux wird nicht installiert, da dies optional ist."
echo "Falls benötigt, kannst du AppArmor oder SELinux später manuell installieren."

# 8. Erweiterte Systemkonfiguration
echo "Aktiviere Multilib für 32-Bit-Anwendungen"
sed -i 's/#\[multilib\]/[multilib]/' /etc/pacman.conf
pacman -Sy
echo "Multilib aktiviert"

echo "Installiere AUR-Helper paru"
pacman -S --noconfirm paru
echo "paru AUR-Helper installiert"

echo "Aktiviere automatische Updates für AUR-Pakete"
echo "Sudo pacman -Syu --noconfirm && paru -Syu --noconfirm" > /etc/cron.daily/auto-update
chmod +x /etc/cron.daily/auto-update
echo "Automatische Updates aktiviert"

# 9. Abschluss und Neustart
echo "Aktiviere Systemdienste für Zeitsynchronisation und SSD-Optimierung"
systemctl enable systemd-timesyncd
systemctl enable fstrim.timer
echo "Systemdienste konfiguriert"

# Neustarten
echo "Installation abgeschlossen! Starte das System neu..."
reboot
