#!/bin/bash
# Configure Vault KV v2 Secrets Engine
# Stores static application secrets with versioning

set -euo pipefail

if command -v terraform >/dev/null 2>&1; then
  TERRAFORM_BIN="terraform"
elif command -v terraform.exe >/dev/null 2>&1; then
  TERRAFORM_BIN="terraform.exe"
else
  echo "terraform is not installed or not available in PATH"
  exit 1
fi

echo "Configuring Vault KV v2 Secrets Engine..."

# Enable KV v2 secrets engine at secret/ path
vault secrets enable -path=secret kv-v2

echo "KV v2 secrets engine enabled"

# Configure KV engine settings
vault write secret/config 
  max_versions=10 
  delete_version_after="720h"

echo "KV engine configured - 10 versions retained, 30 day delete"

# Write demo application secrets
vault kv put secret/apps/demo-app/config 
  app_name="devops-demo-app" 
  app_version="2.0.0" 
  log_level="info" 
  feature_flags='{"new_dashboard":true,"beta_api":false}'

echo "Demo app config secrets written"

# Write database connection config (non-sensitive portion)
vault kv put secret/apps/demo-app/database 
  db_host="$("${TERRAFORM_BIN}" -chdir=../terraform output -raw rds_endpoint)" 
  db_port="5432" 
  db_name="vaultdemo" 
  db_ssl_mode="require"

echo "Database config secrets written"

# Write API keys (example structure)
vault kv put secret/apps/demo-app/api-keys 
  stripe_publishable_key="pk_test_demo" 
  sendgrid_from_email="no-reply@techwithecmma.dev"

echo "API keys written"

# Verify secrets are stored correctly
echo "Verifying KV secrets..."
vault kv get secret/apps/demo-app/config
vault kv metadata get secret/apps/demo-app/config

echo "KV v2 secrets engine configuration complete"
