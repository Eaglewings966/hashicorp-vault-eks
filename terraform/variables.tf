variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "vault-eks"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "owner" {
  description = "Resource owner tag"
  type        = string
  default     = "emmanuel-ubani"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "vault-eks-cluster"
}

variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "vault_replicas" {
  description = "Number of Vault server replicas"
  type        = number
  default     = 5
}

variable "vault_chart_version" {
  description = "HashiCorp Vault Helm chart version"
  type        = string
  default     = "0.27.0"
}

variable "vault_image_tag" {
  description = "Vault container image tag"
  type        = string
  default     = "1.15.4"
}

variable "kms_key_deletion_days" {
  description = "Days before KMS key deletion on destroy"
  type        = number
  default     = 7
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "vaultadmin"
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "vaultdemo"
}

variable "alert_email" {
  description = "Email for security alerts"
  type        = string
  default     = "devops-alerts@gmail.com"
}
