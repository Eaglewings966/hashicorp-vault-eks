data "aws_caller_identity" "current" {}

# -------------------------------------------------------
# IAM ROLE — Vault server pods (IRSA)
# Vault needs KMS access for auto-unseal and
# IAM permissions to generate dynamic credentials
# -------------------------------------------------------
resource "aws_iam_role" "vault_server" {
  name = "${var.project_name}-vault-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.vault_namespace}:vault"
            "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-vault-server-role"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "vault_server" {
  name = "${var.project_name}-vault-server-policy"
  role = aws_iam_role.vault_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VaultKMSUnseal"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.vault_unseal.arn
      },
      {
        Sid    = "VaultDynamicIAM"
        Effect = "Allow"
        Action = [
          "iam:AttachUserPolicy",
          "iam:CreateAccessKey",
          "iam:CreateUser",
          "iam:DeleteAccessKey",
          "iam:DeleteUser",
          "iam:DeleteUserPolicy",
          "iam:DetachUserPolicy",
          "iam:GetUser",
          "iam:ListAccessKeys",
          "iam:ListAttachedUserPolicies",
          "iam:ListGroupsForUser",
          "iam:ListUserPolicies",
          "iam:PutUserPolicy",
          "iam:AddUserToGroup",
          "iam:RemoveUserFromGroup"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/vault-*"
        ]
      },
      {
        Sid    = "VaultSTSDynamic"
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:GetFederationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# -------------------------------------------------------
# OIDC PROVIDER — for IRSA
# -------------------------------------------------------
resource "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  ]
}
