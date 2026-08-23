Dezentrale Monitoring-Lösung für IP-Kameras mit Raspberry Pi unter Linux

Eine schlanke, dezentrale Überwachungsarchitektur für IP-Kameras in Kundennetzwerken.  
Jeder Standort erhält einen Raspberry Pi, der lokal die Erreichbarkeit der Kameras prüft und nur Status-/Alarm-Informationen an eine zentrale Instanz meldet. Der Zugriff erfolgt über einen Reverse-Tunnel – ohne Portweiterleitung auf Kundenseite.

Ziel: Frühzeitige Erkennung von Kamerausfällen bei minimalem Bandbreitenverbrauch und hoher Sicherheit.

## Architektur-Entscheidung

**Ursprüngliche Idee – Zentrale Lösung**

Am Anfang lag der Fokus klar auf einer **zentralen** Monitoring-Architektur:

```
┌─────────────────────┐          Internet / Tunnel           ┌──────────────────────┐
│  Kundennetzwerk     │  ──────────────────────────────────  │  Zentrale Instanz    │
│                     │                                      │                      │
│  Raspberry Pi       │     Alle Status- und Metrikdaten     │  Zentrales Dashboard │
│  (nur Agent)        │     werden nach außen gesendet       │  + Alarmierung       │
│                     │                                      │                      │
│  IP-Kameras         │                                      └──────────────────────┘
└─────────────────────┘
```

**Gedanke dahinter:**  
Ein Raspberry Pi pro Standort sammelt die Erreichbarkeit der Kameras (und perspektivisch weitere Daten) und schickt alles an eine zentrale Monitoring-Instanz. Dort entsteht ein einheitliches Dashboard für alle Kundenstandorte. Techniker sehen auf einen Blick den Status aller Kameras und können bei Bedarf eingreifen.

Diese Herangehensweise wirkte zunächst logisch und übersichtlich – besonders wenn man an eine wachsende Anzahl von Standorten denkt.

### Der Umschwung – Warum dezentral?

Während der ersten Prototypen und der konkreten Anforderungsanalyse wurde schnell klar, dass die zentrale Variante für die eigentliche Aufgabenstellung Over-Engineering ist:

- Die aktuelle Anforderung beschränkt sich auf **Erreichbarkeit** (Ping) um eine generelle Machbarkeit zu evaluieren.
- Weitere Metriken (Systemzustand, Kameradaten etc.) können später hinzukommen – müssen aber nicht permanent das Kundennetz verlassen.
- Unnötiger Bandbreitenverbrauch entsteht, sobald viele Standorte gleichzeitig Daten senden.
- Daten, die lokal bleiben können, erhöhen die Angriffsfläche und werfen Datenschutzfragen auf, wenn sie dauerhaft ins Internet gehen.
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
│  Kundennetzwerk     │   ─────────────────────────────────  │  Zentrale Instanz    │
│                     │                                      │                      │
│  Raspberry Pi       │       Nur Alive-Ping + Alarme        │  Uptime-Kuma         │
│  ├─ Debian / RPi OS │   ─────────────────────────────────  │  (Status + Alerts)   │
│  ├─ M/Monit         │                                      │                      │
│  │   └─ Ping Checks │                                      └──────────────────────┘
│  ├─ iptables        │
│  ├─ fail2ban        │
│  └─ unattended-upgr.│
│                     │
│  IP-Kameras         │   (weitere Metriken bleiben lokal)
└─────────────────────┘
```

**Kernprinzip der finalen Lösung:**  
Der Raspberry Pi überwacht die Kameras **lokal** mit M/Monit. An die zentrale Instanz gehen nur:
1. Alive-Ping (Pi ist erreichbar)
2. Alarm-Webhook (Kamera nicht erreichbar)

Admins können sich bei Bedarf über den Cloudflare-Tunnel auf den Pi schalten und dort tiefer analysieren.  
Damit ist die Lösung schlanker, sicherer und gleichzeitig die bessere Grundlage für spätere Erweiterungen.

## Kernfunktionen

- **Lokale Erreichbarkeitsüberwachung** der IP-Kameras per ICMP (M/Monit)
- **Alive-Ping** vom Raspberry Pi an die zentrale Uptime-Kuma-Instanz
- **Webhook-basierte Alarmierung** (Push bei Fehler, Timeout-Alarm wenn Alive-Ping ausbleibt)
- **Dauerhafter Reverse-Tunnel** (Cloudflare) für SSH-Zugriff ohne Portweiterleitung
- **Systemhärtung** des Raspberry Pi
- Vollständig headless betreibbar

## Tech-Stack

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

## Projektphasen (kurz)

1. **Analyse**  
   Ist-Zustand: Hersteller-Dashboards, keine zentrale Sicht, Kunden erlauben keine Portweiterleitung.  
   Schutzbedarfsanalyse (Verfügbarkeit, Vertraulichkeit, Integrität) → Einstufung „hoch" wegen potenzieller Netzwerk-Kompromittierung.

2. **Entwurf**  
   Software-Evaluation + Nutzwertanalyse (Netdata, Grafana-Stack, M/Monit, Checkmk).  
   Entscheidung: M/Monit (einfach, stabil, leicht) auf dem Pi + Uptime-Kuma zentral.

3. **Realisierung**  
   - Headless-Installation via Raspberry Pi Imager (SSH, Hostname, WLAN vorab)  
   - Härtung (Dienste deaktivieren, iptables, fail2ban, unattended-upgrades)  
   - cloudflared als systemd-Service  
   - M/Monit-Agent + Alive-Ping-Skript als systemd-Service  
   - Uptime-Kuma mit zwei Push-Webhooks (Kamera-Alarm + Alive-Timeout)

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

Zusätzlich: Cloudflare Tunnel ersetzt klassische Portweiterleitung → kein offener Port am Kundenrouter.

## Beispiel-Skripte (Auszug)

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
- **Erst simulieren, dann ausrollen.** Die Dummy-Interfaces mit Randomizer-Skript zum Simulieren von Kameraausfällen waren beim Testen hilfreicher als erwartet – ohne sie hätte man Ausfallszenarien nur schwer kontrolliert nachstellen können, gerade bevor überhaupt echte Hardware im Feld war.
- **Härtung von Anfang an mitgeplant, nicht nachträglich draufgesetzt.** iptables, fail2ban und unattended-upgrades waren von der ersten Debian-Installation an Teil des Setups – das war spürbar einfacher, als sie später auf ein bereits laufendes System aufzusetzen.

## Mögliche Weiterentwicklungen

- Zusätzliche lokale Metriken (CPU, Memory, Kamera-Status über ONVIF/RTSP)
- Automatisierte Provisionierung (Ansible / cloud-init)
- Zentrale Aggregation mehrerer Standorte mit Rollen/Rechte
- High-Availability für die zentrale Uptime-Kuma-Instanz
- Integration in bestehende Ticket-/Alert-Systeme

---

**Hinweis:** Dieses Repository enthält die Dokumentation und Beispiel-Skripte aus einer betrieblichen Projektarbeit (Abschlussprüfung Fachinformatiker Systemintegration).  
