#!/bin/bash

# Arch Linux Installationsskript mit Hardware-Erkennung, KI-Assistent, hybrider Unterstützung, Desktop-Auswahl, und Tool-Auswahl

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
    pacstrap /mnt networkmanager dhcpcd
    arch-chroot /mnt systemctl enable NetworkManager
}

setup_bootloader() {
    echo "Installiere Bootloader..."
    pacstrap /mnt grub efibootmgr dosfstools mtools
    mkdir -p /mnt/boot/efi
    mkfs.fat -F32 ${disk}1
    mount ${disk}1 /mnt/boot/efi
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

# --- Benutzerausrichtung ---

setup_gaming() {
    echo "Aktiviere multilib für Gaming-Unterstützung..."
    sed -i '/\[multilib\]/,/Include/s/^#//' /mnt/etc/pacman.conf
    arch-chroot /mnt pacman -Syu

    echo "Installiere Gaming-Pakete..."
    pacstrap /mnt lutris steam wine wine-gecko wine-mono

    echo "Installiere ProtonQT über Flatpak..."
    arch-chroot /mnt pacman -S --noconfirm flatpak
    arch-chroot /mnt flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    arch-chroot /mnt flatpak install -y flathub org.protonvpn.protonvpn-gui
}

setup_office() {
    echo "Wähle eine Office-Umgebung:"
    echo "1) LibreOffice"
    echo "2) Calligra (KDE Suite)"
    echo "3) Gnumeric und AbiWord (Leichtgewicht)"
    read -p "Deine Wahl: " office_choice

    case $office_choice in
        1)
            pacstrap /mnt libreoffice libreoffice-fresh
            ;;
        2)
            pacstrap /mnt calligra
            ;;
        3)
            pacstrap /mnt gnumeric abiword
            ;;
        *)
            echo "Ungültige Auswahl. Keine Office-Umgebung wird installiert."
            ;;
    esac
}

select_usage_profile() {
    echo "Wähle deinen Nutzungsprofil:"
    echo "1) Gaming"
    echo "2) Office"
    echo "3) Normal (Keine zusätzliche Software)"
    read -p "Deine Wahl: " profile_choice

    case $profile_choice in
        1)
            setup_gaming
            ;;
        2)
            setup_office
            ;;
        3)
            echo "Keine zusätzliche Software für den Normal-Modus wird installiert."
            ;;
        *)
            echo "Ungültige Auswahl. Kein spezifischer Modus wird installiert."
            ;;
    esac
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
        pacstrap /mnt python python-pip
        arch-chroot /mnt pip install --no-cache-dir torch transformers langchain
        arch-chroot /mnt mkdir -p /opt/local-ai
        arch-chroot /mnt wget -O /opt/local-ai/gpt4all.bin "https://gpt4all.io/models/gpt4all-lora-quantized.bin" || { echo "Download fehlgeschlagen"; exit 1; }

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
        parted $disk mklabel gpt
        parted $disk mkpart primary fat32 1MiB 512MiB
        parted $disk set 1 esp on
        parted $disk mkpart primary ext4 512MiB 100%
        mkfs.fat -F32 ${disk}1
        echo -n "Gib dein LUKS-Passwort ein: "
        read -s LUKS_PASS
        echo
        echo -n "Bestätige dein LUKS-Passwort: "
        read -s LUKS_PASS_CONFIRM
        echo
        if [[ "$LUKS_PASS" != "$LUKS_PASS_CONFIRM" ]]; then
            echo "Passwörter stimmen nicht überein. Abbruch."
            exit 1
        fi
        echo $LUKS_PASS | cryptsetup -y -v luksFormat ${disk}2
        echo $LUKS_PASS | cryptsetup open ${disk}2 my_encrypted_drive
        mkfs.ext4 /dev/mapper/my_encrypted_drive
        mount /dev/mapper/my_encrypted_drive /mnt
        mkdir -p /mnt/boot
        mount ${disk}1 /mnt/boot
    else
        echo "Keine Verschlüsselung."
        parted $disk mklabel gpt
        parted $disk mkpart primary ext4 1MiB 100%
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
    echo "$username ALL=(ALL) ALL" | arch-chroot /mnt tee -a /etc/sudoers
}

