# Init mgt cluster
kind create cluster --image kindest/node:v1.29.2
export CAPH_MGT_CLUSTER_KUBECONFIG=/tmp/mgt-kubeconfig && kind get kubeconfig > $CAPH_MGT_CLUSTER_KUBECONFIG
export KUBECONFIG=$CAPH_MGT_CLUSTER_KUBECONFIG
clusterctl init --bootstrap rke2 --control-plane rke2 --infrastructure hetzner

# Bootstrap settings 
kubectl create secret generic hcloud --from-literal="token=$HCLOUD_TOKEN"
source ./env-vars/rke2.rc

#Create and build cluster
clusterctl generate cluster hetzner-capi-rke2-demo --from capi-conf-templates/rke2-online.yaml > hetzner-capi-rke2-demo.yaml
k apply -f hetzner-capi-rke2-demo.yaml
k get hetznercluster


sleep 1000
# Try to access workload cluster 
clusterctl get kubeconfig hetzner-capi-rke2-demo > /tmp/workload-kubeconfig
export KUBECONFIG=/tmp/workload-kubeconfig