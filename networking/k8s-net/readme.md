# # CNCF-MY network k8s

This project is designed to help users understand the fundamentals of IPTABLES, BGP (Border Gateway Protocol), and various networking aspects of Kubernetes (K8S). It provides hands-on examples and scripts to explore these topics in depth.

## Prerequisites

- Docker
- Kubernetes cluster (Minikube, Kind, or any cloud provider) _kind is recommended since all proof of concept scripts are tested on it._
- Any other dependencies required for the project.

## Installation

Clone the repository:

## Usage

*Give permission to the scripts that you want to run unsing*

```bash
chmod +x script-name.sh
```

To create a new Kubernetes cluster using Kind:

```bash
kind create cluster --name happy-path --config ./configs/kind-config.yaml

or

kind create cluster --name happy-path --config ./configs/kind-bgp.yaml
```

*Please note that `--name` is important as `docker exec` will use this name to run the commands inside the cluster.*

To clean up and delete the cluster:

```bash
kind delete cluster --name happy-path
```

### The idea behind kubernetes networking philosophy

#### Flat networking structure

```mermaid
flowchart TD
  subgraph Node1
    PodA[Pod A<br>10.244.1.2]
    PodB[Pod B<br>10.244.1.3]
  end

  subgraph Node2
    PodC[Pod C<br>10.244.2.2]
    PodD[Pod D<br>10.244.2.3]
  end

  PodA <-->|direct Pod-to-Pod| PodB
  PodA <-->|flat Pod-to-Pod| PodC
  PodA <-->|flat Pod-to-Pod| PodD
  PodC -->|direct Pod-to-Pod| PodD

  classDef pod fill:#f2f2f2,stroke:#333,stroke-width:1px;
  class PodA,PodB,PodC,PodD pod;
```
The above diagram illustrates the flat networking structure of Kubernetes, where all pods can communicate with each other directly using their IP addresses. This is made possible by the Container Network Interface (CNI) plugin, which sets up the necessary networking rules.


#### But how is pod-to-pod communication achieved?

```mermaid
flowchart TD
    subgraph NodeA["Node A"]
        App[Application in Pod-A]
        PodA[Pod-A<br>IP: 10.244.1.5]
        vethA[veth0]
        bridgeA[cni0 bridge]
        routeA[Routing Table]
        kubeProxyA["kube-proxy<br>(iptables mode)"]
    end

    subgraph ClusterNetwork["Overlay Network<br>(Flannel / Calico)"]
        tunnel["Tunnel (VXLAN, IP-in-IP)"]
    end

    subgraph NodeB["Node B"]
        PodB[Pod-B<br>IP: 10.244.2.8]
        vethB[veth0]
        bridgeB[cni0 bridge]
        routeB[Routing Table]
    end

    App --> PodA
    PodA --> vethA --> bridgeA --> kubeProxyA -->|DNAT: svc-B -> Pod-B IP| routeA --> tunnel
    tunnel --> routeB --> bridgeB --> vethB --> PodB

    PodB --> vethB --> bridgeB --> routeB --> tunnel
    tunnel --> routeA --> kubeProxyA --> bridgeA --> vethA --> PodA

```



#### What happens when we add a service?
```mermaid
graph TD
    subgraph Node1
        Pod1[Pod A<br>10.0.0.1]
        Pod2[Pod B<br>10.0.0.2]
        KProxy1[Kube-Proxy]
        IPT1[iptables rules]
    end

    subgraph Node2
        Pod3[Pod C<br>10.0.0.3]
        KProxy2[Kube-Proxy]
        IPT2[iptables rules]
    end

    Service["Service (ClusterIP)<br>10.96.0.100"]
    Client[Client]

    Client -->|curl 10.96.0.100| Service
    Service -->|handled via| IPT1
    KProxy1 -->|manages| IPT1
    IPT1 -->|load-balance to| Pod1
    IPT1 --> Pod2
    IPT1 --> Pod3

```


#### So in total we have:

