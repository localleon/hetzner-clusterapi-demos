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
```bash
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

Export the configuration variables for the cluster 

```bash 
source ./env-vars/kubeadm.rc
```

Then generate the cluster with `clusterctl`

```bash
clusterctl generate cluster hetzner-capi-demo --control-plane-machine-count=1 --worker-machine-count=2 > hetzner-capi-kubeadm-demo.yaml
k apply -f kubeadm-cluster.yaml
k get clusters

export CAPH_WORKER_CLUSTER_KUBECONFIG=/tmp/workload-kubeconfig
clusterctl get kubeconfig hetzner-capi-demo > $CAPH_WORKER_CLUSTER_KUBECONFIG
export KUBECONFIG=$CAPH_WORKER_CLUSTER_KUBECONFIG
```

Now we need to deploy the CNI 

```bash
helm repo add cilium https://helm.cilium.io/
helm upgrade --install cilium cilium/cilium --version 1.12.2 --namespace kube-system -f templates/cilium.yaml
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
```bash
source ./env-vars/rke2.rc
```

```bash 
# Generate the cluster
clusterctl generate cluster hetzner-capi-rke2-demo --from capi-conf-templates/rke2-online.yaml > hetzner-capi-rke2-demo.yaml
k apply -f hetzner-capi-rke2-demo.yaml
```

The cluster will now be provisoned. After this, you can access the Kubeconfig of our new Workload Cluster via `clusterctl`

```bash
clusterctl get kubeconfig hetzner-capi-rke2-demo > /tmp/workload-kubeconfig
export KUBECONFIG=/tmp/workload-kubeconfig
```

For the nodes to get into a "Ready"-State, we will need to install the "Hetzner-Cloud-Controller". See [HetznerCloud Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager) for more information. 

```
kubectl -n kube-system create secret generic hcloud --from-literal="token=$HCLOUD_TOKEN"
helm repo add hcloud https://charts.hetzner.cloud
helm repo update hcloud
helm install hccm hcloud/hcloud-cloud-controller-manager -n kube-system
```



## Setup MicroK8s on Hetzner with CAPI 

First you will need to build an Ubuntu Image with `snapd` installed. Our image will be called `microk8s-ubuntu-22.04-2023-07-21-1830``and can then be referenced in the clusterapi-template.

```
packer build templates/node-image/microk8s-image/image.json
```

Export the environment variables and generate you're Cluster Template from the configuration

```bash
source env-vars/microk8s.rc
clusterctl generate cluster hetzner-microk8s-demo --from ./capi-conf-templates/microk8s.yaml > hetzner-microk8s-demo.yaml
```

Export Kubernetes Config 

```
export CAPH_WORKER2_CLUSTER_KUBECONFIG=/tmp/workload1-kubeconfig
clusterctl get kubeconfig hetzner-mikrok8s-demo > $CAPH_WORKER2_CLUSTER_KUBECONFIG
export KUBECONFIG=$CAPH_WORKER2_CLUSTER_KUBECONFIG
```


## Installing Rancher 

```bash 
# Install Ingress Controller 
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace


helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
kubectl create namespace cattle-system
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
helm install rancher rancher-latest/rancher --namespace cattle-system --set hostname=rancher.my.org --set bootstrapPassword=Leon123! --version 2.7.5
```