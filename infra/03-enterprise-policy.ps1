<#
  03-enterprise-policy.ps1  —  Create the Power Platform enterprise policy (subnet injection).

  Deploys enterprise-policy.json (a Microsoft.PowerPlatform/enterprisePolicies resource, kind
  NetworkInjection) referencing BOTH VNets' Power Platform subnets. There is no dedicated Azure
  portal blade for this resource type, so an ARM template is the portable path.

  Run after: . .\infra\00-variables.ps1  (and after 02-network.ps1)
#>

az account set --subscription $SubscriptionId

$vnetAId = az network vnet show -g $ResourceGroup -n $VnetAName --query id -o tsv
$vnetBId = az network vnet show -g $ResourceGroup -n $VnetBName --query id -o tsv

Write-Host "== deploy enterprise policy '$PolicyName' (geo=$PpGeo, two-region) =="
az deployment group create -g $ResourceGroup -n "$PolicyName-deploy" `
  --template-file "$PSScriptRoot\enterprise-policy.json" `
  --parameters policyName=$PolicyName powerplatformEnvironmentRegion=$PpGeo `
    vNetOneSubnetName=$PpSubnet vNetOneResourceId=$vnetAId `
    vNetTwoSubnetName=$PpSubnet vNetTwoResourceId=$vnetBId `
  --query "properties.provisioningState" -o tsv

$policyArmId = az resource show -g $ResourceGroup -n $PolicyName `
  --resource-type Microsoft.PowerPlatform/enterprisePolicies --query id -o tsv

Write-Host ""
Write-Host "Enterprise policy ARM ID:"
Write-Host "  $policyArmId"
Write-Host ""
Write-Host "NEXT — link this policy to your Power Platform environment (one of):"
Write-Host "  A) PPAC UI: admin.powerplatform.microsoft.com -> Security -> Data and privacy ->"
Write-Host "     Azure Virtual Network policies -> select env -> select $PolicyName -> Save."
Write-Host "  B) PowerShell:"
Write-Host "     Install-Module Microsoft.PowerPlatform.EnterprisePolicies -Scope CurrentUser"
Write-Host "     Enable-SubnetInjection -EnvironmentId $EnvironmentId -PolicyArmId '$policyArmId'"
Write-Host ""
Write-Host "Validate: PPAC -> Environments -> (env) -> History -> Succeeded. Allow ~30 min to settle."
