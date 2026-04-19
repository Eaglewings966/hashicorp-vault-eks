#!/bin/bash
# Configure Vault Kubernetes Auth Method
# Run this after Vault is initialized and unsealed
# Requires VAULT_ADDR and VAULT_TOKEN environment variables

set -euo pipefail

VAULT_NAMESPACE="vault"
CLUSTER_NAME="vault-eks-cluster"
AWS_REGION="us-east-1"

if command -v kubectl >/dev/null 2>&1; then
  KUBECTL_BIN="kubectl"
elif command -v kubectl.exe >/dev/null 2>&1; then
  KUBECTL_BIN="kubectl.exe"
else
  echo "kubectl is not installed or not available in PATH"
  exit 1
fi

echo "Configuring Vault Kubernetes Auth Method..."

# Enable Kubernetes auth
vault auth enable kubernetes

# Get Kubernetes host from cluster
K8S_HOST=$("${KUBECTL_BIN}" config view 
  --minify 
  --output jsonpath='{.clusters[0].cluster.server}')

# Get CA certificate
K8S_CA=$("${KUBECTL_BIN}" config view 
  --minify 
  --raw 
  --output jsonpath='{.clusters[0].cluster.certificate-authority-data}' | 
  base64 --decode)

# Configure Kubernetes auth method
vault write auth/kubernetes/config 
  kubernetes_host="${K8S_HOST}" 
  kubernetes_ca_cert="${K8S_CA}" 
  issuer="https://kubernetes.default.svc.cluster.local"

echo "Kubernetes auth configured successfully"

# Create role for demo-app service account
vault write auth/kubernetes/role/demo-app 
  bound_service_account_names=demo-app 
  bound_service_account_namespaces=demo-app 
  policies=app-policy 
  ttl=1h 
  max_ttl=24h

echo "Kubernetes role demo-app created"

# Create role for vault-admin service account
vault write auth/kubernetes/role/vault-admin 
  bound_service_account_names=vault-admin 
  bound_service_account_namespaces=vault 
  policies=admin-policy 
  ttl=1h 
  max_ttl=8h

echo "Kubernetes role vault-admin created"
echo "Kubernetes auth configuration complete"
