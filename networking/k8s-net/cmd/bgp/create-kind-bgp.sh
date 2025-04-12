#!/bin/bash

echo "=== BGP Demo: create bgp cluster ==="
kind create cluster --name bgp-demo --config kind-bgp.yaml

# apply the config map
kubectl apply -f ./cmd/bgp/bgp-configmap.yaml

echo "Installing Cilium (BGP, no kube-proxy)..."
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version 1.16.0 \
  --namespace kube-system \
  --set debug.enabled=true \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=bgp-demo-control-plane \
  --set k8sServicePort=6443 \
  --set bgp.enabled=true \
  --set bgp.announce.loadbalancerIP=true \
  --set bgp.announce.podCIDR=true \
  --set bgpControlPlane.enabled=true \
  --set cni.exclusive=true



echo "Wait for cilium..."
echo "Running: kubectl get pods -n kube-system -w"
echo "📋📋📋 Only run demo-bgp.sh after cilium is ready"