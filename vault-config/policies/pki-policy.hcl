# PKI Policy
# Allows certificate issuance for internal services

path "pki/issue/*" {
  capabilities = ["create", "update"]
}

path "pki/cert/ca" {
  capabilities = ["read"]
}

path "pki/certs" {
  capabilities = ["list"]
}

path "pki/revoke" {
  capabilities = ["create", "update"]
}

path "pki/tidy" {
  capabilities = ["create", "update"]
}

path "pki/intermediate/issue/*" {
  capabilities = ["create", "update"]
}
