#!/bin/bash
# Erstellt drei Dummy-Netzwerk-Interfaces zur Simulation von IP-Kameras (Testumgebung)

sudo modprobe dummy
sudo ip link add dummy1 type dummy
sudo ip link add dummy2 type dummy
sudo ip link add dummy3 type dummy
sudo ip addr add 192.168.1.201/24 dev dummy1
sudo ip addr add 192.168.1.202/24 dev dummy2
sudo ip addr add 192.168.1.203/24 dev dummy3
sudo ip link set dummy1 up
sudo ip link set dummy2 up
sudo ip link set dummy3 up
