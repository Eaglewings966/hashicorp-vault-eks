# Vault EC2 Migration

Vault server pods use persistent volumes for Raft data and audit logs. Those pods cannot be scheduled onto the existing Fargate profile, so the Vault StatefulSet must run on an EC2 managed node group.

## One-time node group creation

Run this from PowerShell:

```powershell
.\scripts\create-vault-nodegroup.ps1
```

That creates a managed node group named `vault-ec2-ng` with the label `workload=vault`.

## Redeploy Vault onto EC2 nodes

After the node group is ready:

```powershell
kubectl get nodes --show-labels
helm upgrade --install vault hashicorp/vault `
  --namespace vault `
  --values .\helm\vault\values.yaml
kubectl rollout status statefulset/vault -n vault --timeout=10m
kubectl get pods -n vault -o wide
```

The `server.nodeSelector.workload=vault` setting in `helm/vault/values.yaml` pins the Vault StatefulSet to the EC2 nodes while allowing stateless workloads like the injector to stay on Fargate.

## Continue initialization

Once the `vault-0` through `vault-4` pods are `Running` or `Ready`, continue with:

```powershell
bash scripts/vault-init.sh
```
