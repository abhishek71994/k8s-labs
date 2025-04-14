#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"
TIMEOUT=120

echo "=== Kubernetes Network Connectivity Test ==="
echo "🔧 Cluster: $(kubectl config current-context)"

# Initial state (no CNI)
echo -e "\n📌 Initial State (No CNI):"
echo "🚀 Applying network-test.yaml (expect failure without CNI)..."
kubectl apply -f network-test.yaml
echo "⏳ Waiting 5s to show no-CNI state..."
sleep 5
kubectl get pods -o wide
kubectl describe pod nginx | grep -i "FailedCreatePodSandBox" -A 5 || echo "  (No CNI error yet)"
echo "📋 CoreDNS State (also affected):"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide

# Add Kindnet on the fly
echo -e "\n📌 Adding Kindnet (CNI) Dynamically:"
kubectl apply -f https://raw.githubusercontent.com/aojea/kindnet/main/install-kindnet.yaml
echo "⏳ Waiting for Kindnet pods to appear..."
for i in {1..12}; do
    if kubectl get pods -n kube-system -l app=kindnet | grep -q Running; then
        echo "Kindnet pods detected!"
        break
    fi
    echo "Waiting... ($i/12)"
    sleep 10
done
kubectl wait --for=condition=ready pod -n kube-system -l app=kindnet --timeout="${TIMEOUT}s" || { echo -e "${RED}Kindnet pods not ready${NC}"; exit 1; }
echo "📋 Kindnet Logs (CNI setup):"
kubectl logs -n kube-system -l app=kindnet --tail=20 | grep -i "node" || echo "  (No node setup logs yet)"

# Watch IPs update
echo -e "\n📌 Watching Pod IPs Update:"
echo "⏳ Waiting for pods to get IPs..."
kubectl wait --for=condition=ready pod --all --timeout="${TIMEOUT}s" || { echo -e "${RED}Pods not ready${NC}"; exit 1; }
kubectl get pods -o wide

# Gather IP information
NGINX_IP=$(kubectl get pod nginx -o jsonpath='{.status.podIP}')
CLIENT_IP=$(kubectl get pod client -o jsonpath='{.status.podIP}')
NGINX_SVC_IP=$(kubectl get svc nginx-service -o jsonpath='{.spec.clusterIP}')
CLIENT_SVC_IP=$(kubectl get svc client-service -o jsonpath='{.spec.clusterIP}')

# Display IP details
echo -e "\n📋 Resource IPs (Assigned by Kindnet):"
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

# # Cleanup
# echo -e "\n🧹 Cleaning up..."
# kubectl delete -f network-test.yaml --ignore-not-found