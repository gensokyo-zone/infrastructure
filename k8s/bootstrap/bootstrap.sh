#!/usr/bin/env -S nix shell nixpkgs#kubernetes-helm nixpkgs#rage --command bash
echo "Installing flannel (CNI/Network Fabric)"
kubectl create ns kube-flannel
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged
helm repo add flannel https://flannel-io.github.io/flannel/
helm install flannel --set podCidr="10.42.0.0/16" --namespace kube-flannel flannel/flannel
echo "Installing CoreDNS (Cluster DNS)"
helm repo add coredns https://coredns.github.io/helm
helm --namespace=kube-system install coredns coredns/coredns --set service.clusterIP=10.43.0.2
echo "Installing ArgoCD (GitOps)"
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --namespace argocd --create-namespace
echo "Generating an age keyfile for sops-secrets-operator, the next line will be the public key, please add it to .sops.yaml"
rage-keygen -o keys.txt 2>&1 | awk '{ print $3 }'
kubectl create ns sops
kubectl create secret generic sops-age-key-file --from-file=keys.txt -o yaml --dry-run=client -n sops > sops-age-key-file.yaml
kubectl apply -f sops-age-key-file.yaml -n sops
echo "Installing sops-secrets-operator"
helm repo add sops-secrets-operator https://inloco.github.io/sops-secrets-operator
helm install sops-secrets-operator sops-secrets-operator/sops-secrets-operator --namespace sops --values sops-values.yaml