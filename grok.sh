#!/bin/bash

echo "Willkommen zur spezifischen Arch Linux Installation mit COSMIC!"

# System update
sudo pacman -Syu
sudo pacman -S base linux linux-firmware dhcpcd

# Netzwerk einrichten (LAN-Kabel)
systemctl enable --now dhcpcd

# Benutzer erstellen
read -p "Gib deinen Benutzernamen ein: " username
useradd -m -g users -G wheel,audio,video,storage,optical,network,power -s /bin/bash $username
passwd $username

# Berechtigungen für sudo anpassen
echo "$username ALL=(ALL) ALL" >> /etc/sudoers.d/$username

# Zeitzone einstellen
read -p "Gib deine Zeitzone ein (z.B. Europe/Berlin): " timezone
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc

# Lokale Einstellungen auf Deutsch
echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=de_DE.UTF-8" > /etc/locale.conf

# Tastaturlayout auf de-latin1 setzen
echo "KEYMAP=de-latin1" > /etc/vconsole.conf

# Hostname setzen
read -p "Gib deinen Hostnamen ein: " hostname
echo $hostname > /etc/hostname

# Kernelparameter anpassen
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet pcie_aspm=force\"" >> /etc/default/grub

# Automatische Partitionierung und Formatierung (ext4)
echo "Automatische Partitionierung wird durchgeführt. Das Root-FS wird mit ext4 formatiert."
cfdisk /dev/sda
read -p "Drücke Enter, nachdem du die Partition erstellt und beendet hast: " wait_for_partition
read -p "Gib die Partition für das Root-Filesystem an (z.B. /dev/sda1): " root_partition
mkfs.ext4 $root_partition
mount $root_partition /mnt

# Festplattenverschlüsselung
read -p "Möchtest du deine Festplatte verschlüsseln? (ja/nein): " encrypt_choice
if [ "$encrypt_choice" = "ja" ]; then
    echo "HINWEIS: Es wird empfohlen, die Festplatte zu verschlüsseln, besonders bei Laptops, um den Schutz Ihrer Daten zu gewährleisten. LUKS (Linux Unified Key Setup) ist eine häufig verwendete Methode für die Festplattenverschlüsselung in Arch Linux."
    cryptsetup luksFormat $root_partition
    cryptsetup open $root_partition cryptroot
    mkfs.ext4 /dev/mapper/cryptroot
    mount /dev/mapper/cryptroot /mnt
    echo "cryptdevice=$root_partition:cryptroot root=/dev/mapper/cryptroot" >> /etc/default/grub
fi

# Bootloader GRUB installieren
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Installiere Grafiksystem und gdm für COSMIC
sudo pacman -S xorg xorg-xinit gdm

# Wayland und benötigte Pakete
sudo pacman -S wayland libxkbcommon libinput mesa

# Installiere yay für AUR-Pakete
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Installiere COSMIC (ACHTUNG: Alpha-Version)
yay -S cosmic-session-git

# Aktiviere gdm und stelle sicher, dass COSMIC als Standard festgelegt ist
systemctl enable gdm

# Audio-Treiber (Intel HD Audio)
sudo pacman -S alsa-utils

# Audio-Optionen
read -p "Welches Audio-System möchtest du verwenden? (PulseAudio/Pipewire): " audio_system
case "$audio_system" in
    "PulseAudio")
        sudo pacman -S pulseaudio pulseaudio-alsa
        ;;
    *)
        echo "Pipewire wird als Standard verwendet."
        sudo pacman -S pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber
        systemctl --user enable pipewire-pulse.service
        systemctl --user enable pipewire.service
        systemctl --user enable wireplumber.service
        ;;
esac

# Intel-Mikrocode für den neuesten Kernel
sudo pacman -S intel-ucode

# Zusätzliche Software
read -p "Installiere zusätzliche Software? (ja/nein): " install_software
if [ "$install_software" = "ja" ]; then
    read -p "Welche Softwarepakete möchtest du installieren? (Komma getrennt, z.B. nano,firefox-de): " software_list
    IFS=',' read -ra ADDR <<< "$software_list"
    for i in "${ADDR[@]}"; do
        sudo pacman -S $i
    done
    read -p "Möchtest du nano als Standard-Editor setzen? (ja/nein): " set_nano
    if [ "$set_nano" = "ja" ]; then
        echo "export EDITOR=nano" >> /etc/profile
        echo "export VISUAL=nano" >> /etc/profile
        echo "export EDITOR=nano" >> /home/$username/.bashrc
        echo "export VISUAL=nano" >> /home/$username/.bashrc
    fi
else
    echo "Keine zusätzliche Software wird installiert."
fi

# Netzwerk
read -p "Möchtest du eine statische IP-Konfiguration einrichten? (ja/nein): " static_ip
if [ "$static_ip" = "ja" ]; then
    echo "Bitte konfiguriere die statische IP manuell in /etc/netctl/examples/ethernet-static."
    sudo pacman -S netctl
else
    echo "DHCP wird für die Netzwerkkonfiguration verwendet."
fi

# Firewall
read -p "Möchtest du eine Firewall installieren? (ufw/iptables/keine): " firewall_choice
case "$firewall_choice" in
    "ufw")
        sudo pacman -S ufw
        systemctl enable ufw
        ;;
    "iptables")
        sudo pacman -S iptables
        ;;
    *)
        echo "Keine Firewall wird installiert."
        ;;
esac

# Blacklisting
echo "Blacklisting aller unnötigen Module:"
echo "blacklist *" > /etc/modprobe.d/blacklist-all.conf

# Whitelist für notwendige Laptop-Treiber
echo "Whitelist für notwendige Laptop-Treiber:"
echo "blacklist *" | grep -v "i915" | grep -v "snd_hda_intel" | grep -v "ehci_pci" | grep -v "xhci_hcd" | grep -v "ahci" | grep -v "usb_storage" > /etc/modprobe.d/blacklist-needed.conf

# Power Management
read -p "Möchtest du Power Management (tlp) installieren? (ja/nein): " install_tlp
if [ "$install_tlp" = "ja" ]; then
    sudo pacman -S tlp
    systemctl enable tlp
fi

# Abschluss
echo "Skript ausgeführt! Bitte rebooten, um die Änderungen zu übernehmen und COSMIC zu starten."
