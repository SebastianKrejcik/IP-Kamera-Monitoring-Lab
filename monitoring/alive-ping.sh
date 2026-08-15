#!/bin/bash
# Sendet regelmäßig ein Lebenszeichen (Heartbeat) an das zentrale Monitoring-Dashboard
# Platzhalter unten durch eigene Uptime-Kuma-Push-URL ersetzen

notification_url="<UPTIME_KUMA_PUSH_URL>"

echo "Starte Heartbeat-Benachrichtigung..."

while true; do
  response=$(curl -s -o /dev/null -w "%{http_code}" "$notification_url")

  if [ "$response" == "200" ]; then
    echo "Benachrichtigung erfolgreich gesendet."
  else
    echo "Fehler beim Senden der Benachrichtigung. HTTP-Antwortcode: $response"
  fi

  sleep 60
done
