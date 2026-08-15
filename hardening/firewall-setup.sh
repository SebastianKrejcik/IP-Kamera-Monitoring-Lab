#!/bin/bash
# Konfiguriert iptables als restriktive Firewall (Default Deny, nur benötigte Ports)

REQUIRED_PORTS=(22 80 443 8080)

iptables -F
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT

for PORT in "${REQUIRED_PORTS[@]}"; do
  iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
  iptables -A INPUT -p udp --dport "$PORT" -j ACCEPT
done

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -j LOG --log-prefix "iptables denied: " --log-level 7
