kubectl -n kube-system create secret generic hcloud --from-literal="token=$HCLOUD_TOKEN"
helm repo add hcloud https://charts.hetzner.cloud
helm repo update hcloud
helm install hccm hcloud/hcloud-cloud-controller-manager -n kube-system
