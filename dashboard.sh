#!/bin/bash

# Pakete installieren
echo "Installiere benötigte Pakete..."
apt update
apt install -y python3 python3-pip python3-venv cron

# Virtuelle Umgebung erstellen und aktivieren
echo "Erstelle und aktiviere die virtuelle Umgebung..."
python3 -m venv venv
source venv/bin/activate

# Flask und weitere Python-Pakete installieren
echo "Installiere Python-Pakete..."
pip install Flask matplotlib

# Verzeichnisstruktur anlegen
echo "Erstelle Verzeichnisstruktur..."
mkdir -p /opt/setup/static
touch /var/log/smb_backup.log
touch /etc/cron.d/smb_backup
touch /opt/setup/.backup_ordner

# app.py erstellen
cat << EOF > /opt/setup/app.py
from flask import Flask, render_template, request, redirect, url_for
import os
import subprocess
import matplotlib.pyplot as plt

app = Flask(__name__)
BACKUP_DIR = "/mnt/backup_drive"
LOG_FILE = "/var/log/smb_backup.log"
CRON_JOB_FILE = "/etc/cron.d/smb_backup"
BACKUP_FOLDER_FILE = "/opt/setup/.backup_ordner"

@app.route('/')
def index():
    total, used, free = get_storage_info(BACKUP_DIR)
    storage_graph(total, used, free)
    backup_folders = get_backup_folders()
    cron_jobs = get_cron_jobs()
    last_log_lines = get_last_log_lines()
    return render_template('index.html', total=total, used=used, free=free,
                           backup_folders=backup_folders, cron_jobs=cron_jobs,
                           last_log_lines=last_log_lines)

@app.route('/add_cronjob', methods=['POST'])
def add_cronjob():
    cron_expression = request.form.get('new_cronjob')
    if cron_expression:
        try:
            with open(CRON_JOB_FILE, 'a') as f:
                f.write(f"{cron_expression}\\n")
            return redirect(url_for('index'))
        except Exception as e:
            return f"Fehler beim Hinzufügen des Cron-Jobs: {str(e)}", 500
    return "Ungültige Cron-Job-Eingabe", 400

@app.route('/remove_cronjob', methods=['POST'])
def remove_cronjob():
    cron_to_remove = request.form.get('cron_to_remove')
    if cron_to_remove:
        try:
            cron_jobs = get_cron_jobs()
            cron_jobs.remove(cron_to_remove)
            with open(CRON_JOB_FILE, 'w') as f:
                f.writelines([f"{cron}\\n" for cron in cron_jobs])
            return redirect(url_for('index'))
        except Exception as e:
            return f"Fehler beim Entfernen des Cron-Jobs: {str(e)}", 500
    return "Ungültiger Cron-Job", 400

@app.route('/run_backup', methods=['POST'])
def run_backup():
    try:
        subprocess.run(['/opt/setup/smb_backup.sh'])
        return redirect(url_for('index'))
    except Exception as e:
        return f"Fehler beim Starten des Backups: {str(e)}", 500

@app.route('/add_backup_folder', methods=['POST'])
def add_backup_folder():
    new_folder = request.form.get('new_folder')
    if new_folder:
        try:
            with open(BACKUP_FOLDER_FILE, 'a') as f:
                f.write(f"{new_folder}\\n")
            return redirect(url_for('index'))
        except Exception as e:
            return f"Fehler beim Hinzufügen des Backup-Ordners: {str(e)}", 500
    return "Ungültiger Ordner", 400

@app.route('/remove_backup_folder', methods=['POST'])
def remove_backup_folder():
    folder_to_remove = request.form.get('folder_to_remove')
    if folder_to_remove:
        try:
            backup_folders = get_backup_folders()
            backup_folders.remove(folder_to_remove)
            with open(BACKUP_FOLDER_FILE, 'w') as f:
                f.writelines([f"{folder}\\n" for folder in backup_folders])
            return redirect(url_for('index'))
        except Exception as e:
            return f"Fehler beim Entfernen des Backup-Ordners: {str(e)}", 500
    return "Ungültiger Ordner", 400

def get_storage_info(path):
    statvfs = os.statvfs(path)
    total = statvfs.f_frsize * statvfs.f_blocks
    used = statvfs.f_frsize * (statvfs.f_blocks - statvfs.f_bfree)
    free = statvfs.f_frsize * statvfs.f_bavail
    return total, used, free

def storage_graph(total, used, free):
    labels = ['Verwendet', 'Frei']
    sizes = [used, free]
    colors = ['#ff9999','#66b3ff']
    fig, ax = plt.subplots()
    ax.pie(sizes, labels=labels, colors=colors, autopct='%1.1f%%', startangle=90)
    ax.axis('equal')
    plt.savefig('/opt/setup/static/storage_graph.png')
    plt.close()

