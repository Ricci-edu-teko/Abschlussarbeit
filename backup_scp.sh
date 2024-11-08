#!/bin/bash

# Variablen
WINDOWS_USER="windows_user"      # Windows-Benutzername
WINDOWS_IP="192.168.10.2"        # IP-Adresse des Windows-PCs
WINDOWS_BACKUP_PATH="C:/Users"   # Alternativer Pfad für Windows-Nutzer
BACKUP_DRIVE="/mnt/backup_drive/windows_backup"  # Backup-Speicherort auf dem Raspberry Pi
PASSWORD_FILE="$HOME/.backup_password"  # Optional: Datei zum Speichern des Passworts
LOG_FILE="/var/log/backup_scp.log" # Log-Datei für das Backup
CRON_INTERVAL_HOURS=24  # Intervall für die Backups (in Stunden)

# Funktion zur Einrichtung von SCP-Backup
setup_backup() {
  echo "Starte das SCP Backup-Setup..."

  # Sicherstellen, dass der Backup-Pfad existiert
  if [ ! -d "$BACKUP_DRIVE" ]; then
    sudo mkdir -p "$BACKUP_DRIVE"
    echo "Backup-Speicherort $BACKUP_DRIVE wurde erstellt."
  fi

  echo "Setup abgeschlossen."
}

# Funktion zur Abfrage oder zum Laden des Passworts
get_password() {
  if [ -f "$PASSWORD_FILE" ]; then
    PASSWORD=$(cat "$PASSWORD_FILE")
  else
    read -sp "Geben Sie das Passwort für $WINDOWS_USER@$WINDOWS_IP ein: " PASSWORD
    echo ""
  fi
}

# Funktion für das eigentliche Backup mit SCP
perform_backup() {
  echo "Starte Backup mit SCP..." >> "$LOG_FILE"
  DATE=$(date +"%Y-%m-%d_%H-%M-%S")
  BACKUP_DIR="$BACKUP_DRIVE/backup_$DATE"

  # Erstelle Verzeichnis für das aktuelle Backup
  mkdir -p "$BACKUP_DIR"

  # Führe SCP-Befehl aus, um Daten vom Windows-PC zu übertragen
  sshpass -p "$PASSWORD" scp -r "$WINDOWS_USER@$WINDOWS_IP:\"$WINDOWS_BACKUP_PATH\"" "$BACKUP_DIR"

  if [ $? -eq 0 ]; then
    echo "Backup erfolgreich abgeschlossen am $DATE" >> "$LOG_FILE"
  else
    echo "Backup fehlgeschlagen am $DATE" >> "$LOG_FILE"
  fi
}

# Funktion zur Einrichtung eines Cron-Jobs für das automatische Backup
setup_cron() {
  CRON_JOB="0 */$CRON_INTERVAL_HOURS * * * $HOME/backup_scp.sh"
  
  # Prüfen, ob der Cron-Job bereits existiert
  if ! crontab -l | grep -q "$HOME/backup_scp.sh"; then
    (crontab -l ; echo "$CRON_JOB") | crontab -
    echo "Cron-Job für automatisches Backup alle $CRON_INTERVAL_HOURS Stunden wurde eingerichtet."
  else
    echo "Cron-Job existiert bereits."
  fi
}

# Hauptlogik
echo "----- SCP Backup Skript -----"
setup_backup
get_password  # Passwort abfragen oder aus Datei laden
perform_backup
setup_cron
