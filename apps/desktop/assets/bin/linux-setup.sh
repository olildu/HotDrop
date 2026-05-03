#!/bin/bash

# Master setup script for HotDrop Linux
# Usage: ./linux-setup.sh <ssid> <password> <port1> <port2> ...

SSID=$1
PASSWORD=$2
shift 2
PORTS=("$@")

echo "Step 1: Starting Hotspot..."
nmcli device wifi hotspot ssid "$SSID" password "$PASSWORD"

echo "Step 2: Configuring Firewall..."
for PORT in "${PORTS[@]}"; do
    echo "Configuring firewall rules for HotDrop on port $PORT..."

    # 1. UFW
    if command -v ufw >/dev/null 2>&1; then
        echo "UFW: Ensuring port $PORT/tcp is allowed..."
        ufw allow $PORT/tcp comment 'HotDrop P2P'
    fi

    # 2. Firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        ZONES=$(firewall-cmd --get-active-zones | grep -v '^[[:space:]]' | awk '{print $1}')
        ZONES="$ZONES public nm-shared"
        ZONES=$(echo "$ZONES" | tr ' ' '\n' | grep . | sort -u | tr '\n' ' ')

        for ZONE in $ZONES; do
            firewall-cmd --permanent --zone="$ZONE" --add-port="$PORT/tcp" >/dev/null 2>&1
            firewall-cmd --zone="$ZONE" --add-port="$PORT/tcp" >/dev/null 2>&1
        done
        firewall-cmd --reload >/dev/null 2>&1
    fi

    # 3. iptables (Direct fallback)
    if command -v iptables >/dev/null 2>&1; then
        if ! iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT >/dev/null 2>&1; then
            iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
        fi
    fi
done

echo "Setup Complete"
