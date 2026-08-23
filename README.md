## Projektzusammenfassung
Dezentrale Monitoring-Lösung für IP-Kameras mit Raspberry Pi unter Linux
 
Eine schlanke, dezentrale Überwachungsarchitektur für IP-Kameras in Kundennetzwerken.  
Jeder Standort erhält einen Raspberry Pi, der lokal die Erreichbarkeit der Kameras prüft und nur Status-/Alarm-Informationen an eine zentrale Instanz meldet. Der Zugriff erfolgt über einen Reverse-Tunnel – ohne Portweiterleitung auf Kundenseite.

## Warum das Projekt?

Problem: Kunden einer Sicherheitsfirma bemerken Kameraausfälle selber zuerst und dann meistens zu spät – weil die Überwachung über separate Hersteller-Dashboards läuft, welche nicht ständig einzeln aufgerufen wurden.
Ziel: Die Sicherheitsfirma will eine zentrale Sicht auf alle Kameras.

## Architektur-Entscheidung
 
**Ursprüngliche Idee – Zentrale Lösung**
 
Am Anfang lag der Fokus klar auf einer **zentralen** Monitoring-Architektur:
 
```
┌─────────────────────┐          Internet / Tunnel           ┌──────────────────────┐
│  Kundennetzwerk     │  ──────────────────────────────────> │  Zentrale Instanz    │
│                     │                                      │                      │
│  Raspberry Pi       │     Alle Status- und Metrikdaten     │  Zentrales Dashboard │
│  (nur Agent)        │      werden nach außen gesendet      │  + Alarmierung       │
│                     │                                      │                      │
│  IP-Kameras         │                                      └──────────────────────┘
└─────────────────────┘
```
 
**Gedanke dahinter:**  
Ein Raspberry Pi pro Standort sammelt die Erreichbarkeit der Kameras (und perspektivisch weitere Daten) und schickt alles an eine zentrale Monitoring-Instanz. Dort entsteht ein einheitliches Dashboard für alle Kundenstandorte. Techniker und Admins sehen auf einen Blick den Status aller Kameras und können bei Bedarf eingreifen.
 
Diese Herangehensweise wirkte zunächst logisch und übersichtlich – besonders wenn man an eine wachsende Anzahl von Standorten denkt.
 
### Der Umschwung – Warum dezentral?
 
Während der ersten Prototypen und der konkreten Anforderungsanalyse wurde schnell klar, dass die zentrale Variante für die eigentliche Aufgabenstellung Over-Engineering ist:
 
<ins>**Kernprinzip: Daten bleiben lokal – nur die Information "Alles gut" oder "Problem" geht raus.**</ins> 

- Die aktuelle Anforderung beschränkt sich auf ein Erreichbarkeit-Ping, um eine generelle Machbarkeit zu evaluieren.
- Weitere Metriken (Systemzustand, Kameradaten etc.) können später hinzukommen, in Form von weiteren Alert-Pings, wenn Schwellenwerte überschritten sind – die eigentlichen Metriken müssen aber nicht permanent das Kundennetzwerk verlassen.
- Unnötiger Bandbreitenverbrauch entsteht, sobald viele Standorte gleichzeitig Daten senden.
- Daten, die lokal bleiben können, erhöhen die Angriffsfläche und werfen Datenschutzfragen auf, wenn sie dauerhaft ins Internet gehen.
- Einfache Skalierbarkeit für mehrere Kunden
- Ein schlankes Edge-Device ist stabiler und einfacher zu warten als ein voller Monitoring-Agent mit vielen Abhängigkeiten.
 
**Ergebnis der Abwägung:**
 
| Kriterium              | Zentrale Lösung                  | Dezentrale Lösung                     |
|------------------------|----------------------------------|---------------------------------------|
| Bandbreite             | Hoch (alle Daten raus)           | Minimal (nur Status + Alarme)         |
| Daten verbleiben       | Zentral / Internet               | Lokal im Kundennetz                   |
| Komplexität am Edge    | Hoch                             | Niedrig                               |
| Erweiterbarkeit        | Teuer (alles muss rüber)         | Günstig (Metriken bleiben vor Ort)    |
| Angriffsfläche         | Größer                           | Kleiner                               |
| Skalierbarkeit         | Begrenzt                         | Gut (viele Standorte möglich)         |
 
