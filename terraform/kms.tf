# -------------------------------------------------------
# KMS KEY — Vault auto-unseal
# This key is what allows Vault pods to unseal themselves
# automatically on restart without human intervention
# -------------------------------------------------------
resource "aws_kms_key" "vault_unseal" {
  description             = "Vault auto-unseal key for ${var.project_name}"
  deletion_window_in_days = var.kms_key_deletion_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowVaultUnseal"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.vault_server.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-vault-unseal"
    Environment = var.environment
    Owner       = var.owner
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/${var.project_name}-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}
