#!/bin/bash

# Arch Linux Installationsskript mit Hardware-Erkennung, KI-Assistent, hybrider Unterstützung und Desktop-Auswahl

# --- Funktionen ---
setup_essentials() {
    echo "Installiere essenzielle Pakete..."
    pacstrap /mnt base linux linux-firmware
}

generate_fstab() {
    genfstab -U /mnt >> /mnt/etc/fstab
}

setup_timezone() {
    echo "Setze Zeitzone..."
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
    arch-chroot /mnt hwclock --systohc
}

setup_locale() {
    echo "Konfiguriere Locale..."
    echo "LANG=de_DE.UTF-8" > /mnt/etc/locale.conf
    echo "KEYMAP=de-latin1" > /mnt/etc/vconsole.conf
    arch-chroot /mnt sed -i 's/#\(de_DE\.UTF-8\)/\1/' /etc/locale.gen
    arch-chroot /mnt locale-gen
}

setup_network() {
    echo "Installiere Netzwerkdienste..."
    pacstrap /mnt networkmanager
    arch-chroot /mnt systemctl enable NetworkManager
}

setup_bootloader() {
    echo "Installiere Bootloader..."
    pacstrap /mnt grub
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

setup_drivers() {
    echo "Installiere notwendige Treiber basierend auf Hardware..."

    echo "Wähle deinen CPU-Hersteller:"
    echo "1) AMD"
    echo "2) Intel"
    echo "3) VM (Virtual Machine)"
    echo "4) Keine Ahnung (installiere alle CPU-Treiber)"
    read -p "Deine Wahl: " cpu_choice

    case $cpu_choice in
        1)
            pacstrap /mnt amd-ucode
            ;;
        2)
            pacstrap /mnt intel-ucode
            ;;
        3|4)
            pacstrap /mnt amd-ucode intel-ucode
            ;;
        *)
            echo "Ungültige Auswahl. Abbruch."
            exit 1
            ;;
    esac

    echo "Wähle deine GPU:"
    echo "1) AMD"
    echo "2) Nvidia"
    echo "3) Intel"
    echo "4) VM (Virtual Machine)"
    echo "5) Keine Ahnung (installiere alle GPU-Treiber)"
    read -p "Deine Wahl: " gpu_choice

    case $gpu_choice in
        1)
            pacstrap /mnt mesa vulkan-radeon
            ;;
        2)
            pacstrap /mnt nvidia nvidia-utils
            ;;
        3)
            pacstrap /mnt mesa vulkan-intel
            ;;
        4|5)
            pacstrap /mnt mesa vulkan-radeon vulkan-intel nvidia nvidia-utils
            ;;
        *)
            echo "Ungültige Auswahl. Abbruch."
            exit 1
            ;;
    esac
}

configure_local_ai() {
    echo "Möchtest du eine lokale KI (GPT4All) installieren? (y/n): "
    read -p "Deine Wahl: " install_ai
    if [[ "$install_ai" == "y" ]]; then
        echo "Richte GPT4All ein..."
        arch-chroot /mnt pacman -S --noconfirm python python-pip
        arch-chroot /mnt pip install torch transformers langchain
        arch-chroot /mnt mkdir -p /opt/local-ai
        arch-chroot /mnt wget -O /opt/local-ai/gpt4all.bin "https://gpt4all.io/models/gpt4all-lora-quantized.bin"

        cat <<EOF | arch-chroot /mnt tee /etc/systemd/system/local-ai.service
[Unit]
Description=Lokale KI mit GPT4All
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/local-ai/gpt4all_server.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

        arch-chroot /mnt systemctl enable local-ai.service

        echo "Möchtest du einen OpenAI-API-Schlüssel hinzufügen? (y/n): "
        read -p "Deine Wahl: " add_api
        if [[ "$add_api" == "y" ]]; then
            read -sp "Gib deinen OpenAI-API-Schlüssel ein: " api_key
            arch-chroot /mnt mkdir -p /etc/local-ai
            echo "{\"mode\": \"hybrid\", \"api_key\": \"$api_key\"}" | arch-chroot /mnt tee /etc/local-ai/config.json
            echo "Hybride KI-Unterstützung aktiviert."
        else
            echo "Nur lokale KI wird verwendet."
        fi
    else
        echo "KI-Installation übersprungen."
    fi
}