---
**Die Entscheidung fiel deshalb auf eine dezentrale Architektur**
 
```
┌─────────────────────┐          Cloudflare Tunnel           ┌──────────────────────┐
│  Kundennetzwerk     │  <─────────────────────────────────> │  Zentrale Instanz    │
│                     │                                      │                      │
│  Raspberry Pi       │  Raspberry + Cam-Alive-Ping + Alarme │  Uptime-Kuma         │
│  ├─ Debian / RPi OS │  ──────────────────────────────────> │  (Status + Alerts)   │
│  ├─ M/Monit         │                                      │                      │
│  │   └─ Ping Checks │                                      └──────────────────────┘
│  ├─ iptables        │
│  ├─ fail2ban        │
│  └─ unattended-upgr.│
│                     │
│  IP-Kameras         │   (weitere Metriken bleiben lokal!!)
└─────────────────────┘
```
 
**Kernprinzip der finalen Lösung:**  
Der Raspberry Pi überwacht die Kameras **lokal** mit M/Monit. An die zentrale Instanz gehen nur:
- Webhook-basierte Alarmierung mit drei Komponenten:
  - **Kamera-Alarm-Webhook** – wird von M/Monit bei Kameraausfall getriggert
  - **Raspberry-Alive-Ping** – der Pi meldet sich regelmäßig bei Uptime-Kuma
  - **Timeout-Alarm** – wird in Uptime-Kuma ausgelöst, wenn der Alive-Ping ausbleibt
 
Admins können sich bei Bedarf über den Cloudflare-Tunnel auf den Pi schalten und dort tiefer analysieren.
Sie bekommen auch eine Nachricht über Uptime-Kuma falls der Raspberry ausfällt.
Damit ist die Lösung schlanker, sicherer und gleichzeitig die bessere Grundlage für spätere Erweiterungen.

## Kernfunktionen
 
- **Lokale Erreichbarkeitsüberwachung** der IP-Kameras per ICMP (M/Monit)
- **Alive-Ping** vom Raspberry Pi an die zentrale Uptime-Kuma-Instanz
- **Webhook-basierte Alarmierung** (Push bei Fehler, Timeout-Alarm wenn Alive-Ping ausbleibt)
- **Dauerhafter Reverse-Tunnel** (Cloudflare) für SSH-Zugriff ohne Portweiterleitung
- **Systemhärtung** des Raspberry Pi
- Vollständig headless betreibbar
 
## Tech-Stack

---
| Komponente              | Technologie                          | Zweck                              |
|-------------------------|--------------------------------------|------------------------------------|
| Hardware                | Raspberry Pi 4                       | Edge-Device                        |
| Betriebssystem          | Debian / Raspberry Pi OS             | Leichtgewichtig, stabil            |
| Lokales Monitoring      | M/Monit                              | ICMP-Checks, Webhook-Trigger       |
| Zentrales Monitoring    | Uptime-Kuma                          | Dashboard, Multi-Channel-Alerts    |
| Tunnel                  | Cloudflare Tunnel (cloudflared)      | Reverse-Zugang ohne Portforward    |
| Firewall                | iptables                             | Minimal offene Ports               |
| Intrusion Prevention    | fail2ban                             | Brute-Force-Schutz                 |
| Updates                 | unattended-upgrades                  | Automatische Security-Patches      |
| Orchestrierung          | systemd                              | Services & Timer                   |
| Skripting               | Bash                                 | Dummy-Interfaces, Alive-Ping, etc. |
---

## Schutzbedarfsanalyse
 
Um das Schadensrisiko einzuschätzen, wurden vor der Umsetzung mögliche Bedrohungsszenarien bewertet:
 
