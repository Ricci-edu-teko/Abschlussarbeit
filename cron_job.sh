#!/bin/bash

# Variablen
CRON_JOB="0 0 * * * /path/to/smb_backup.sh"  # Cron-Zeitplan für tägliche Ausführung um Mitternacht

# Überprüfen, ob der Cron-Job bereits existiert
if ! crontab -l | grep -q "$CRON_JOB"; then
    if (crontab -l; echo "$CRON_JOB") | crontab -; then
        echo "Cron-Job erfolgreich hinzugefügt: $CRON_JOB"
    else
        echo "Fehler beim Hinzufügen des Cron-Jobs."
    fi
else
    echo "Der Cron-Job existiert bereits."
fi
