#!/bin/bash
# Configure Vault PKI Secrets Engine
# Issues TLS certificates for internal services
# Eliminates need for self-signed or manually managed certs

set -euo pipefail

DOMAIN="vault-eks.internal"

echo "Configuring Vault PKI Secrets Engine..."

# Enable PKI secrets engine at pki/ path
vault secrets enable pki

# Configure PKI max lease TTL - 10 years for root CA
vault secrets tune 
  -max-lease-ttl=87600h 
  pki

# Generate root CA
vault write -field=certificate pki/root/generate/internal 
  common_name="${DOMAIN} Root CA" 
  organization="Tech with Emma" 
  country="NG" 
  locality="Lagos" 
  ttl=87600h > /tmp/root-ca.crt

echo "Root CA generated"

# Configure PKI URLs
vault write pki/config/urls 
  issuing_certificates="http://localhost:8200/v1/pki/ca" 
  crl_distribution_points="http://localhost:8200/v1/pki/crl"

# Enable intermediate PKI
vault secrets enable -path=pki_int pki

vault secrets tune 
  -max-lease-ttl=43800h 
  pki_int

# Generate intermediate CA CSR
vault write -format=json pki_int/intermediate/generate/internal 
  common_name="${DOMAIN} Intermediate CA" 
  organization="Tech with Emma" 
  | jq -r '.data.csr' > /tmp/intermediate.csr

echo "Intermediate CA CSR generated"

# Sign intermediate CA with root CA
vault write -format=json pki/root/sign-intermediate 
  csr=@/tmp/intermediate.csr 
  format=pem_bundle 
  ttl=43800h 
  | jq -r '.data.certificate' > /tmp/intermediate.cert

echo "Intermediate CA signed by root CA"

# Set signed intermediate certificate
vault write pki_int/intermediate/set-signed 
  certificate=@/tmp/intermediate.cert

# Configure intermediate PKI URLs
vault write pki_int/config/urls 
  issuing_certificates="http://localhost:8200/v1/pki_int/ca" 
  crl_distribution_points="http://localhost:8200/v1/pki_int/crl"

# Create role for demo-app certificate issuance
vault write pki_int/roles/demo-app 
  allowed_domains="${DOMAIN}" 
  allow_subdomains=true 
  allow_glob_domains=false 
  max_ttl=720h 
  key_type=rsa 
  key_bits=2048 
  require_cn=true

echo "PKI role demo-app created"

# Test certificate issuance
echo "Testing certificate issuance..."
vault write pki_int/issue/demo-app 
  common_name="demo-app.${DOMAIN}" 
  ttl=24h

echo "PKI secrets engine configuration complete"

# Clean up temp files
rm -f /tmp/root-ca.crt /tmp/intermediate.csr /tmp/intermediate.cert
