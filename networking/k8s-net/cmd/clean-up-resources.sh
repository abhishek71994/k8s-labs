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

# Clean up resources
echo "🧹 Cleaning up resources..."

kubectl delete -f network-test.yaml || { echo -e "${RED}Failed to delete YAML${NC}"; exit 1; }

echo "✅ Resources cleaned up successfully."