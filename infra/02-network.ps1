<#
  02-network.ps1  —  Two paired VNets + delegated subnets + peering.

  US geography (unitedstates) requires TWO VNets in the paired Azure regions (eastus + westus),
  each with a subnet delegated to Microsoft.PowerPlatform/enterprisePolicies. VNet A also holds a
  subnet delegated to Microsoft.App/environments for the internal Container Apps environment.
  The VNets are peered so the ACA endpoint in VNet A is reachable from a Power Platform runtime
  container injected into either region.

  Run after: . .\infra\00-variables.ps1
#>

az account set --subscription $SubscriptionId

Write-Host "== VNet A ($RegionA) + Power Platform delegated subnet =="
az network vnet create -g $ResourceGroup -n $VnetAName -l $RegionA --address-prefixes $VnetAPrefix `
  --subnet-name $PpSubnet --subnet-prefixes $PpSubnetAPrefix --query "newVNet.provisioningState" -o tsv
az network vnet subnet update -g $ResourceGroup --vnet-name $VnetAName -n $PpSubnet `
  --delegations Microsoft.PowerPlatform/enterprisePolicies --query "delegations[0].serviceName" -o tsv

Write-Host "== ACA infrastructure subnet (delegated to Microsoft.App/environments) in VNet A =="
az network vnet subnet create -g $ResourceGroup --vnet-name $VnetAName -n $AcaSubnet --address-prefixes $AcaSubnetPrefix `
  --delegations Microsoft.App/environments --query "delegations[0].serviceName" -o tsv

Write-Host "== VNet B ($RegionB) + Power Platform delegated subnet =="
az network vnet create -g $ResourceGroup -n $VnetBName -l $RegionB --address-prefixes $VnetBPrefix `
  --subnet-name $PpSubnet --subnet-prefixes $PpSubnetBPrefix --query "newVNet.provisioningState" -o tsv
az network vnet subnet update -g $ResourceGroup --vnet-name $VnetBName -n $PpSubnet `
  --delegations Microsoft.PowerPlatform/enterprisePolicies --query "delegations[0].serviceName" -o tsv

Write-Host "== peer VNet A <-> VNet B =="
az network vnet peering create -g $ResourceGroup -n peer-a-to-b --vnet-name $VnetAName --remote-vnet $VnetBName --allow-vnet-access --query "peeringState" -o tsv
az network vnet peering create -g $ResourceGroup -n peer-b-to-a --vnet-name $VnetBName --remote-vnet $VnetAName --allow-vnet-access --query "peeringState" -o tsv

Write-Host ""
Write-Host "Network ready: $VnetAName ($RegionA) peered with $VnetBName ($RegionB); PP subnet delegated in both; ACA subnet in $VnetAName."
