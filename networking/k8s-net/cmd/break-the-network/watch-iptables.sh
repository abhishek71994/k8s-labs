#!/bin/bash

echo "=== Watching iptables, Pods, Services, and Kube-Proxy ==="
echo "🔧 Running on: happy-path-control-plane"
echo "📌 Press Ctrl+C to stop watching"

while true; do
    echo -e "\n--- Update at $(date) ---"

    # iptables NAT rules (KUBE-SERVICES chain)
    echo "📋 iptables NAT Rules (KUBE-SERVICES chain):"
    docker exec happy-path-control-plane iptables -t nat -L KUBE-SERVICES -n -v | grep -E "nginx-service|Chain KUBE-SERVICES" || echo "  (No rules yet for nginx-service)"

    # Pod count
    echo -e "\n📋 Pod Count:"
    kubectl get pods --no-headers | grep nginx | wc -l | awk '{print "  Running nginx pods: " $1}'

    # Service count
    echo -e "\n📋 Service Count:"
    kubectl get services --no-headers | grep nginx-service | wc -l | awk '{print "  Active nginx services: " $1}'

    # Kube-proxy logs
    echo -e "\n📋 Kube-Proxy Logs (Recent):"
    kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=5 | grep -i "iptables" || echo "  (No recent iptables updates logged)"

    sleep 2
done