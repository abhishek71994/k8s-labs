#!/bin/bash

# Colors using \033
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"
TIMEOUT=60

echo "=== Kubernetes Network Connectivity Test ==="
echo "🔧 Cluster: $(kubectl config current-context)"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}kubectl is not installed or not in PATH${NC}"
  exit 1
fi

# Check if Kubernetes cluster is reachable
if ! kubectl cluster-info &> /dev/null; then
  echo -e "${RED}Kubernetes cluster is not reachable${NC}"
  exit 1
fi

# Deploy resources
echo "🚀 Applying network-test.yaml..."
kubectl apply -f network-test.yaml || { echo -e "${RED}Failed to apply YAML${NC}"; exit 1; }
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all --timeout="${TIMEOUT}s" || { echo -e "${RED}Pods not ready${NC}"; exit 1; }

echo "Pods are ready."