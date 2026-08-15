#!/bin/bash
sudo apt-get update
sudo apt-get install -y fail2ban

sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/# bantime = 10m/bantime = 10m/' /etc/fail2ban/jail.local
sudo sed -i 's/# findtime = 10m/findtime = 10m/' /etc/fail2ban/jail.local
sudo sed -i 's/# maxretry = 5/maxretry = 5/' /etc/fail2ban/jail.local

sudo systemctl restart fail2ban
