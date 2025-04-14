#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"

echo "=== Stressing iptables with Heavy Workload ==="
echo "🔧 Cluster: $(kubectl config current-context)"

# Function to check iptables rules count
check_iptables_count() {
    echo "📋 Number of iptables NAT Rules (KUBE-SERVICES):"
    docker exec happy-path-control-plane iptables -t nat -L KUBE-SERVICES -n | wc -l
}

# # Create cluster if not already running
if ! kind get clusters | grep -q "happy-path"; then
    kind create cluster --name happy-path --config kind-config-with-cni.yaml
    kubectl wait --for=condition=ready node happy-path-control-plane --timeout=60s
fi

# Initial state
echo -e "\n📌 Initial iptables Rule Count:"
check_iptables_count

# Deploy many Pods and Services
echo -e "\n🚀 Deploying 50 nginx Pods and Services..."
for i in $(seq 1 60); do
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-$i
  labels:
    app: nginx-$i
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service-$i
spec:
  selector:
    app: nginx-$i
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
EOF
done

echo "⏳ Waiting for Pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout=120s || echo "Some pods may not be ready"

# Show updated state
echo -e "\n📋 Pods with IPs:"
kubectl get pods -o wide | grep nginx
echo -e "\n📋 Services with ClusterIPs:"
kubectl get services -o wide | grep nginx-service
echo -e "\n📌 Updated iptables Rule Count:"
check_iptables_count

# Simulate churn
echo -e "\n🔧 Simulating Churn (Deleting Pods Every 5s for 1 Minute)..."
for i in $(seq 1 12); do
    kubectl delete pod -l app=nginx-$((RANDOM % 50 + 1)) --force --grace-period=0 &
    sleep 5
done

# Watch impact
echo -e "\n📋 Kube-Proxy Logs (Look for Delays or Errors):"
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=20 | grep -i "iptables" || echo "  (No recent iptables updates logged)"

echo -e "\n📋 Test Connectivity (May Fail Under Load):"
NGINX_SVC_IP=$(kubectl get svc nginx-service-1 -o jsonpath='{.spec.clusterIP}')
kubectl run -i --rm --restart=Never test-pod --image=radial/busyboxplus:curl -- curl -s -o /dev/null http://$NGINX_SVC_IP:80 && echo -e "${GREEN}PASS${NC}" || echo -e "${RED}FAIL${NC}"

echo -e "\n📌 Demo Complete! Check watcher for real-time effects."