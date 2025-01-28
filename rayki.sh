#!/bin/bash

# Arch Linux Installationsskript mit lokaler KI (GPT4All) und hybrider Unterstützung

# --- Funktionen ---
setup_essentials() {
    echo "Installiere essenzielle Pakete..."
    pacstrap /mnt base linux linux-firmware
}

setup_drivers() {
    echo "Installiere notwendige Treiber basierend auf Hardware..."
    pacstrap /mnt amd-ucode mesa vulkan-radeon
}

configure_local_ai() {
    echo "Richte GPT4All ein..."
    # Python und Abhängigkeiten installieren
    arch-chroot /mnt pacman -S --noconfirm python python-pip
    arch-chroot /mnt pip install torch transformers langchain

    echo "Lade GPT4All-Modell herunter..."
    arch-chroot /mnt mkdir -p /opt/local-ai
    arch-chroot /mnt wget -O /opt/local-ai/gpt4all.bin "https://gpt4all.io/models/gpt4all-lora-quantized.bin"

    # Systemdienst erstellen
    echo "Erstelle Systemdienst für GPT4All..."
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
}

setup_hybrid_ai() {
    echo "Frage API-Schlüssel für OpenAI ab..."
    read -p "Möchtest du einen OpenAI-API-Schlüssel hinzufügen? (y/n): " add_api
    if [[ "$add_api" == "y" ]]; then
        read -sp "Gib deinen OpenAI-API-Schlüssel ein: " api_key
        arch-chroot /mnt mkdir -p /etc/local-ai
        echo "{\"mode\": \"hybrid\", \"api_key\": \"$api_key\"}" | arch-chroot /mnt tee /etc/local-ai/config.json
        echo "Hybride KI-Unterstützung aktiviert."
    else
        echo "Nur lokale KI wird verwendet."
    fi
}

# --- Hauptskript ---
echo "Starte Arch Linux Installation..."

# Partitionierung und Formatierung
read -p "Auf welcher Festplatte soll Arch installiert werden? (z.B. /dev/sda): " disk
parted $disk mklabel gpt
parted $disk mkpart primary ext4 1MiB 100%
mkfs.ext4 ${disk}1
mount ${disk}1 /mnt

# Basissystem einrichten
setup_essentials

# Treiber basierend auf Hardware installieren
setup_drivers

# Lokale KI einrichten
configure_local_ai

# Optionale hybride KI einrichten
setup_hybrid_ai

# Abschluss
echo "Arch Linux Installation abgeschlossen! Du kannst jetzt neustarten."
