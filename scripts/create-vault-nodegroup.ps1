param(
  [string]$ClusterName = "vault-eks-cluster",
  [string]$Region = "us-east-1",
  [string]$NodegroupName = "vault-ec2-ng",
  [string]$InstanceType = "t3.large",
  [int]$Nodes = 3,
  [int]$NodesMin = 3,
  [int]$NodesMax = 5
)

$ErrorActionPreference = "Stop"

eksctl create nodegroup `
  --cluster $ClusterName `
  --region $Region `
  --name $NodegroupName `
  --node-type $InstanceType `
  --nodes $Nodes `
  --nodes-min $NodesMin `
  --nodes-max $NodesMax `
  --node-volume-size 80 `
  --node-labels "workload=vault"