select_tools() {
    echo "Wähle die Tools, die du installieren möchtest. (y/n für jede Option)"
    declare -A tools
    tools[vim]="Vim Editor"
    tools[nano]="Nano Editor"
    tools[htop]="Htop - Systemüberwachung"
    tools[curl]="Curl - HTTP Client"
    tools[wget]="Wget - Dateiherunterlader"
    tools[neofetch]="Neofetch - System-Info Anzeige"
    tools[zsh]="Zsh - Shell"
    tools[fish]="Fish - Benutzerfreundliche Shell"
    tools[bash]="Bash - Standard Shell"
    tools[screen]="Screen - Terminal Multiplexer"
    tools[tmux]="Tmux - Terminal Multiplexer"
    tools[rsync]="Rsync - Dateisynchronisation"
    tools[tree]="Tree - Verzeichnisstruktur anzeigen"
    tools[lf]="Lf - Terminal Filemanager"
    tools[ffmpeg]="FFmpeg - Multimediatools"
    tools[vlc]="VLC - Mediaplayer"
    tools[gimp]="GIMP - Bildbearbeitung"
    tools[inkscape]="Inkscape - Vektorgrafik-Editor"
    tools[blender]="Blender - 3D-Modellierung"
    tools[kdenlive]="Kdenlive - Videobearbeitung"
    tools[obs-studio]="OBS Studio - Aufnahme- und Streaming-Software"
    tools[audacity]="Audacity - Audiobearbeitung"
    tools[spotify]="Spotify - Musik Streaming"
    tools[plex-media-server]="Plex Media Server - Medien-Server"
    tools[discord]="Discord - Kommunikations-App"
    tools[slack]="Slack - Team-Kommunikation"
    tools[thunderbird]="Thunderbird - E-Mail-Client"
    tools[chromium]="Chromium - Webbrowser"
    tools[firefox]="Firefox - Webbrowser"
    tools[vivaldi]="Vivaldi - Webbrowser"
    tools[qemu]="QEMU - Virtualisierung"
    tools[virtualbox]="VirtualBox - Virtualisierung"
    tools[docker]="Docker - Containerisierung"
    tools[podman]="Podman - Containerisierung"
    tools[wine]="Wine - Windows-Programme auf Linux"
    tools[lutris]="Lutris - Spielmanagement"
    tools[steam]="Steam - Spiel-Client"
    tools[playonlinux]="PlayOnLinux - Spiele und Windows-Anwendungen"
    tools[wine-gecko]="Wine Gecko - Webrendering für Wine"
    tools[wine-mono]="Wine Mono - .NET für Wine"
    tools[libreoffice]="LibreOffice - Office-Suite"
    tools[evince]="Evince - PDF-Viewer"
    tools[okular]="Okular - Dokumentenbetrachter"
    tools[calibre]="Calibre - E-Book Management"
    tools[syncthing]="Syncthing - Dateisynchronisation"
    tools[nextcloud-client]="Nextcloud Client - Cloud-Synchronisation"
    tools[dropbox]="Dropbox - Cloud-Synchronisation"
    tools[megasync]="MegaSync - Cloud-Synchronisation"
    tools[rclone]="Rclone - Cloud-Synchronisation"
    tools[rar]="RAR - Archivierung"
    tools[unrar]="UnRAR - Entpacken von RAR-Archiven"
    tools[zip]="Zip - Archivierung"
    tools[7zip]="7-Zip - Archivierung"
    tools[xarchiver]="Xarchiver - Archivmanager"
    tools[p7zip]="P7zip - 7-Zip für Linux"
    tools[unzip]="Unzip - Entpacken von ZIP-Archiven"
    tools[filezilla]="FileZilla - FTP-Client"
    tools[ssh]="SSH - Secure Shell"
    tools[nmap]="Nmap - Netzwerkscanner"
    tools[netcat]="Netcat - Netzwerk-Tool"
    tools[tcpdump]="Tcpdump - Netzwerkverkehr Aufzeichnen"
    tools[ufw]="UFW - Firewall"
    tools[firewalld]="Firewalld - dynamische Firewall"
    tools[fail2ban]="Fail2ban - Intrusion Prevention"
    tools[iproute2]="Iproute2 - Netzwerkmanagement"
    tools[wpa_supplicant]="WPA Supplicant - WLAN-Verbindung"
    tools[nmcli]="Nmcli - NetworkManager Command Line Interface"
    tools[iwctl]="IWD - Wireless Daemon"
    tools[bluez]="BlueZ - Bluetooth-Stack"
    tools[blueman]="Blueman - Bluetooth-Manager"
    tools[aircrack-ng]="Aircrack-ng - WLAN-Sicherheitswerkzeuge"
    tools[iw]="Iw - WLAN-Tool"
    tools[hostnamectl]="Hostnamectl - Hostname Verwaltung"
    tools[yay]="Yay - Paketmanager"
    tools[paru]="Paru - Paketmanager"
    tools[flatpak]="Flatpak - Anwendungspaketierung"
    tools[snapd]="Snapd - Anwendungspaketierung"
    tools[zfsutils-linux]="ZFS - Dateisystem"
    tools[btrfs-progs]="Btrfs - Dateisystem"
    tools[lvm2]="LVM - Logical Volume Manager"
    tools[cryptsetup]="Cryptsetup - Verschlüsselungswerkzeuge"
    tools[gparted]="GParted - Partitionierungswerkzeug"
    tools[gdisk]="Gdisk - Partitionierungswerkzeug"
    tools[dosfstools]="Dosfstools - FAT Dateisystem Tools"
    tools[lsscsi]="Lsscsi - SCSI Geräte auflisten"
    tools[smartmontools]="Smartmontools - Festplatten-Überwachung"
    tools[xfsprogs]="Xfsprogs - XFS Dateisystem Tools"
    tools[ntfs-3g]="NTFS-3G - NTFS Unterstützung"
    tools[f2fs-tools]="F2FS-Tools - Flash-Friendly File System Tools"
    tools[btop]="Btop - Systemüberwachung"
    tools[glances]="Glances - Systemüberwachung"
    tools[atop]="Atop - Systemüberwachung"
    tools[iostat]="Iostat - I/O-Statistik"
    tools[stress]="Stress - Systembelastung"
    tools[sysstat]="Sysstat - System Performance Tools"
    tools[sar]="SAR - System Activity Reporter"
    tools[nmon]="Nmon - Leistungsüberwachungswerkzeug"
    tools[uptime]="Uptime - Systemlaufzeit"
    tools[dstat]="Dstat - Systemstatistik"
    tools[time]="Time - Kommandozeiterfassung"
    tools[watch]="Watch - Wiederholte Ausführung von Kommandos"
    tools[logger]="Logger - Log-Nachrichten erstellen"
    tools[strace]="Strace - Systemaufrufe verfolgen"
    tools[ltrace]="Ltrace - Bibliotheksaufrufe verfolgen"
    tools[perf]="Perf - Leistungsanalyse"
    tools[gdb]="GDB - Debugger"
    tools[valgrind]="Valgrind - Speicherfehler-Detektor"
    tools[clang]="Clang - Compiler"
    tools[make]="Make - Build-Automatisierung"
    tools[gcc]="GCC - GNU Compiler Collection"
    tools[cmake]="CMake - Build-System"
    tools[build-essential]="Build-Essential - Build-Tools"
    tools[autoconf]="Autoconf - Build-Konfiguration"
    tools[automake]="Automake - Makefile-Generator"
    tools[pkg-config]="Pkg-config - Bibliothekskonfiguration"
    tools[python-pip]="Pip - Python Paketmanager"
    tools[pipx]="Pipx - Python Paketmanager"
    tools[nodejs]="Node.js - JavaScript Laufzeitumgebung"
    tools[npm]="NPM - Node Paketmanager"
    tools[yarn]="Yarn - Paketmanager für JavaScript"
    tools[ruby]="Ruby - Programmiersprache"
    tools[go]="Go - Programmiersprache"
    tools[rust]="Rust - Programmiersprache"
    tools[jdk]="JDK - Java Development Kit"
    tools[maven]="Maven - Java Build-Automatisierung"
    tools[gradle]="Gradle - Build-Automatisierung"
    tools[perl]="Perl - Programmiersprache"
    tools[php]="PHP - Web-Programmiersprache"
    tools[mysql]="MySQL - Datenbank"
    tools[postgresql]="PostgreSQL - Datenbank"
    tools[mongodb]="MongoDB - NoSQL Datenbank"
    tools[redis]="Redis - Schlüssel-Wert-Datenbank"
    tools[nginx]="Nginx - Webserver"
    tools[apache]="Apache - Webserver"
    tools[lighttpd]="Lighttpd - Leichtgewichtiger Webserver"
    tools[haproxy]="HAProxy - Load Balancer"
    tools[squid]="Squid - Web-Proxy"
    tools[unicorn]="Unicorn - Ruby Webserver"
    tools[rails]="Rails - Ruby Web-Framework"
    tools[fastfetch]="Fastfetch - System-Info Anzeige"

    selected_packages=""
    for pkg in "${!tools[@]}"; do
        read -p "Installiere ${tools[$pkg]}? (y/n): " choice
        if [[ "$choice" == "y" ]]; then
            selected_packages+=" $pkg"
        fi
    done

    if [ -n "$selected_packages" ]; then
        pacstrap /mnt $selected_packages || {
            echo "Fehler beim Installieren der Pakete. Bitte überprüfen Sie Ihre Internetverbindung oder die Paketnamen."
            exit 1
        }
    else
        echo "Keine zusätzlichen Tools ausgewählt."
    fi
}
    done

    if [ -n "$selected_packages" ]; then
        pacstrap /mnt $selected_packages
    else
        echo "Keine zusätzlichen Tools ausgewählt."
    fi
}

# --- Hauptskript ---
echo "Starte Arch Linux Installation..."

# Partitionierung und Formatierung
read -p "Auf welcher Festplatte soll Arch installiert werden? (z.B. /dev/sda): " disk
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
select_tools
setup_user_profile

echo "Arch Linux Installation abgeschlossen! Du kannst jetzt neustarten."
