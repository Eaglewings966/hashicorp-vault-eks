#!/bin/bash
# Configure Vault AWS Secrets Engine
# Generates dynamic, short-lived AWS credentials on demand

set -euo pipefail

if command -v aws >/dev/null 2>&1; then
  AWS_BIN="aws"
elif command -v aws.exe >/dev/null 2>&1; then
  AWS_BIN="aws.exe"
else
  echo "aws is not installed or not available in PATH"
  exit 1
fi

AWS_ACCOUNT_ID=$("${AWS_BIN}" sts get-caller-identity 
  --query Account --output text)

echo "Configuring Vault AWS Secrets Engine..."

# Enable AWS secrets engine
vault secrets enable aws

# Configure AWS credentials
# Vault uses IRSA - no static keys needed
vault write aws/config/root 
  region="us-east-1" 
  iam_endpoint="https://iam.amazonaws.com" 
  sts_endpoint="https://sts.amazonaws.com"

echo "AWS secrets engine configured"

# Create IAM role for demo app - S3 read-only
vault write aws/roles/demo-app-role 
  credential_type=iam_user 
  policy_document='-' <<'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::vault-demo-*",
        "arn:aws:s3:::vault-demo-*/*"
      ]
    }
  ]
}
POLICY

echo "AWS role demo-app-role created"

# Configure credential TTL
vault write aws/config/lease 
  lease="1h" 
  lease_max="24h"

echo "AWS secrets engine configuration complete"

# Test dynamic credential generation
echo "Testing dynamic credential generation..."
vault read aws/creds/demo-app-role
echo "Dynamic AWS credentials generated successfully"
