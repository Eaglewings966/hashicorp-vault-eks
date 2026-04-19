# Vault Admin Policy
# Full access to all secret paths and auth methods
# Assign only to platform administrators

path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
