#!/bin/bash

# HotDrop Firewall Setup Script for Linux (UFW/Firewalld/iptables)

# Usage: ./setup-firewall.sh [--check] [port1] [port2] ...

CHECK_MODE=0
if [ "$1" == "--check" ]; then
    CHECK_MODE=1
    shift
fi

# Use provided ports or fallback to default
PORTS=("$@")
if [ ${#PORTS[@]} -eq 0 ]; then
    PORTS=(42069)
fi

if [ "$CHECK_MODE" -eq 1 ]; then
    ALL_OPEN=0
    for PORT in "${PORTS[@]}"; do
        # 1. Check for Firewalld
        if command -v firewall-cmd >/dev/null 2>&1; then
            ZONES=$(firewall-cmd --get-active-zones | grep -v '^[[:space:]]' | awk '{print $1}')
            # Also check nm-shared if it exists
            if firewall-cmd --get-zones | grep -q "nm-shared"; then
                ZONES="$ZONES nm-shared"
            fi
            if [ -z "$ZONES" ]; then ZONES="public"; fi
            
            for ZONE in $ZONES; do
                if ! firewall-cmd --zone="$ZONE" --query-port="$PORT/tcp" >/dev/null 2>&1; then
                    ALL_OPEN=1
                    break
                fi
            done
        # 2. Check for UFW
        elif command -v ufw >/dev/null 2>&1; then
            if ! ufw status | grep -q "$PORT/tcp"; then
                ALL_OPEN=1
            fi
        # 3. Check for iptables
        elif command -v iptables >/dev/null 2>&1; then
            if ! iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT >/dev/null 2>&1; then
                ALL_OPEN=1
            fi
        else
            ALL_OPEN=1
        fi
        
        if [ "$ALL_OPEN" -eq 1 ]; then
            exit 1
        fi
    done
    exit 0
fi

# Configuration Mode (requires root usually)
for PORT in "${PORTS[@]}"; do
    echo "Configuring firewall rules for HotDrop on port $PORT..."

    # 1. UFW
    if command -v ufw >/dev/null 2>&1; then
        echo "UFW: Ensuring port $PORT/tcp is allowed..."
        ufw allow $PORT/tcp comment 'HotDrop P2P'
    fi

    # 2. Firewalld
    if command -v firewall-cmd >/dev/null 2>&1; then
        # Identify all active zones
        ZONES=$(firewall-cmd --get-active-zones | grep -v '^[[:space:]]' | awk '{print $1}')
        
        # Always include public and nm-shared to be safe
        ZONES="$ZONES public nm-shared"

        # Remove duplicates and empty lines
        ZONES=$(echo "$ZONES" | tr ' ' '\n' | grep . | sort -u | tr '\n' ' ')

        echo "Firewalld: Adding rule for port $PORT in zones: $ZONES"
        for ZONE in $ZONES; do
            # Add with --permanent and also try runtime rule immediately
            firewall-cmd --permanent --zone="$ZONE" --add-port="$PORT/tcp" >/dev/null 2>&1
            firewall-cmd --zone="$ZONE" --add-port="$PORT/tcp" >/dev/null 2>&1
        done
        firewall-cmd --reload >/dev/null 2>&1
    fi

    # 3. iptables (Direct fallback)
    if command -v iptables >/dev/null 2>&1; then
        if ! iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT >/dev/null 2>&1; then
            echo "iptables: Adding direct rule for port $PORT..."
            iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
        fi
    fi
done

echo "Firewall setup complete."
