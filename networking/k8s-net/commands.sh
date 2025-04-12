#!/bin/bash
echo "=== Setting up a Kind Cluster with CNI ==="
kind create cluster --name happy-path --config kind-config.yaml
kind create cluster --name happy-path-limited --config kind-config-limited.yaml

