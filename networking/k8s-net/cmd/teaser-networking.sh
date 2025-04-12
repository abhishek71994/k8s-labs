#!/bin/bash

GREEN="\033[32m"
NC="\033[0m"

echo "=== Kubernetes Networking Basics Demo Teaser ==="
echo "🔧 Setting up a kind cluster with default networking..."

# Create cluster with default CNI (Kindnet)
kind create cluster --name happy-path-with-cni --config kind-config-with-cni.yaml

# Wait for cluster to be ready
echo "⏳ Waiting for control-plane to be ready..."
kubectl wait --for=condition=ready node happy-path-with-cni-control-plane --timeout=60s

# Deploy resources
echo "🚀 Deploying network-test.yaml..."
kubectl apply -f network-test.yaml
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=60s

# Show pods with IPs
echo -e "\n📋 Pods with IPs (Flat Network Model):"
kubectl get pods -o wide

# Show services with ClusterIPs
echo -e "\n📋 Services with ClusterIPs:"
kubectl get services -o wide

# Quick connectivity test
echo -e "\n🔍 Quick Connectivity Test (Pod-to-Service):"
NGINX_SVC_IP=$(kubectl get svc nginx-service -o jsonpath='{.spec.clusterIP}')
kubectl exec client -- curl -s -o /dev/null http://$NGINX_SVC_IP:80 && echo -e "${GREEN}PASS${NC}" || echo "FAIL"

echo -e "\n📌 Teaser Complete! Basic networking works out of the box with Kindnet."