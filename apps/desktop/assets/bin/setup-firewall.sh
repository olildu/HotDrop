#!/bin/bash

# HotDrop Firewall Setup Script for Arch Linux (UFW/Firewalld)

PORT=42069

echo "Configuring firewall rules for HotDrop..."

# 1. Check for UFW
if command -v ufw >/dev/null 2>&1; then
    echo "UFW detected. Adding rule for port $PORT..."
    ufw allow $PORT/tcp comment 'HotDrop P2P'
fi

# 2. Check for Firewalld
if command -v firewall-cmd >/dev/null 2>&1; then
    echo "Firewalld detected. Adding rule for port $PORT..."
    firewall-cmd --permanent --add-port=$PORT/tcp
    firewall-cmd --reload
fi

# 3. Check for iptables (direct)
if command -v iptables >/dev/null 2>&1; then
    echo "Checking iptables..."
    # Only add if not already present
    iptables -C INPUT -p tcp --dport $PORT -j ACCEPT >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Adding iptables rule..."
        iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
    fi
fi

echo "Firewall setup complete."