| Szenario | Ursache | Auswirkung | Einstufung |
|----------|---------|------------|------------|
| Ausfall der Hardware | Naturkatastrophen, Stromausfall, Hardwaredefekte | Funktionsverlust des Systems und der Überwachungskameras | Mittel |
| Ausfall der Konnektivität | Netzwerkprobleme, ISP-Ausfälle | Verlust der Verbindung zum Internet, beeinträchtigte Fernüberwachung und Wartung | Mittel |
| Kompromittierung des Systems | Selbstverschuldeter Fehler oder Angriffe durch Dritte | Möglicher weiterer Zugriff auf das Kundennetzwerk, im schlimmsten Fall Ausschalten der gesamten Alarm- und Überwachungsanlage | **Existenzbedrohend** |
 
Da der Raspberry Pi direkt ins Kundennetzwerk eingebunden wird, trägt der Betreiber der Lösung Verantwortung für mögliche Schäden bei einer Kompromittierung. Bei einer größeren Zahl angeschlossener Kundenstandorte wird dieses Szenario deshalb als existenzbedrohend eingestuft – der Hauptgrund für die konsequente Systemhärtung.
 
## Projektphasen (kurz)
 
1. **Analyse**  
   Ist-Zustand: Hersteller-Dashboards, keine zentrale Sicht, Kunden erlauben keine Portweiterleitung.  
   Schutzbedarfsanalyse (Verfügbarkeit, Vertraulichkeit, Integrität) → Einstufung „hoch" wegen potenzieller Netzwerk-Kompromittierung.
 
2. **Entwurf**  
   Software-Evaluation + Nutzwertanalyse (Netdata, Grafana-Stack, M/Monit, Checkmk):
 
   | Kriterium            | Gewicht | NetData | Grafana | M/Monit       | CheckMk |
   |----------------------|---------|---------|---------|---------------|---------|
   | Schlichtheit         | 35%     | 6 (2,1) | 3 (1,05)| 9 (3,15)      | 6 (2,1) |
   | Stabilität           | 35%     | 6 (2,1) | 5 (1,75)| 8 (2,8)       | 8 (2,8) |
   | Nutzerfreundlichkeit | 20%     | 5 (1,0) | 5 (1,0) | 7 (1,4)       | 5 (1,0) |
   | Größe                | 5%      | 7 (0,35)| 4 (0,2) | 6 (0,3)       | 4 (0,2) |
   | Community            | 5%      | 7 (0,35)| 9 (0,45)| 4 (0,2)       | 7 (0,35)|
   | **Gesamt**           | 100%    | 31 (5,9)| 26(4,45)| **34 (7,85)** | 30(6,35)|
 
   Bewertungsskala 1–10. M/Monit gewinnt klar bei den zwei am höchsten gewichteten Kriterien (Schlichtheit, Stabilität) und wird deshalb für die dezentrale Erreichbarkeitsprüfung eingesetzt.
 
3. **Realisierung**  
   - Headless-Installation via Raspberry Pi Imager (SSH, Hostname, WLAN vorab)  
   - Härtung (Dienste deaktivieren, iptables, fail2ban, unattended-upgrades)  
   - cloudflared als systemd-Service  
   - M/Monit-Agent + Alive-Ping-Skript als systemd-Service  
   - Uptime-Kuma mit zwei Push-Webhooks (Kamera-Alarm + Raspberry Alive + Alive-Timeout)
 
4. **Test**  
   In VirtualBox (zwei Debian-VMs), Dummy-Interfaces + Randomizer-Skript simulieren Kamerausfälle.
 
## Sicherheitsmaßnahmen (Härtung)
 
```bash
# Nicht benötigte Dienste deaktivieren
bluetooth, cups, avahi-daemon, rpcbind, nfs-*, smbd, nmbd, 
winbind, vsftpd, bind9, apache2, mysql, postfix …
 
# iptables – Default DROP, nur notwendige Ports
22 (SSH), 80/443 (falls benötigt), 8080 (optional)
ESTABLISHED,RELATED erlaubt, Logging verweigerter Pakete
 
# fail2ban
bantime / findtime / maxretry angepasst
 
# unattended-upgrades
Automatische Security-Updates aktiv
```
 
