# Init mgt cluster
kind create cluster 
export CAPH_MGT_CLUSTER_KUBECONFIG=/tmp/mgt-kubeconfig && kind get kubeconfig > $CAPH_MGT_CLUSTER_KUBECONFIG
export KUBECONFIG=$CAPH_MGT_CLUSTER_KUBECONFIG
clusterctl init --bootstrap rke2 --control-plane rke2 --infrastructure hetzner

# Bootstrap settings 
kubectl create secret generic hetzner --from-literal="hcloud=$HCLOUD_TOKEN"
source ./env-vars/rke2.rc

#Create and build cluster
clusterctl generate cluster hetzner-capi-rke2-demo --from capi-conf-templates/rke2-online.yaml > hetzner-capi-rke2-demo.yaml
kubectl apply -f hetzner-capi-rke2-demo.yaml
kubectl get hetznercluster


# Try to access workload cluster 
clusterctl get kubeconfig hetzner-capi-rke2-demo > /tmp/workload-kubeconfig
export KUBECONFIG=/tmp/workload-kubeconfig
