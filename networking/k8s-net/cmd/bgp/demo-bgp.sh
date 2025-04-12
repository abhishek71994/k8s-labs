#!/bin/bash
echo "=== BGP Demo: Handling 75 Services ==="


echo "Checking if cilium is ready..."
if kubectl get pods -n kube-system -l k8s-app=cilium | grep -q "0/1"; then
  echo "Cilium is not ready yet. Please wait..."
  exit 1
fi

echo "Cilium is ready. Proceeding with the demo..."

echo "Deploying 75 services..."
for i in $(seq 1 75); do
  cat <<EOF | kubectl apply -f - &
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
  - port: 80
    targetPort: 80
EOF
done
wait

echo "Waiting for pods (up to 1min)..."
kubectl wait --for=condition=ready pod --all --timeout=60s || echo "Some pods may not be ready"

echo "Waiting for BGP routes (30s)..."
sleep 30

echo "📋 Service count..."
kubectl get svc | grep nginx-service | wc -l | awk '{print "  " $1 " services running"}'

echo "📋 Run ./cmd/bgp/bgp-network-test next..."