## Cloudflare Tunnel Installation
```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm.deb
sudo dpkg -i cloudflared.deb
sudo cloudflared service install --legacy-token <TOKEN>
```
Cloudflare Tunnel ersetzt klassische Portweiterleitung → kein offener Port am Kundenrouter.
 
## Beispiel-Skripte/Konfiguration (Auszug)
 
**M/Monit-Konfiguration (Kernlogik)**
 
Prüft alle 5 Sekunden die Erreichbarkeit der drei Dummy-Interfaces (Kamera-Ersatz), löst bei Fehlschlag sofort den Alarm-Webhook aus:
 
```
# /etc/monit/monitrc – Auszug
set daemon 5              # Prüfintervall: alle 5 Sekunden
 
check host dummy1 with address 192.168.1.201
    if failed ping then exec "/usr/local/bin/trigger-webhook.sh"
 
check host dummy2 with address 192.168.1.202
    if failed ping then exec "/usr/local/bin/trigger-webhook.sh"
 
check host dummy3 with address 192.168.1.203
    if failed ping then exec "/usr/local/bin/trigger-webhook.sh"
```
 
**Alive-Ping (systemd-Service)**
```bash
#!/bin/bash
notification_url="https://<uptime-kuma>/api/push/<token>?status=up&msg=OK&ping="
while true; do
  response=$(curl -s -o /dev/null -w "%{http_code}" "$notification_url")
  # Logging + Fehlerbehandlung
  sleep 60
done
```
 
**Dummy-Interfaces für Tests** (systemd oneshot) + Randomizer, der Interfaces zufällig up/down schaltet – ideal zum Simulieren von Kamerausfällen.
 
## Was das Projekt zeigt
 
- Selbstständige Konzeption einer skalierbaren, dezentralen Monitoring-Architektur
- Sichere Einbindung von Edge-Devices in fremde Netze (ohne Portforward)
- Praxisnahe Linux-Systemadministration (Debian/RPi OS, systemd, iptables, fail2ban)
- Bash-Skripting + systemd-Service-Integration
- Monitoring-Tools (M/Monit, Uptime-Kuma) und Webhook-basierte Alarmierung
- Strukturiertes Vorgehen: Analyse → Nutzwertanalyse → Härtung → Test (VM + Labor)
- Bewusstes Abwägen von Bandbreite, Datenschutz und Erweiterbarkeit
 
## Lessons Learned
 
- **SSH-Reverse-Tunnel in der Praxis zu instabil.** Die erste produktive Umsetzung lief über einen SSH-Reverse-Tunnel mit Portweiterleitung, kombiniert mit Grafana und InfluxDB als Monitoring-Stack. Der Tunnel brach im laufenden Betrieb wiederholt zusammen – der genaue Auslöser ließ sich im Nachhinein nicht mehr eindeutig rekonstruieren. Der Umstieg auf Cloudflare Tunnel löste das Stabilitätsproblem zuverlässig.
- **Weniger Daten senden statt mehr.** Mit dem technischen Wechsel kam auch ein Umdenken beim Datenumfang: Statt fortlaufend Metriken der Kundennetzwerke nach außen zu senden, sollte im Regelbetrieb nur ein einfacher Alive-Ping laufen. Bleibt der Ping aus, bekommt der Admin eine Meldung und schaut gezielt nach – statt dass ständig alle Daten das Kundennetz verlassen. Lokale Metriken bleiben als Option für die tiefere Analyse vor Ort erhalten, statt sie dauerhaft zu übertragen.
- **Härtung von Anfang an mitgeplant, nicht nachträglich draufgesetzt.** iptables, fail2ban und unattended-upgrades waren von der ersten Debian-Installation an Teil des Setups – das war spürbar einfacher, als sie später auf ein bereits laufendes System aufzusetzen.
 
## Mögliche Weiterentwicklungen
 
- Zusätzliche lokale Metriken (CPU, Memory, Kamera-Status über ONVIF/RTSP)
- Automatisierte Provisionierung (Ansible / cloud-init)
- Zentrale Aggregation mehrerer Standorte mit Rollen/Rechte
- High-Availability für die zentrale Uptime-Kuma-Instanz
- Integration in bestehende Ticket-/Alert-Systeme
 

