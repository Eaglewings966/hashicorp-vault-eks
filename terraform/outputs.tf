output "kms_key_id" {
  description = "KMS key ID used for Vault auto-unseal"
  value       = aws_kms_key.vault_unseal.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for Vault auto-unseal"
  value       = aws_kms_key.vault_unseal.arn
}

output "vault_server_role_arn" {
  description = "IAM role ARN for Vault server IRSA"
  value       = aws_iam_role.vault_server.arn
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint for dynamic credentials"
  value       = aws_db_instance.vault_demo.address
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN for RDS master password"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "vault_namespace" {
  description = "Kubernetes namespace where Vault is deployed"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "vault_port_forward" {
  description = "Command to access Vault UI locally"
  value       = "kubectl port-forward svc/vault -n vault 8200:8200"
}

output "vault_ui_url" {
  description = "Vault UI URL after port-forward"
  value       = "http://localhost:8200/ui"
}

output "vault_init_command" {
  description = "Command to initialize Vault cluster"
  value       = "kubectl exec -it vault-0 -n vault -- vault operator init -key-shares=5 -key-threshold=3"
}

output "destroy_command" {
  description = "Full destroy sequence"
  value       = "terraform destroy --auto-approve && eksctl delete cluster --name ${var.cluster_name} --region ${var.aws_region}"
}
