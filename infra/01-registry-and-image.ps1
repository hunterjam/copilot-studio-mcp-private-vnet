<#
  01-registry-and-image.ps1  —  Register providers, create ACR, build the MCP image.

  Uses ACR Tasks (`az acr build`) so the image builds server-side — no local Docker and no
  Azure VM/compute quota needed. Run from the repo root after: . .\infra\00-variables.ps1
#>

az account set --subscription $SubscriptionId

Write-Host "== register resource providers =="
foreach ($p in @("Microsoft.Network","Microsoft.App","Microsoft.ContainerRegistry","Microsoft.OperationalInsights","Microsoft.PowerPlatform")) {
    az provider register -n $p | Out-Null
    Write-Host "  $p -> $(az provider show -n $p --query registrationState -o tsv)"
}

Write-Host "== ensure containerapp CLI extension =="
az extension add -n containerapp --upgrade 2>$null | Out-Null

az group create -n $ResourceGroup -l $RegionA | Out-Null

Write-Host "== create ACR (Basic, admin enabled) =="
az acr create -g $ResourceGroup -n $AcrName --sku Basic --admin-enabled true `
  --query "{name:name, state:provisioningState}" -o json

Write-Host "== build image $ImageName from ./server (ACR Tasks) =="
az acr build -r $AcrName -t $ImageName ./server

Write-Host ""
Write-Host "Image built: $AcrName.azurecr.io/$ImageName"
