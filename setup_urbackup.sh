#!/bin/bash
 2.  
 3. # 1. Update das System
 4. sudo apt-get update && sudo apt-get upgrade -y
 5.  
 6. # 2. Festplatte mounten
 7. # 2.1 Überprüfen, ob die Festplatte verfügbar ist (Annahme: /dev/sda1)
 8. DRIVE="/dev/sda1"
 9. MOUNTPOINT="/var/urbackup"
10.  
11. # Erstelle den UrBackup-Standardpfad, falls er noch nicht existiert
12. sudo mkdir -p $MOUNTPOINT
13.  
14. # 2.2 Festplatte formatieren (optional, falls nicht formatiert, Dateisystem ist hier ext4)
15. sudo mkfs.ext4 $DRIVE
16.  
17. # 2.3 Die Festplatte mounten
18. sudo mount $DRIVE $MOUNTPOINT
19.  
20. # Überprüfen, ob das Mounten erfolgreich war
21. if mount | grep $DRIVE > /dev/null; then
22.     echo "Externe Festplatte erfolgreich gemountet."
23. else
24.     echo "Fehler beim Mounten der externen Festplatte."
25.     exit 1
26. fi
27.  
28. # 2.4 Festplatte in /etc/fstab eintragen, damit sie bei jedem Neustart automatisch gemountet wird
29. UUID=$(sudo blkid -s UUID -o value $DRIVE)
30. echo "UUID=$UUID $MOUNTPOINT ext4 defaults 0 0" | sudo tee -a /etc/fstab
31.  
32. # 3. Installation von UrBackup
33. # 3.1 Installation der notwendigen Abhängigkeiten
34. sudo apt-get install -y build-essential cmake libcrypto++-dev zlib1g-dev \
35.   libssl-dev libcurl4-openssl-dev libfuse-dev pkg-config fuse git
36.  
37. # 3.2 Füge das UrBackup-Repository hinzu
38. echo "deb http://download.opensuse.org/repositories/home:/uroni/Raspbian_10/ /" | sudo tee /etc/apt/sources.list.d/urbackup.list
39. wget -qO - https://download.opensuse.org/repositories/home:/uroni/Raspbian_10/Release.key | sudo apt-key add -
40.  
41. # 3.3 Installiere UrBackup Server
42. sudo apt-get update
43. sudo apt-get install -y urbackup-server
44.  
45. # 4. Konfiguration von UrBackup
46. # Setzt den Backup-Pfad auf das gemountete Laufwerk (gemäss dem UrBackup-Standardpfad /var/urbackup)
47. sudo urbackupsrv set-settings --backuppath=$MOUNTPOINT
48.  
49. # 5. Starte den UrBackup Server
50. sudo systemctl start urbackupsrv
51.  
52. # 6. Aktiviere UrBackup beim Systemstart
53. sudo systemctl enable urbackupsrv
54.  
55. echo "UrBackup wurde erfolgreich installiert und konfiguriert."
56. echo "Das Webinterface ist erreichbar unter http://<Raspberry_Pi_IP>:55414"
