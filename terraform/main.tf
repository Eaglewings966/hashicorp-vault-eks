provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = var.owner
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster" "main" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  name = var.cluster_name
}

provider "kubernetes" {
  host = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.main.certificate_authority[0].data
  )
  token = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.main.certificate_authority[0].data
    )
    token = data.aws_eks_cluster_auth.main.token
  }
}

# -------------------------------------------------------
# RDS POSTGRESQL — for dynamic credential demonstration
# -------------------------------------------------------
resource "aws_db_subnet_group" "vault_demo" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.private.ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "tag:kubernetes.io/role/internal-elb"
    values = ["1"]
  }
}

data "aws_vpc" "eks" {
  filter {
    name   = "tag:aws:cloudformation:stack-name"
    values = ["eksctl-${var.cluster_name}-cluster"]
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS security group for Vault dynamic credentials demo"
  vpc_id      = data.aws_vpc.eks.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.eks.cidr_block]
    description = "PostgreSQL from EKS VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

resource "aws_db_instance" "vault_demo" {
  identifier        = "${var.project_name}-demo-db"
  engine            = "postgres"
  engine_version    = "15.7"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.vault_demo.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "${var.project_name}-demo-db"
  }
}

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store DB password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}/rds/master-password"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.vault_demo.address
    port     = 5432
    dbname   = var.db_name
  })
}

# -------------------------------------------------------
# VAULT NAMESPACE
# -------------------------------------------------------
resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "project"                      = var.project_name
    }
  }
}

# -------------------------------------------------------
# VAULT SERVICE ACCOUNT — with IRSA annotation
# -------------------------------------------------------
resource "kubernetes_service_account" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.vault.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.vault_server.arn
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# -------------------------------------------------------
# VAULT HELM RELEASE — 5-replica HA with Raft storage
# -------------------------------------------------------
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name
  timeout    = 900

  values = [file("${path.module}/../helm/vault/values.yaml")]

  set {
    name  = "server.image.tag"
    value = var.vault_image_tag
  }

  set {
    name  = "server.ha.replicas"
    value = var.vault_replicas
  }

  set {
    name  = "server.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "server.serviceAccount.name"
    value = kubernetes_service_account.vault.metadata[0].name
  }

  # AWS KMS auto-unseal configuration
  set {
    name  = "server.extraEnvironmentVars.VAULT_SEAL_TYPE"
    value = "awskms"
  }

  set {
    name  = "server.extraEnvironmentVars.VAULT_AWSKMS_SEAL_KEY_ID"
    value = aws_kms_key.vault_unseal.key_id
  }

  set {
    name  = "server.extraEnvironmentVars.AWS_REGION"
    value = var.aws_region
  }

  depends_on = [
    kubernetes_namespace.vault,
    kubernetes_service_account.vault,
    aws_kms_key.vault_unseal
  ]
}

# -------------------------------------------------------
# SNS ALERT — Vault pod failures
# -------------------------------------------------------
resource "aws_sns_topic" "vault_alerts" {
  name = "${var.project_name}-vault-alerts"
}

resource "aws_sns_topic_subscription" "vault_alerts_email" {
  topic_arn = aws_sns_topic.vault_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
