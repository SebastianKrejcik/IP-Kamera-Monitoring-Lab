#!/bin/bash
# Simuliert zufällige Kameraausfälle für Testzwecke

ip_addresses=("192.168.1.201/24" "192.168.1.202/24" "192.168.1.203/24")

while true; do
  action=$((RANDOM % 2))
  random_ip=${ip_addresses[$RANDOM % ${#ip_addresses[@]}]}

  if [ "$action" -eq 0 ]; then
    echo "Aktiviere IP-Adresse: $random_ip"
    sudo ip addr add "$random_ip" dev dummy$((RANDOM % 3 + 1))
  else
    echo "Deaktiviere IP-Adresse: $random_ip"
    sudo ip addr flush dev dummy$((RANDOM % 3 + 1))
  fi

  sleep 5
done
