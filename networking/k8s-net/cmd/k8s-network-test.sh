#!/bin/bash

# Colors using \033
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"
TIMEOUT=60

echo "=== Kubernetes Network Connectivity Test ==="
echo "🔧 Cluster: $(kubectl config current-context)"

# check if pods are running
if ! kubectl get pods -n default | grep -q "Running"; then
    echo -e "${RED}No running pods found${NC}"
    exit 1
fi

# Gather IP information
NGINX_IP=$(kubectl get pod nginx -o jsonpath='{.status.podIP}')
CLIENT_IP=$(kubectl get pod client -o jsonpath='{.status.podIP}')
NGINX_SVC_IP=$(kubectl get svc nginx-service -o jsonpath='{.spec.clusterIP}')
CLIENT_SVC_IP=$(kubectl get svc client-service -o jsonpath='{.spec.clusterIP}')

# Display IP details
echo -e "\n📋 Resource IPs:"
echo "  - Pod nginx: $NGINX_IP"
echo "  - Pod client: $CLIENT_IP"
echo "  - Service nginx-service: $NGINX_SVC_IP"
echo "  - Service client-service: $CLIENT_SVC_IP"

# Test 1: Pod-to-Pod
echo -e "\n🔍 Pod-to-Pod Test:"
echo "  - Source: client ($CLIENT_IP)"
echo "  - Target: nginx ($NGINX_IP:80)"
echo -n "  - Result: "
if kubectl exec client -- curl -s -o /dev/null http://$NGINX_IP:80; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test 2: Pod-to-Service
echo -e "\n🔍 Pod-to-Service Test:"
echo "  - Source: client ($CLIENT_IP)"
echo "  - Target: nginx-service ($NGINX_SVC_IP:80)"
echo -n "  - Result: "
if kubectl exec client -- curl -s -o /dev/null http://nginx-service:80; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi

# Test 3: Service-to-Service
echo -e "\n🔍 Service-to-Service Test:"
echo "  - Source: client ($CLIENT_IP) via client-service ($CLIENT_SVC_IP)"
echo "  - Target: nginx-service ($NGINX_SVC_IP:80)"
echo -n "  - Result: "
if kubectl exec client -- curl -s -o /dev/null http://nginx-service:80; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
fi
