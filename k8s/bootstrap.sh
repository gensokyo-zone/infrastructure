#!/usr/bin/env -S nix shell nixpkgs#kubernetes-helm --command bash
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