def get_backup_folders():
    try:
        with open(BACKUP_FOLDER_FILE, 'r') as f:
            return [line.strip() for line in f.readlines()]
    except Exception:
        return []

def get_cron_jobs():
    try:
        with open(CRON_JOB_FILE, 'r') as f:
            return [line.strip() for line in f.readlines()]
    except Exception:
        return []

def get_last_log_lines():
    try:
        with open(LOG_FILE, 'r') as log_file:
            lines = log_file.readlines()
            return lines[-5:]
    except Exception:
        return ["Log-Datei nicht verfügbar"]

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
EOF

# HTML-Template erstellen
cat << 'EOF' > /opt/setup/templates/index.html
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backup Dashboard</title>
    <link rel="stylesheet" href="/static/style.css">
</head>
<body>
    <header>
        <h1>Backup Dashboard</h1>
    </header>

    <section>
        <h2>Speicherkapazität</h2>
        <div class="storage-info">
            <div class="storage-details">
                <p>Gesamt: {{ total | filesizeformat }}</p>
                <p>Verwendet: {{ used | filesizeformat }}</p>
                <p>Frei: {{ free | filesizeformat }}</p>
            </div>
            <img src="/static/storage_graph.png" alt="Speicherkapazität" class="storage-graph">
        </div>
    </section>

    <section>
        <h2>Backup-Ordner verwalten</h2>
        <form action="/add_backup_folder" method="POST">
            <label for="new_folder">Neuen Backup-Ordner hinzufügen:</label>
            <input type="text" id="new_folder" name="new_folder" required>
            <button type="submit">Hinzufügen</button>
        </form>

        <h3>Vorhandene Backup-Ordner</h3>
        <ul>
            {% for folder in backup_folders %}
            <li>
                {{ folder }}
                <form action="/remove_backup_folder" method="POST" style="display:inline;">
                    <input type="hidden" name="folder_to_remove" value="{{ folder }}">
                    <button type="submit">Löschen</button>
                </form>
            </li>
            {% endfor %}
        </ul>
    </section>

    <section>
        <h2>Cron-Jobs verwalten</h2>
        <form action="/add_cronjob" method="POST">
            <label for="new_cronjob">Neuen Cron-Job hinzufügen:</label>
            <input type="text" id="new_cronjob" name="new_cronjob" required>
            <button type="submit">Hinzufügen</button>
        </form>

        <h3>Vorhandene Cron-Jobs</h3>
        <ul>
            {% for cron in cron_jobs %}
            <li>
                {{ cron }}
                <form action="/remove_cronjob" method="POST" style="display:inline;">
                    <input type="hidden" name="cron_to_remove" value="{{ cron }}">
                    <button type="submit">Löschen</button>
                </form>
            </li>
            {% endfor %}
        </ul>
    </section>

    <section>
        <h2>Backup manuell starten</h2>
        <form action="/run_backup" method="POST">
            <button type="submit" style="background-color: orange; color: white; padding: 10px 20px; border: none; border-radius: 5px;">
                Backup jetzt starten
            </button>
        </form>
    </section>

    <section>
        <h2>Backup-Informationen (Letzte 5 Log-Zeilen)</h2>
        <ul>
            {% for line in last_log_lines %}
            <li>{{ line }}</li>
            {% endfor %}
        </ul>
    </section>

</body>
</html>
EOF

# CSS-Datei erstellen
cat << 'EOF' > /opt/setup/static/style.css
body {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: #f4f4f9;
}

header {
    background-color: #333;
    color: white;
    padding: 10px 0;
    text-align: center;
}

h1 {
    margin: 0;
}

section {
    margin-bottom: 30px;
}

h2 {
    color: #333;
    border-bottom: 2px solid #333;
    padding-bottom: 5px;
}

label {
    display: block;
    margin: 10px 0 5px;
}

input[type="text"] {
    width: 100%;
    padding: 8px;
    margin-bottom: 10px;
    border-radius: 4px;
    border: 1px solid #ccc;
}

button {
    padding: 10px 20px;
    background-color: #5cb85c;
    color: white;
    border: none;
    border-radius: 5px;
    cursor: pointer;
}

button:hover {
    background-color: #4cae4c;
}

ul {
    list-style-type: none;
    padding: 0;
}

li {
    margin: 10px 0;
}

form {
    display: inline;
}

button[type="submit"] {
    background-color: #d9534f;
}

button[type="submit"]:hover {
    background-color: #c9302c;
}


.storage-info {
    display: flex;
    align-items: center;
    justify-content: space-between; 
}

.storage-graph {
    max-width: 50%;  
    margin-left: 20px; 
}

.storage-details {
    flex-grow: 1; 
}
EOF

echo "Setup abgeschlossen. Starten Sie die App mit 'source venv/bin/activate' und 'python /opt/setup/app.py'"
