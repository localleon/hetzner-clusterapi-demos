# hetzner-clusterapi-rke2
Sample-Setup for using the RKE2-ClusterAPI Provider on Hetzner Cloud 


## Inital ClusterAPI Setup 

Install the `clusterctl` cli. See [Install ClusterCTL](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl)

```bash 
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.4.4/clusterctl-linux-amd64 -o clusterctl
sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
clusterctl version
```

We will use a Kind-Cluster as Managment Cluster 
```bash 
# Create Kind-Cluster for local managment
sudo kind create cluster --image kindest/node:v1.27.3

export CAPH_MGT_CLUSTER_KUBECONFIG=/tmp/mgt-kubeconfig
kind get kubeconfig > $CAPH_MGT_CLUSTER_KUBECONFIG
export KUBECONFIG=$CAPH_MGT_CLUSTER_KUBECONFIG
```


Setup Environment Variables 
```
export HCLOUD_CONTROL_PLANE_MACHINE_TYPE=cpx31
export HCLOUD_WORKER_MACHINE_TYPE=cpx31
export HCLOUD_SSH_KEY="lraus-cka_sshkey"
export HCLOUD_REGION="nbg1"
```

## Setup Cluster with clusterctl (kubeadm)

We need to prepare our environment variables for cluster template generation. We will be using the [Hetzner CAPI-Provder from Syself](https://github.com/syself/cluster-api-provider-hetzner) to provision the inital cluster with `kubeadm`.


```bash
# Setup syself/hetzner clusterAPI Provider 
clusterctl init --core cluster-api --bootstrap kubeadm --control-plane kubeadm --infrastructure hetzner
```

The following componentes will be installed on the managment cluster

```bash
Fetching providers
Installing cert-manager Version="v1.12.2"
Waiting for cert-manager to be available...
Installing Provider="cluster-api" Version="v1.4.4" TargetNamespace="capi-system"
Installing Provider="bootstrap-kubeadm" Version="v1.4.4" TargetNamespace="capi-kubeadm-bootstrap-system"
Installing Provider="control-plane-kubeadm" Version="v1.4.4" TargetNamespace="capi-kubeadm-control-plane-system"
Installing Provider="infrastructure-hetzner" Version="v1.0.0-beta.18" TargetNamespace="caph-system"
```


Then generate the cluster

```bash
clusterctl generate cluster hetzner-capi-demo --kubernetes-version v1.25.2 --control-plane-machine-count=1 --worker-machine-count=2 > my-cluster.yaml
k apply -f kubeadm-cluster.yaml
k get clusters

export CAPH_WORKER_CLUSTER_KUBECONFIG=/tmp/workload-kubeconfig
clusterctl get kubeconfig hetzner-capi-demo > $CAPH_WORKER_CLUSTER_KUBECONFIG
export KUBECONFIG=$CAPH_WORKER_CLUSTER_KUBECONFIG
```

## Setup the Cluster (with RKE2)

We will be using the experimental ClusterAPI Provider [cluster-api-provider-rke2](https://github.com/rancher-sandbox/cluster-api-provider-rke2) from Rancher. 

Create the following file with `vi ~/.cluster-api/clusterctl.yaml`

```yaml 
providers:
  - name: "rke2"
    url: "https://github.com/rancher-sandbox/cluster-api-provider-rke2/releases/v0.1.0-alpha.1/bootstrap-components.yaml"
    type: "BootstrapProvider"
  - name: "rke2"
    url: "https://github.com/rancher-sandbox/cluster-api-provider-rke2/releases/v0.1.0-alpha.1/control-plane-components.yaml"
    type: "ControlPlaneProvider"
  - name: "docker"
    url: "https://github.com/belgaied2/cluster-api/releases/v1.3.3-cabpr-fix/infrastructure-components.yaml"
    type: "InfrastructureProvider"
```

Now we switch our Bootstrap Provider to RKE2 and Control-Plane to RKE2. We still use the SysElf Provider for the infrastructure provisoning. Make sure this is run on the CAPI-Managment-Cluster.

```bash
# We need to remove the kubeadm provider befor installing rke2. 
clusterctl delete  --bootstrap kubeadm --control-plane kubeadm
# Setup syself/hetzner clusterAPI Provider 
clusterctl init --core cluster-api --bootstrap rke2 --control-plane rke2 --infrastructure hetzner
```

Setup Environment Variables 
```
export HCLOUD_CONTROL_PLANE_MACHINE_TYPE=cpx31
export HCLOUD_WORKER_MACHINE_TYPE=cpx31
export HCLOUD_SSH_KEY="lraus-cka_sshkey"
export HCLOUD_REGION="nbg1"

export CABPR_NAMESPACE="default"
export CLUSTER_NAME=hetzner-capi-rke2-demo
export CABPR_CP_REPLICAS=1
export CABPR_WK_REPLICAS=1
export KUBERNETES_VERSION=v1.24.6 
```


```bash 
# Generate the cluster
clusterctl generate cluster hetzner-capi-rke2-demo --from templates/rke2-online-default-sample-capi-template.yaml > hetzner-capi-rke2-demo.yaml
```

## Installing the CNI (or more)

Now we need to deploy the CNI 

```bash
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium --version 1.12.2 --namespace kube-system -f templates/cilium.yaml
```