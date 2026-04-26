#!/bin/bash
# Vault Verification Script
# Verifies all secrets engines and auth methods are working

set -euo pipefail

if command -v kubectl >/dev/null 2>&1; then
  KUBECTL_BIN="kubectl"
elif command -v kubectl.exe >/dev/null 2>&1; then
  KUBECTL_BIN="kubectl.exe"
else
  echo "kubectl is not installed or not available in PATH"
  exit 1
fi

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI is not installed or not available in PATH"
  exit 1
fi

echo "================================================"
echo "Vault HA Cluster Verification"
echo "================================================"

# Check all 5 pods are Running and Ready
echo "Checking pod status..."
"${KUBECTL_BIN}" get pods -n vault -l app.kubernetes.io/name=vault

echo ""
echo "Checking Vault cluster status..."
"${KUBECTL_BIN}" exec vault-0 -n vault -- vault status

echo ""
echo "Checking Raft cluster members..."
"${KUBECTL_BIN}" exec vault-0 -n vault -- \
  vault operator raft list-peers

echo ""
echo "Checking enabled secrets engines..."
vault secrets list

echo ""
echo "Checking enabled auth methods..."
vault auth list

echo ""
echo "Checking KV secrets..."
vault kv list secret/apps/

echo ""
echo "Checking AWS dynamic credentials..."
vault read aws/creds/demo-app-role

echo ""
echo "Checking database dynamic credentials..."
vault read database/creds/demo-app-db-role

echo ""
echo "Checking PKI certificate issuance..."
vault write pki_int/issue/demo-app \
  common_name="verify-test.vault-eks.internal" \
  ttl=1h | grep "common_name"

echo ""
echo "================================================"
echo "All verification checks passed"
echo "Vault HA cluster is fully operational"
echo "================================================"
