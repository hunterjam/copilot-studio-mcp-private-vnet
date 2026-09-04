<#
  99-teardown.ps1  —  Remove all Azure resources and unlink the Power Platform policy.

  Run after: . .\infra\00-variables.ps1
#>

az account set --subscription $SubscriptionId

Write-Host "== delete resource group $ResourceGroup =="
az group delete -n $ResourceGroup --yes --no-wait
Write-Host "  Deletion started (async)."

Write-Host ""
Write-Host "IMPORTANT — also unlink the enterprise policy from your Power Platform environment:"
Write-Host "  Install-Module Microsoft.PowerPlatform.EnterprisePolicies -Scope CurrentUser"
Write-Host "  Disable-SubnetInjection -EnvironmentId $EnvironmentId"
Write-Host "  (or PPAC -> Security -> Data and privacy -> Azure Virtual Network policies -> remove)"
Write-Host ""
Write-Host "Enabling/disabling subnet injection can cause ~30 min of environment instability."