```mermaid
flowchart TD
  subgraph Cluster["Kubernetes Cluster"]
    
    subgraph ControlPlane["Control Plane"]
      APIServer[Kube-API Server]
      Scheduler[Scheduler]
      ControllerManager[Controller Manager]
      Etcd[etcd]
    end

    subgraph Node["Worker Node"]
      Pod1[("Pod")]
      Service1["Service (ClusterIP)"]
      Kubelet[Kubelet]
      ContainerRuntime["CRI (e.g., containerd)"]
      CNI["CNI Plugin"]
      KubeProxy["kube-proxy (iptables mode)"]
    end

  end

  %% Control Plane interactions
  APIServer --> Etcd
  Scheduler --> APIServer
  ControllerManager --> APIServer

  %% Node interactions
  Kubelet --> APIServer
  Kubelet --> ContainerRuntime
  ContainerRuntime --> CNI
  CNI -->|Sets up| Pod1
  ContainerRuntime --> Pod1

  Kubelet --> Pod1

  KubeProxy -->|Watches| APIServer
  KubeProxy -->|Manages| iptables
  Service1 --> KubeProxy
  KubeProxy --> Pod1

  %% Service to Pod mapping
  Client["Client Request"] --> Service1
  Service1 -->|Routes to| Pod1

```

#### How did I break my cluster?

```mermaid
flowchart TD
    A[Start: Pod/Service Created] --> B[Kubelet invokes Container Runtime]
    B --> C[Container Runtime calls CNI plugin]
    C --> D[CNI sets up netns & assigns Pod IP]
    D --> E[kube-proxy programs iptables rules]

    subgraph Normal_Operation["Normal Operation"]
        E --> F[iptables rules are minimal]
        F --> G[Fast, low-latency packet routing]
    end

    subgraph High_Scale["At High Scale"]
        H[Hundreds of Pods & Services] --> I[Large iptables rule set]
        I --> J[kube-proxy runs iptables-restore]
        J --> K[Restore takes longer, CPU usage spikes]
        K --> L[Packet drops, kube-proxy lags behind]
    end
```

#### How does BGP does networking?
```mermaid
graph TD
    subgraph Node1
        Pod1[Pod A<br>10.0.0.1]
        Pod2[Pod B<br>10.0.0.2]
        Cilium1["Cilium Agent<br>(eBPF dataplane)"]
    end

    subgraph Node2
        Pod3[Pod C<br>10.0.0.3]
        Cilium2["Cilium Agent<br>(eBPF dataplane)"]
    end

    subgraph Control Plane
        KubeAPI[Kube-API Server]
    end

    subgraph BGP
        BGP1["BGP Speaker"]
        Router[External Router]
    end

    Service1[Service<br>10.96.0.1]
    Service2[Service<br>10.96.0.2]

    Cilium1 --> Pod1
    Cilium1 --> Pod2
    Cilium2 --> Pod3

    Service1 -->|eBPF Load Balancing| Pod1
    Service2 --> Pod3

    BGP1 -->|Announces Pod CIDRs| Router
    BGP1 --> Cilium1
    BGP1 --> Cilium2
    KubeAPI --> Cilium1
    KubeAPI --> Cilium2
```

```mermaid
graph TD
    subgraph External
        Client[External Client]
        Router[External Router]
    end

    subgraph BGP
        BGP1["BGP Speaker (e.g., MetalLB/Cilium)"]
    end

    subgraph ControlPlane["Control Plane"]
        KubeAPI[Kube-API Server]
    end

    subgraph Node1
        Pod1[Pod A<br>10.0.0.1]
        Pod2[Pod B<br>10.0.0.2]
        Cilium1["Cilium Agent<br>(eBPF dataplane)"]
    end

    subgraph Node2
        Pod3[Pod C<br>10.0.0.3]
        Cilium2["Cilium Agent<br>(eBPF dataplane)"]
    end

    Service1["Service<br>10.96.0.1<br>LoadBalancer IP: 192.0.2.10"]

    %% External traffic flow
    Client -->|"Accesses LoadBalancer IP<br>(192.0.2.10)"| Router
    Router -->|Routes via BGP-announced path| BGP1
    BGP1 -->|Announces Pod/Service IPs| Cilium1
    BGP1 --> Cilium2

    %% Internal routing
    Cilium1 --> Pod1
    Cilium1 --> Pod2
    Cilium2 --> Pod3

    %% Load balancing by Cilium
    Service1 -->|eBPF Load Balancing| Pod1
    Service1 --> Pod3

    %% API server communication
    KubeAPI -->|Watches Services, Endpoints| Cilium1
    KubeAPI --> Cilium2

```

## Contributing

Contributions are welcome! Please clone and submit a pull request.
