#!/bin/bash
PORT=42069
echo "Checking port $PORT..."

if command -v firewall-cmd >/dev/null 2>&1; then
    echo "Testing firewall-cmd..."
    firewall-cmd --query-port="$PORT/tcp" && echo "firewall-cmd says OPEN" || echo "firewall-cmd says CLOSED"
fi

if command -v ufw >/dev/null 2>&1; then
    echo "Testing ufw..."
    ufw status | grep -q "$PORT/tcp" && echo "ufw says OPEN" || echo "ufw says CLOSED"
fi

if command -v iptables >/dev/null 2>&1; then
    echo "Testing iptables..."
    iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT && echo "iptables says OPEN" || echo "iptables says CLOSED"
fi
