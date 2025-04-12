#!/bin/bash

echo "=== Watching iptables, Pods, and Services ==="
echo "🔧 Running on: happy-path-control-plane"
echo "📌 Press Ctrl+C to stop watching"

while true; do
    echo -e "\n--- Update at $(date) ---"

    # Watch iptables NAT rules (KUBE-SERVICES chain)
    echo "📋 iptables NAT Rules (KUBE-SERVICES chain):"
    docker exec happy-path-control-plane iptables -t nat -L KUBE-SERVICES -n -v | grep -E "nginx-service|client-service|Chain KUBE-SERVICES" || echo "  (No rules yet for nginx-service or client-service)"

    # Watch pods
    echo -e "\n📋 Pods:"
    kubectl get pods -o wide --no-headers | grep -E "nginx|client" || echo "  (No nginx or client pods yet)"

    # Watch services
    echo -e "\n📋 Services:"
    kubectl get services -o wide --no-headers | grep -E "nginx-service|client-service" || echo "  (No nginx-service or client-service yet)"

    sleep 2
done