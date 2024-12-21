<!-- create a readme for a talk with an lab type setup for kubernetes networking where I want to setup a completely new cluster with no networking and show one step at a time how an IP is assigned to a pod and then how that is used to discover and communicate to the pod -->

# Kubernetes Networking Deep Dive: From Zero to Pod Communication

This lab demonstrates how Kubernetes networking works from the ground up by creating a cluster without networking and observing how pods get IP addresses and communicate.

## Prerequisites

- kubectl
- kind or minikube
- Docker

## Lab Steps

### 1. Create a Bare Kubernetes Cluster

First, we'll create a Kubernetes cluster without any CNI plugin:

I'll help expand the README with detailed technical steps and lab setup instructions. Here's how we can enhance it:

```markdown:Readme.md
# Kubernetes Networking Deep Dive: From Zero to Pod Communication

This lab demonstrates how Kubernetes networking works from the ground up by creating a cluster without networking and observing how pods get IP addresses and communicate.

## Prerequisites

- kubectl
- kind or minikube
- Docker
- tcpdump/wireshark (for network analysis)
- Linux environment (recommended)

## Lab Setup Options

### Option 1: Using Kind (Recommended)

```bash
# Create a custom kind config
cat << EOF > kind-no-cni.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true # Disable default CNI installation
  podSubnet: "10.244.0.0/16"
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Create the cluster
kind create cluster --config kind-no-cni.yaml --name net-deep-dive
```

### Option 2: Using Kubeadm (For deeper understanding)

```bash
# Initialize control plane without networking
kubeadm init --pod-network-cidr=10.244.0.0/16 --skip-phases=addon/kube-proxy

# Join worker nodes without kube-proxy
kubeadm join --skip-phases=addon/kube-proxy ...
```

## Lab Steps

### 1. Verify Cluster State

```bash
# Check nodes
kubectl get nodes
# Nodes should be NotReady due to missing CNI

# Check kube-system pods
kubectl get pods -n kube-system
# CoreDNS pods will be pending
```

### 2. Understanding Pod Network Requirements

Examine the basic requirements for pod networking:
- Every pod needs a unique IP
- Pods on a node can communicate with all pods on all nodes
- No NAT required for pod-to-pod communication

### 3. Manual Pod IP Assignment (Learning Exercise)

```bash
# Create a test pod
kubectl run nginx --image=nginx --restart=Never

# Pod will be in ContainerCreating state
kubectl get pod nginx
```

### 4. Network Analysis Steps

1. **Examine CNI Configuration**
```bash
# View CNI config directory
ls /etc/cni/net.d/

# Check CNI binaries
ls /opt/cni/bin/
```

2. **Network Namespace Investigation**
```bash
# Find pod's network namespace
docker inspect <container-id> | grep -i pid
nsenter -t <pid> -n ip addr
```

### 5. Installing CNI Step by Step

#### 5.1 Install Calico CNI (Example)
```bash
# Install Calico operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml

# Install Calico custom resources
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
```

#### 5.2 Observe Network Creation
```bash
# Watch pod IP assignment
kubectl get pods -A -o wide --watch

# Examine pod interfaces
kubectl exec -it nginx -- ip addr
```

### 6. Testing Pod Communication

```bash
# Create test pods
kubectl run pod1 --image=nginx
kubectl run pod2 --image=nginx

# Test connectivity
kubectl exec pod1 -- ping <pod2-ip>
```

## Advanced Topics

### Network Packet Analysis

```bash
# Capture pod traffic
tcpdump -i cali+ -n

# Analyze pod-to-pod communication
kubectl exec -it pod1 -- traceroute <pod2-ip>
```

### Debugging Tools

- `kubectl debug` - For running debugging containers
- `nsenter` - For entering network namespaces
- `ip netns` - For managing network namespaces
- `bridge-utils` - For examining Linux bridges
- `iptables-save` - For viewing iptables rules

## Additional Resources

- [Kubernetes Networking Model](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [CNI Specification](https://github.com/containernetworking/cni/blob/master/SPEC.md)
- [Calico Documentation](https://docs.projectcalico.org/)

## Troubleshooting Guide

Common issues and their solutions:
1. Pods stuck in ContainerCreating
2. Network connectivity issues
3. DNS resolution problems
4. Cross-node communication failures

Each section can be expanded based on your specific needs. Would you like me to elaborate on any particular section?
