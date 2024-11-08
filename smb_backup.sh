#!/bin/bash

# Variablen
WINDOWS_IP="192.168.10.4"         
CREDENTIALS_FILE="/opt/setup/.smb_credentials"  
BACKUP_DRIVE="/mnt/windows_temp_drive" 
LOCAL_BACKUP_DIR="/mnt/backup_drive"  
LOG_FILE="/var/log/smb_backup.log"  
DATE=$(date +"%Y-%m-%d_%H-%M-%S")   

# Sicherstellen, dass das Backup-Verzeichnis existiert
if [ ! -d "$BACKUP_DRIVE" ]; then
    sudo mkdir -p "$BACKUP_DRIVE"
fi

if [ ! -d "$LOCAL_BACKUP_DIR" ]; then
    mkdir -p "$LOCAL_BACKUP_DIR"
fi

# Windows-Ordner aus der Datei lesen
if [ ! -f "/opt/setup/.backup_ordner" ]; then
    echo "Ordnerdatei existiert nicht: /opt/setup/.backup_ordner" | tee -a "$LOG_FILE"
    exit 1
fi

# Durch die Ordner in der Datei iterieren
while IFS= read -r WINDOWS_SHARE; do
    echo "Mounten der Windows-Freigabe: $WINDOWS_SHARE..." | tee -a "$LOG_FILE"

    # Mounten der Windows-Freigabe
    sudo mount -t cifs "//$WINDOWS_IP/$WINDOWS_SHARE" "$BACKUP_DRIVE" -o credentials="$CREDENTIALS_FILE",vers=3.0,file_mode=0777,dir_mode=0777

    if [ $? -eq 0 ]; then
        echo "Freigabe $WINDOWS_SHARE erfolgreich gemountet." >> "$LOG_FILE"

        # Sicherstellen, dass das Zielverzeichnis existiert
        mkdir -p "$LOCAL_BACKUP_DIR/backup_$DATE/$WINDOWS_SHARE"

        # Backup mit rsync
        echo "Starte das Backup von $WINDOWS_SHARE..." | tee -a "$LOG_FILE"
        rsync -avh --progress --delete --partial "$BACKUP_DRIVE/" "$LOCAL_BACKUP_DIR/backup_$DATE/$WINDOWS_SHARE"

        if [ $? -eq 0 ]; then
            echo "Backup erfolgreich abgeschlossen für $WINDOWS_SHARE am $DATE" | tee -a "$LOG_FILE"
        else
            echo "Backup fehlgeschlagen für $WINDOWS_SHARE am $DATE" | tee -a "$LOG_FILE"
        fi

        # Freigabe unmounten
        echo "Unmounten der Freigabe $WINDOWS_SHARE..." >> "$LOG_FILE"
        sudo umount "$BACKUP_DRIVE"

        if [ $? -eq 0 ]; then
            echo "Freigabe $WINDOWS_SHARE erfolgreich unmounted." >> "$LOG_FILE"
        else
            echo "Fehler beim Unmounten der Freigabe $WINDOWS_SHARE." >> "$LOG_FILE"
        fi
    else
        echo "Fehler beim Mounten der Freigabe $WINDOWS_SHARE. Überprüfe die Logs mit 'dmesg' für mehr Informationen." >> "$LOG_FILE"
    fi
done < /opt/setup/.backup_ordner

# Log abschließen
echo "Backup abgeschlossen." | tee -a "$LOG_FILE"
