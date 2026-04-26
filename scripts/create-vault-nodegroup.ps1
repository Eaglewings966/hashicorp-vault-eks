param(
  [string]$ClusterName = "vault-eks-cluster",
  [string]$Region = "us-east-1",
  [string]$NodegroupName = "vault-ec2-ng",
  [string]$InstanceType = "t3.medium",
  [int]$Nodes = 2,
  [int]$NodesMin = 2,
  [int]$NodesMax = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-RequiredCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' is not available in PATH."
  }
}

if ($NodesMin -gt $NodesMax) {
  throw "Invalid scaling values: NodesMin ($NodesMin) cannot be greater than NodesMax ($NodesMax)."
}

if ($Nodes -lt $NodesMin -or $Nodes -gt $NodesMax) {
  throw "Invalid desired node count: Nodes ($Nodes) must be between NodesMin ($NodesMin) and NodesMax ($NodesMax)."
}

Test-RequiredCommand -Name "aws"
Test-RequiredCommand -Name "eksctl"

Write-Host "Validating AWS credentials..."
aws sts get-caller-identity --output text | Out-Null

Write-Host "Checking EKS cluster '$ClusterName' in region '$Region'..."
$cluster = & eksctl get cluster --name $ClusterName --region $Region --output json 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($cluster)) {
  throw "EKS cluster '$ClusterName' was not found in region '$Region'."
}

Write-Host "Checking whether node group '$NodegroupName' already exists..."
$existingNodegroup = & eksctl get nodegroup --cluster $ClusterName --region $Region --name $NodegroupName --output json 2>$null
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existingNodegroup)) {
  Write-Host "Node group '$NodegroupName' already exists. Nothing to create."
  exit 0
}

Write-Host "Creating node group '$NodegroupName'..."
$createArgs = @(
  "create", "nodegroup",
  "--cluster", $ClusterName,
  "--region", $Region,
  "--name", $NodegroupName,
  "--node-type", $InstanceType,
  "--nodes", $Nodes,
  "--nodes-min", $NodesMin,
  "--nodes-max", $NodesMax,
  "--node-volume-size", "80",
  "--node-labels", "workload=vault"
)

& eksctl @createArgs
if ($LASTEXITCODE -ne 0) {
  throw "Node group creation failed for '$NodegroupName'."
}

Write-Host "Node group '$NodegroupName' created successfully."