setup_desktop() {
    echo "Wähle eine Desktop-Umgebung:"
    echo "1) GNOME"
    echo "2) KDE Plasma"
    echo "3) XFCE"
    echo "4) Cinnamon"
    echo "5) MATE"
    echo "6) LXQt"
    echo "7) Deepin"
    echo "8) Budgie"
    echo "9) Pantheon (Elementary OS)"
    echo "10) Enlightenment"
    echo "0) Keine (nur CLI)"
    read -p "Deine Wahl: " desktop_choice

    case $desktop_choice in
        1)
            pacstrap /mnt gnome gnome-extra gdm
            arch-chroot /mnt systemctl enable gdm
            ;;
        2)
            pacstrap /mnt plasma kde-applications sddm
            arch-chroot /mnt systemctl enable sddm
            ;;
        3)
            pacstrap /mnt xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
            arch-chroot /mnt systemctl enable lightdm
            ;;
        4)
            pacstrap /mnt cinnamon nemo
            arch-chroot /mnt systemctl enable gdm
            ;;
        5)
            pacstrap /mnt mate mate-extra
            arch-chroot /mnt systemctl enable lightdm
            ;;
        6)
            pacstrap /mnt lxqt openbox
            arch-chroot /mnt systemctl enable sddm
            ;;
        7)
            pacstrap /mnt deepin
            arch-chroot /mnt systemctl enable lightdm
            ;;
        8)
            pacstrap /mnt budgie-desktop
            arch-chroot /mnt systemctl enable lightdm
            ;;
        9)
            pacstrap /mnt pantheon pantheon-*
            arch-chroot /mnt systemctl enable lightdm
            ;;
        10)
            pacstrap /mnt enlightenment
            arch-chroot /mnt systemctl enable enlightenment
            ;;
        0)
            echo "Keine Desktop-Umgebung wird installiert."
            ;;
        *)
            echo "Ungültige Auswahl. Kein Desktop wird installiert."
            ;;
    esac
}

setup_encryption() {
    echo "Möchtest du die Festplatte verschlüsseln? (y/n): "
    read -p "Deine Wahl: " encrypt_choice
    if [[ "$encrypt_choice" == "y" ]]; then
        echo "Verschlüssele die Festplatte..."
        cryptsetup -y -v luksFormat ${disk}1
        cryptsetup open ${disk}1 my_encrypted_drive
        mkfs.ext4 /dev/mapper/my_encrypted_drive
        mount /dev/mapper/my_encrypted_drive /mnt
    else
        echo "Keine Verschlüsselung."
        mkfs.ext4 ${disk}1
        mount ${disk}1 /mnt
    fi
}

setup_user_profile() {
    echo "Erstelle Benutzerprofil..."
    read -p "Gib den gewünschten Benutzernamen ein: " username
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    echo "Setze ein Passwort für $username:"
    arch-chroot /mnt passwd "$username"
    arch-chroot /mnt echo "$username ALL=(ALL) ALL" >> /etc/sudoers
}

# --- Hauptskript ---
echo "Starte Arch Linux Installation..."

# Partitionierung und Formatierung
read -p "Auf welcher Festplatte soll Arch installiert werden? (z.B. /dev/sda): " disk
parted $disk mklabel gpt
parted $disk mkpart primary ext4 1MiB 100%
setup_encryption

setup_essentials
generate_fstab
setup_timezone
setup_locale
setup_network
setup_bootloader
setup_drivers
configure_local_ai
setup_desktop
setup_user_profile

echo "Arch Linux Installation abgeschlossen! Du kannst jetzt neustarten."
