#!/bin/bash

# Variablen festlegen
MOUNT_DIR="/mnt/backup_drive"  # Das Verzeichnis, wo die Festplatte gemountet wird
DEVICE_PARTITION="/dev/sda2"   # Festplattenpartition (anpassen, falls nötig)
FILE_SYSTEM_TYPE="ext4"        # Dateisystem der Festplatte (anpassen, falls anders)

# UUID der Festplatte finden
UUID=$(blkid -s UUID -o value $DEVICE_PARTITION)

# Überprüfen, ob UUID gefunden wurde
if [ -z "$UUID" ]; then
    echo "Fehler: Konnte keine UUID für $DEVICE_PARTITION finden."
    exit 1
fi

echo "Gefundene UUID: $UUID"

# Überprüfen, ob das Mount-Verzeichnis existiert, wenn nicht, erstelle es
if [ ! -d "$MOUNT_DIR" ]; then
    echo "Erstelle Mount-Verzeichnis $MOUNT_DIR"
    sudo mkdir -p $MOUNT_DIR
else
    echo "Mount-Verzeichnis $MOUNT_DIR existiert bereits."
fi

# Backup der fstab erstellen
echo "Erstelle ein Backup der /etc/fstab"
sudo cp /etc/fstab /etc/fstab.backup.$(date +%F-%T)

# Überprüfen, ob der Eintrag bereits in der fstab existiert
grep -q "$UUID" /etc/fstab
if [ $? -eq 0 ]; then
    echo "Eintrag für $UUID existiert bereits in /etc/fstab."
else
    # Neuen Eintrag in /etc/fstab hinzufügen
    echo "Füge Eintrag für die Festplatte in /etc/fstab hinzu"
    echo "UUID=$UUID $MOUNT_DIR $FILE_SYSTEM_TYPE defaults 0 2" | sudo tee -a /etc/fstab
fi

# Mount-Konfiguration testen
echo "Teste die neuen Einträge mit 'sudo mount -a'"
sudo mount -a

# Überprüfen, ob die Festplatte korrekt gemountet wurde
if mountpoint -q "$MOUNT_DIR"; then
    echo "Die Festplatte wurde erfolgreich unter $MOUNT_DIR gemountet."
else
    echo "Fehler: Die Festplatte konnte nicht gemountet werden."
fi

echo "Skript abgeschlossen."
