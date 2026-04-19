#!/bin/bash
# Configure Vault Database Secrets Engine
# Generates dynamic PostgreSQL credentials on demand
# Credentials are automatically revoked after TTL expires

set -euo pipefail

if command -v terraform >/dev/null 2>&1; then
  TERRAFORM_BIN="terraform"
elif command -v terraform.exe >/dev/null 2>&1; then
  TERRAFORM_BIN="terraform.exe"
else
  echo "terraform is not installed or not available in PATH"
  exit 1
fi

if command -v aws >/dev/null 2>&1; then
  AWS_BIN="aws"
elif command -v aws.exe >/dev/null 2>&1; then
  AWS_BIN="aws.exe"
else
  echo "aws is not installed or not available in PATH"
  exit 1
fi

# Get RDS endpoint from Terraform output
RDS_ENDPOINT=$("${TERRAFORM_BIN}" -chdir=../terraform output -raw rds_endpoint)

# Get master password from Secrets Manager
DB_PASSWORD=$("${AWS_BIN}" secretsmanager get-secret-value 
  --secret-id "vault-eks/rds/master-password" 
  --query "SecretString" 
  --output text | 
  python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

echo "Configuring Vault Database Secrets Engine..."

# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/demo-postgres 
  plugin_name="postgresql-database-plugin" 
  allowed_roles="demo-app-db-role,readonly-db-role" 
  connection_url="postgresql://{{username}}:{{password}}@${RDS_ENDPOINT}:5432/vaultdemo?sslmode=require" 
  username="vaultadmin" 
  password="${DB_PASSWORD}" 
  password_authentication="scram-sha-256"

echo "PostgreSQL database connection configured"

# Rotate root credentials immediately
# Vault now owns the root password - humans cannot log in with it
vault write -force database/rotate-root/demo-postgres

echo "Root credentials rotated - Vault now owns database access"

# Create demo-app role - short TTL for application use
vault write database/roles/demo-app-db-role 
  db_name="demo-postgres" 
  creation_statements="CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO "{{name}}";" 
  revocation_statements="DROP ROLE IF EXISTS "{{name}}";" 
  default_ttl="1h" 
  max_ttl="24h"

echo "Role demo-app-db-role created"

# Create readonly role - for reporting and analytics
vault write database/roles/readonly-db-role 
  db_name="demo-postgres" 
  creation_statements="CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";" 
  revocation_statements="DROP ROLE IF EXISTS "{{name}}";" 
  default_ttl="30m" 
  max_ttl="2h"

echo "Role readonly-db-role created"
echo "Database secrets engine configuration complete"

# Test dynamic credential generation
echo "Testing dynamic credential generation..."
vault read database/creds/demo-app-db-role
echo "Dynamic database credentials generated successfully"
