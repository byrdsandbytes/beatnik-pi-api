#!/bin/bash
# Check connection status
nmcli general status | grep -q "connected"
CONNECTED=$?

if [ $CONNECTED -ne 0 ]; then
    echo "No network connection, starting hotspot and portal..."
    sudo nmcli connection up Beatnik-Setup
    sudo systemctl start beatnik-api.service
    sudo systemctl start nodogsplash.service
else
    echo "Already connected, ensuring hotspot services are down."
    sudo nmcli connection down Beatnik-Setup || true
    sudo systemctl stop nodogsplash.service || true
    sudo systemctl stop beatnik-api.service || true
fi
