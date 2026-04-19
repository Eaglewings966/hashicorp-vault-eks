# Application Policy
# Read-only access to application secrets
# Assign to Kubernetes service accounts via K8s auth

# KV v2 — application secrets
path "secret/data/apps/demo-app/*" {
  capabilities = ["read"]
}

path "secret/metadata/apps/demo-app/*" {
  capabilities = ["list"]
}

# AWS dynamic credentials — read-only role
path "aws/creds/demo-app-role" {
  capabilities = ["read"]
}

# Database dynamic credentials
path "database/creds/demo-app-db-role" {
  capabilities = ["read"]
}

# PKI — request certificates
path "pki/issue/demo-app" {
  capabilities = ["create", "update"]
}

# Renew and revoke own token
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
