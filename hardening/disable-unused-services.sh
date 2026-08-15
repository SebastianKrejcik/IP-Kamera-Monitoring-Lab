#!/bin/bash
# Deaktiviert nicht benötigte Standarddienste zur Reduzierung der Angriffsfläche

SERVICES=(
  "bluetooth"
  "cups"
  "avahi-daemon"
  "rpcbind"
  "nfs-kernel-server"
  "nfs-common"
  "smbd"
  "nmbd"
  "winbind"
  "vsftpd"
  "bind9"
  "apache2"
  "mysql"
  "postfix"
)

for SERVICE in "${SERVICES[@]}"; do
  systemctl disable "$SERVICE"
  systemctl stop "$SERVICE"
done
