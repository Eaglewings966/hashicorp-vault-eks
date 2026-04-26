<div align="center">

# HashiCorp Vault HA Cluster on AWS EKS

[![Vault](https://img.shields.io/badge/HashiCorp_Vault-1.15.4-FFEC6E?style=for-the-badge&logo=vault&logoColor=black)](https://www.vaultproject.io/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS_Fargate-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com/fargate/)
[![AWS KMS](https://img.shields.io/badge/AWS-KMS_Auto--Unseal-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)](https://aws.amazon.com/kms/)
[![Raft](https://img.shields.io/badge/Storage-Raft_Integrated-00B4D8?style=for-the-badge)](https://developer.hashicorp.com/vault/docs/concepts/integrated-storage)
[![Helm](https://img.shields.io/badge/Helm-3.0-0F1689?style=for-the-badge&logo=helm&logoColor=white)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.29-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/Eaglewings966/hashicorp-vault-eks?style=for-the-badge&color=3b82f6)](https://github.com/Eaglewings966/hashicorp-vault-eks)

**An enterprise-grade HashiCorp Vault HA cluster on AWS EKS Fargate
with Raft integrated storage, AWS KMS auto-unseal, dynamic AWS and
database credentials, PKI certificate authority, and Vault Agent
sidecar injection — eliminating static secrets from every workload.**

[📖 Full Technical Article](https://emmanuelubani.hashnode.dev) •
[💼 LinkedIn](https://linkedin.com/in/ubaniemmanuel) •
[🐙 GitHub](https://github.com/Eaglewings966) •
[🌐 Portfolio](https://ops-run.lovable.app)

</div>

---

## Table of Contents

- [Problem Statement](#problem-statement)
- [Business Impact](#business-impact)
- [Architecture Overview](#architecture-overview)
- [Architecture Decisions](#architecture-decisions)
- [Secrets Engines](#secrets-engines)
- [DevOps Toolchain](#devops-toolchain)
- [Project Structure](#project-structure)
- [Security Implementation](#security-implementation)
- [Prerequisites](#prerequisites)
- [Deployment](#deployment)
- [HA Failover Testing](#ha-failover-testing)
- [Production Considerations](#production-considerations)
- [Key Lessons Learned](#key-lessons-learned)
- [Destroy Everything](#destroy-everything)
- [Author](#author)

---

## Problem Statement

Static credentials are the leading cause of cloud security
incidents. An access key that lives in a Kubernetes secret,
an environment variable, a configuration file, or a CI/CD
pipeline is a credential that can be stolen, leaked, rotated
incorrectly, or forgotten. Once an attacker obtains a static
credential, they have persistent access until someone discovers
the breach and manually rotates it.

The alternative is dynamic credentials. Credentials that are
generated on demand, valid for minutes or hours, and
automatically revoked when the requesting workload no longer
needs them. No credential to steal. No rotation to forget.
No persistent access for an attacker who somehow obtains one.

This platform implements dynamic credentials for AWS IAM,
PostgreSQL databases, and TLS certificates — alongside
a secure KV store for static secrets that cannot be dynamic —
all served from a five-node Vault HA cluster that auto-unseals
via AWS KMS and survives any single node failure without
human intervention.

---

## Business Impact

| Security Problem | Static Credential Approach | Vault Dynamic Approach |
|-----------------|---------------------------|----------------------|
| Credential theft | Persistent access until rotation | Credential expired in 1 hour |
| Rotation failure | Human error causes outage | Automatic, zero human touch |
| Audit trail | None — who used this key? | Full Vault audit log per request |
| Blast radius | All systems using that key | One token, one TTL, auto-revoked |
| Database passwords | Long-lived, shared | Per-pod, per-session, auto-expired |
| TLS certificates | Manual rotation, often forgotten | PKI engine auto-issues and rotates |
| Vault availability | Single point of failure | 5-node Raft HA, survives 2 failures |
| Unseal on restart | Manual human intervention | AWS KMS auto-unseal, zero touch |

---

## Architecture Overview
```
┌──────────────────────────────────────────────────────────────────┐
│                    AWS us-east-1                                  │
│                                                                  │
│  AWS KMS Key ──────────────────────────────────────────────┐    │
│  (vault-eks-vault-unseal)                                   │    │
│  Auto-unseals Vault pods on restart                         │    │
│                                                             │    │
│  EKS Cluster: vault-eks-cluster — Fargate                  │    │
│                                                             │    │
│  ┌─────────────────────────────────────────────────────┐   │    │
│  │  namespace: vault                                   │   │    │
│  │                                                     │   │    │
│  │  vault-0 (leader)  ◄──── Raft consensus             │   │    │
│  │  vault-1 (follower) │                               │   │    │
│  │  vault-2 (follower) │    5-node HA cluster          │   │    │
│  │  vault-3 (follower) │    quorum = 3 of 5            │   │    │
│  │  vault-4 (follower) ◄────                           │   │    │
│  │                                                     │   │    │
│  │  Vault Injector (2 replicas)                        │   │    │
│  │  Intercepts pod admission                           │   │    │
│  │  Injects Agent sidecar containers                   │   │    │
│  └─────────────────────────────────────────────────────┘   │    │
│            │                                                │    │
│            │  Dynamic credentials                          │    │
│            ▼                                                │    │
│  ┌─────────────────────────────────────────────────────┐   │    │
│  │  namespace: demo-app                                │   │    │
│  │                                                     │   │    │
│  │  demo-app pod                                       │   │    │
│  │  ├── app container (reads /vault/secrets/)          │   │    │
│  │  └── vault-agent sidecar                            │   │    │
│  │       ├── Fetches KV secrets                        │   │    │
│  │       ├── Fetches dynamic AWS credentials           │   │    │
│  │       ├── Fetches dynamic DB credentials            │   │    │
│  │       └── Fetches PKI certificate                   │   │    │
│  └─────────────────────────────────────────────────────┘   │    │
│                                                             │    │
│  Secrets Engines:                                           │    │
│  ├── KV v2      ── Static versioned secrets                 │    │
│  ├── AWS        ── Dynamic IAM credentials (1h TTL)         │    │
│  ├── Database   ── Dynamic PostgreSQL creds (1h TTL)        │    │
│  └── PKI        ── TLS certificate authority                │    │
│                                                             │    │
│  RDS PostgreSQL ────────────────────────────────────────────┘    │
│  (Vault owns root password after rotation)                       │
└──────────────────────────────────────────────────────────────────┘
```

---

## Architecture Decisions

**Why 5 replicas instead of 3**
Raft requires a quorum of floor(n/2)+1 nodes to operate.
With 3 nodes, losing 1 leaves you at 2 — exactly at quorum.
One network partition away from a split-brain scenario.
With 5 nodes, you can lose 2 simultaneously and maintain quorum
with 3. For a secrets platform that everything else depends on,
the extra 2 pods are not a cost — they are insurance.

**Why Raft over Consul storage**
Consul as a storage backend introduces a second distributed
system that Vault depends on. If Consul has an issue, Vault
goes down. Raft integrated storage eliminates this dependency.
Vault manages its own consensus. Fewer components, fewer failure
modes, simpler operations.

**Why AWS KMS auto-unseal over Shamir key shares**
Shamir key shares require human operators to provide the unseal
keys every time Vault restarts. In a Kubernetes environment where
pods can restart at any time, this means an on-call engineer must
manually unseal Vault after every pod restart. AWS KMS auto-unseal
delegates this to a hardware security module that Vault can
call automatically. The recovery keys still exist for emergency
use but day-to-day operations require zero human intervention.

**Why IRSA over static IAM credentials**
Vault needs IAM permissions for KMS auto-unseal and for the
AWS dynamic credentials engine. Storing static IAM access keys
in Vault configuration is the same problem Vault is supposed to
solve. IRSA binds an IAM role to the Vault Kubernetes service
account via OIDC, giving Vault AWS permissions through the
pod identity rather than credentials.

**Why Vault Agent sidecar over application SDK**
If applications use the Vault SDK directly, every application
must implement token renewal, secret rotation, and error handling.
The Vault Agent sidecar handles all of that transparently.
Applications read files from `/vault/secrets/`. They never
talk to Vault directly. Secrets are always fresh. The application
code has zero dependency on Vault's API.

---

## Secrets Engines

| Engine | Path | What It Provides | TTL |
|--------|------|-----------------|-----|
| KV v2 | `secret/` | Versioned static secrets — config, API keys | Permanent with versioning |
| AWS | `aws/` | Dynamic IAM users with scoped policies | 1 hour default |
| Database | `database/` | Dynamic PostgreSQL roles — per-request | 1 hour default |
| PKI | `pki_int/` | TLS certificates from internal CA | 24 hours default |

---

## DevOps Toolchain

| Tool | Version | Purpose |
|------|---------|---------|
| HashiCorp Vault | 1.15.4 | Secrets management, dynamic credentials, PKI |
| Terraform | 1.5+ | KMS, RDS, IAM, OIDC provisioning |
| AWS EKS Fargate | 1.29 | Kubernetes compute platform |
| AWS KMS | Latest | Vault auto-unseal hardware key |
| AWS RDS PostgreSQL | 15.4 | Dynamic credential target database |
| Helm | 3.x | Vault cluster installation |
| eksctl | 0.220.0 | EKS Fargate cluster provisioning |
| kubectl | Latest | Cluster interaction and verification |

---

## Project Structure
```
hashicorp-vault-eks/
│
├── terraform/
│   ├── main.tf              # Providers, RDS, Vault Helm, namespaces
│   ├── kms.tf               # KMS key for auto-unseal
│   ├── iam.tf               # IRSA role, OIDC provider, IAM policies
│   ├── variables.tf         # All configurable variables
│   ├── outputs.tf           # KMS ID, RDS endpoint, role ARNs
│   ├── versions.tf          # Provider version constraints
│   └── terraform.tfvars     # Variable values (not committed)
│
├── helm/vault/
│   └── values.yaml          # 5-replica HA Vault with Raft config
│
├── vault-config/
│   ├── auth/
│   │   └── kubernetes-auth.sh         # Kubernetes auth method setup
│   ├── pki/
│   │   └── pki-setup.sh               # Internal CA setup
│   ├── policies/
│   │   ├── admin-policy.hcl           # Full admin access policy
│   │   ├── app-policy.hcl             # App read-only policy
│   │   └── pki-policy.hcl             # Certificate issuance policy
│   └── secrets/
│       ├── aws-secrets-engine.sh      # AWS dynamic credentials
│       ├── database-secrets-engine.sh # PostgreSQL dynamic creds
│       ├── demo-app-aws-policy.json   # IAM policy for demo app role
│       └── kv-secrets-engine.sh       # KV v2 static secrets
│
├── apps/demo-app/
│   ├── deployment.yaml      # App with Vault Agent sidecar
│   └── serviceaccount.yaml  # Service account for K8s auth
│
├── docs/
│   └── vault-ec2-migration.md  # EC2 migration reference
│
├── scripts/
│   ├── create-vault-nodegroup.ps1  # EKS node group provisioning
│   ├── vault-init.sh               # One-time initialization script
│   └── vault-verify.sh             # Verification and health check
│
├── .gitignore
└── README.md
```

---

## Security Implementation

**AWS KMS auto-unseal**
The KMS key policy allows only the Vault server IAM role to
call kms:Encrypt and kms:Decrypt. No other principal can use
the key to unseal Vault. Key rotation is enabled annually.

**IRSA least privilege**
The Vault server IAM role has exactly four permission sets.
KMS encrypt/decrypt for auto-unseal. IAM user management
scoped to `vault-*` prefixed users only for dynamic credentials.
STS for credential federation. Nothing else.

**Database root credential rotation**
After configuring the database secrets engine, Vault rotates
the RDS master password immediately. From that point, no human
knows the root database password. Only Vault can authenticate
as the root user and only to create and revoke dynamic roles.

**Audit logging**
Vault audit logging should be enabled immediately after
initialization. Every secret read, every credential generation,
every authentication event is logged with timestamp, client
identity, and request path.

**Pod Disruption Budget**
The Vault PDB allows a maximum of 2 unavailable pods at any time,
preserving the 3-node quorum minimum for a 5-node Raft cluster.

---

## Prerequisites

| Tool | Version | Verify |
|------|---------|--------|
| AWS CLI | v2.x | `aws --version` |
| eksctl | v0.220.0 | `eksctl version` |
| Terraform | v1.5+ | `terraform --version` |
| kubectl | Latest | `kubectl version --client` |
| Helm | v3.x | `helm version` |
| Vault CLI | v1.15+ | `vault version` |
| jq | Latest | `jq --version` |

---

## Deployment

### Phase 1 — EKS Fargate Cluster
```bash
eksctl create cluster \
  --name vault-eks-cluster \
  --region us-east-1 \
  --fargate

for ns in vault demo-app; do
  eksctl create fargateprofile \
    --cluster vault-eks-cluster \
    --region us-east-1 \
    --name fp-${ns} \
    --namespace ${ns}
done
```

### Phase 2 — Infrastructure via Terraform
```bash
cd terraform && terraform apply --auto-approve
```

### Phase 3 — Initialize Vault
```bash
bash scripts/vault-init.sh
# Save recovery keys immediately
```

### Phase 4 — Configure Secrets Engines
```bash
kubectl port-forward svc/vault -n vault 8200:8200 &
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=YOUR_ROOT_TOKEN

bash vault-config/auth/kubernetes-auth.sh
bash vault-config/secrets/aws-secrets-engine.sh
bash vault-config/secrets/database-secrets-engine.sh
bash vault-config/secrets/kv-secrets-engine.sh
bash vault-config/pki/pki-setup.sh
```

### Phase 5 — Deploy Demo App
```bash
kubectl apply -f apps/demo-app/serviceaccount.yaml
kubectl apply -f apps/demo-app/deployment.yaml
```

### Phase 6 — Verify
```bash
bash scripts/vault-verify.sh
```

---

## HA Failover Testing

```bash
# Identify the active leader
kubectl exec -it vault-0 -n vault -- \
  vault operator raft list-peers

# Delete the leader pod
kubectl delete pod [LEADER_POD] -n vault

# Watch Raft elect a new leader (takes 5-10 seconds)
kubectl exec -it vault-1 -n vault -- \
  vault operator raft list-peers

# Verify auto-unseal — deleted pod restarts without manual unseal
kubectl get pods -n vault -w
```

---

## Production Considerations

| Gap | Current State | Production Solution |
|-----|--------------|---------------------|
| Audit logging | Not enabled post-init | Enable file and syslog audit devices |
| Vault namespaces | Single namespace | Vault Enterprise namespaces per team |
| Response wrapping | Not demonstrated | Wrap all credentials for one-use delivery |
| Sentinel policies | Not configured | Vault Enterprise Sentinel for fine-grained policy |
| Vault agent caching | Not enabled | Agent caching reduces Vault request volume |
| Multi-region HA | Single region | Vault Enterprise replication across regions |
| Break-glass access | Root token only | Emergency recovery procedure with offline keys |
| Secrets rotation | TTL-based only | Event-driven rotation via Vault Transform engine |

---

## Key Lessons Learned

**Raft quorum math matters before you choose replica count**
With 3 nodes you can lose 1 and maintain quorum.
With 5 nodes you can lose 2. The difference is not just
availability — it is your ability to perform maintenance
on one node while being protected against a simultaneous failure.
Choose your replica count based on how many failures you need
to survive simultaneously.

**Database root credential rotation is irreversible**
When Vault rotates the RDS root password, it generates a new
random password and stores it internally. You can never retrieve
it again. If Vault becomes unavailable before you have tested
the dynamic credential path, you are locked out of the database.
Always test dynamic credential generation before rotating root.

**IRSA trust policy scope is critical**
The OIDC condition in the IRSA trust policy must match both the
service account name and namespace exactly. A misconfigured
condition allows any service account in the cluster to assume
the Vault IAM role, which has KMS and IAM permissions. Be precise.

**Vault Agent sidecar adds startup latency**
The Vault Agent init container must authenticate and fetch all
secrets before the application container starts. On Fargate,
where pod startup is already slower than EC2, this can add
30-60 seconds to pod startup time. Account for this in
your readiness probe initialDelaySeconds.

**Recovery keys and root tokens must be stored offline**
The recovery keys generated during initialization are the only
way to recover Vault if AWS KMS becomes unavailable. Storing
them in AWS Secrets Manager or any cloud service defeats the
purpose — if AWS is the problem, you cannot reach AWS to get
the keys. Print them, encrypt them, store them in a physical
safe. This is not optional.

---

## Destroy Everything

```bash
helm uninstall vault -n vault
kubectl delete namespace demo-app vault --ignore-not-found=true
cd terraform && terraform destroy --auto-approve
eksctl delete cluster --name vault-eks-cluster --region us-east-1
```

> Verify KMS key, RDS instance, Secrets Manager secret,
> and all IAM resources are removed in the AWS console.

---

## Author

<div align="center">

**Emmanuel Ubani**
Cloud and DevOps Engineer — Lagos, Nigeria

*From zoo volunteer to Cloud and DevOps Engineer.*
*Building production-grade infrastructure in public.*

[![LinkedIn](https://img.shields.io/badge/LinkedIn-ubaniemmanuel-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/ubaniemmanuel)
[![GitHub](https://img.shields.io/badge/GitHub-Eaglewings966-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Eaglewings966)
[![Hashnode](https://img.shields.io/badge/Hashnode-emmanuelubani-2962FF?style=for-the-badge&logo=hashnode&logoColor=white)](https://emmanuelubani.hashnode.dev)
[![Medium](https://img.shields.io/badge/Medium-emmaubani966-000000?style=for-the-badge&logo=medium&logoColor=white)](https://medium.com/@emmaubani966)
[![Docker Hub](https://img.shields.io/badge/Docker_Hub-eaglewings6-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://hub.docker.com/u/eaglewings6)
[![Portfolio](https://img.shields.io/badge/Portfolio-ops--run.lovable.app-6366f1?style=for-the-badge)](https://ops-run.lovable.app)

| # | Project | Repository |
|---|---------|------------|
| 1 | AWS IAM Multi-Account Setup | [aws-iam-multi-account-setup](https://github.com/Eaglewings966/aws-iam-multi-account-setup) |
| 2 | GitHub Actions CI/CD Pipeline | [github-actions-cicd-pipeline](https://github.com/Eaglewings966/github-actions-cicd-pipeline) |
| 3 | Kubernetes EKS Deployment | [eks-kubernetes-deployment](https://github.com/Eaglewings966/eks-kubernetes-deployment) |
| 4 | GitOps Platform with Argo CD | [argocd-gitops-platform](https://github.com/Eaglewings966/argocd-gitops-platform) |
| 5 | AWS Cost Optimization Engine | [aws-cost-optimization](https://github.com/Eaglewings966/aws-cost-optimization) |
| 6 | AWS Multi-Account Landing Zone | [aws-multi-account-landing-zone](https://github.com/Eaglewings966/aws-multi-account-landing-zone) |
| 7 | Enterprise DevSecOps Pipeline | [aws-devsecops-pipeline](https://github.com/Eaglewings966/aws-devsecops-pipeline) |
| 8 | HashiCorp Vault HA Cluster | This repository |

</div>