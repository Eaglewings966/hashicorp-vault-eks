#!/bin/bash
# Vault Initialization Script
# Run once after Vault pods are all Running
# With AWS KMS auto-unseal, Vault unseals itself automatically

set -euo pipefail

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"

if command -v kubectl >/dev/null 2>&1; then
  KUBECTL_BIN="kubectl"
elif command -v kubectl.exe >/dev/null 2>&1; then
  KUBECTL_BIN="kubectl.exe"
else
  echo "kubectl is not installed or not available in PATH"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is not installed or not available in PATH"
  exit 1
fi

echo "================================================"
echo "HashiCorp Vault HA Cluster Initialization"
echo "================================================"

# Wait for all Vault pods to be ready
echo "Waiting for all 5 Vault pods to be Running..."
"${KUBECTL_BIN}" wait --for=condition=Ready pods \
  -n "${VAULT_NAMESPACE}" \
  -l app.kubernetes.io/name=vault \
  --timeout=300s

echo "All Vault pods are Running"

# Check current Vault status
echo "Checking Vault initialization status..."
INIT_STATUS=$("${KUBECTL_BIN}" exec "${VAULT_POD}" \
  -n "${VAULT_NAMESPACE}" -- \
  vault status -format=json 2>/dev/null | \
  jq -r '.initialized')

if [ "${INIT_STATUS}" == "true" ]; then
  echo "Vault is already initialized"
  exit 0
fi

# Initialize Vault
# 5 key shares, 3 key threshold for quorum
# With KMS auto-unseal, Vault only uses these for recovery
echo "Initializing Vault with 5 key shares and 3 key threshold..."
INIT_OUTPUT=$("${KUBECTL_BIN}" exec "${VAULT_POD}" \
  -n "${VAULT_NAMESPACE}" -- \
  vault operator init \
    -key-shares=5 \
    -key-threshold=3 \
    -recovery-shares=5 \
    -recovery-threshold=3 \
    -format=json)

# Extract root token and recovery keys
ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | jq -r '.root_token')
RECOVERY_KEYS=$(echo "${INIT_OUTPUT}" | jq '.recovery_keys_b64')

echo ""
echo "================================================"
echo "      VAULT INITIALIZATION COMPLETE"
echo "================================================"
echo ""
echo "!!! CRITICAL SECURITY INFORMATION !!!"
echo "The following output contains your Vault cluster's"
echo "recovery keys and initial root token."
echo ""
echo "DO NOT close this terminal until you have saved this"
echo "information in a secure location (e.g., a password manager)."
echo "This is the ONLY time this information will be displayed."
echo "------------------------------------------------"
echo ""
echo "Recovery Keys (save all of them):"
echo "${RECOVERY_KEYS}"
echo ""
echo "Initial Root Token:"
echo "${ROOT_TOKEN}"
echo ""
echo "------------------------------------------------"
echo "================================================"

read -p "Have you saved the recovery keys and root token securely? Press Enter to continue..."

# Set VAULT_TOKEN for subsequent commands
export VAULT_TOKEN="${ROOT_TOKEN}"
export VAULT_ADDR="http://localhost:8200"

echo ""
echo "Run the following to set up port-forward and configure Vault:"
echo ""
echo "kubectl port-forward svc/vault -n vault 8200:8200 &"
echo "export VAULT_ADDR=http://localhost:8200"
echo "export VAULT_TOKEN=${ROOT_TOKEN}"
echo ""
echo "Then run the configuration scripts:"
echo "  bash vault-config/auth/kubernetes-auth.sh"
echo "  bash vault-config/secrets/aws-secrets-engine.sh"
echo "  bash vault-config/secrets/database-secrets-engine.sh"
echo "  bash vault-config/secrets/kv-secrets-engine.sh"
echo "  bash vault-config/pki/pki-setup.sh"
