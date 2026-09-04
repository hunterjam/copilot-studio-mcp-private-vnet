<#
  04-container-app.ps1  —  Internal Container Apps env + app + private DNS.

  Creates an INTERNAL (VNet-injected, no public IP) Container Apps environment in the ACA subnet,
  deploys the MCP server image with ingress=external (which, on an internal env, publishes the app
  on the environment's INTERNAL endpoint with a clean FQDN + managed TLS cert), then wires a private
  DNS zone (wildcard -> the env's private static IP) linked to BOTH VNets so a Power Platform runtime
  container in either region can resolve and reach it.

  Why Container Apps (not App Service): App Service private-endpoint hosting needs a Basic+ plan,
  which is blocked on subscriptions with 0 App Service compute quota ("Total VMs: 0"). ACA internal
  ingress gives an equivalent private-only HTTPS endpoint with a managed cert and uses ACA quota.

  Run after: . .\infra\00-variables.ps1  (and after 02-network.ps1)
#>

az account set --subscription $SubscriptionId

$acaSubnetId = az network vnet subnet show -g $ResourceGroup --vnet-name $VnetAName -n $AcaSubnet --query id -o tsv

Write-Host "== create INTERNAL Container Apps environment (several minutes) =="
az containerapp env create -g $ResourceGroup -n $AcaEnvName -l $RegionA `
  --infrastructure-subnet-resource-id $acaSubnetId `
  --internal-only true `
  --logs-destination none `
  --query "{name:name, state:properties.provisioningState, internal:properties.vnetConfiguration.internal, staticIp:properties.staticIp, domain:properties.defaultDomain}" -o json

$staticIp = az containerapp env show -g $ResourceGroup -n $AcaEnvName --query "properties.staticIp" -o tsv
$domain   = az containerapp env show -g $ResourceGroup -n $AcaEnvName --query "properties.defaultDomain" -o tsv
Write-Host "Env private static IP: $staticIp   default domain: $domain"

Write-Host "== deploy MCP app (ingress=external on internal env => clean private FQDN) =="
$acrServer = az acr show -n $AcrName --query loginServer -o tsv
$acrUser   = az acr credential show -n $AcrName --query username -o tsv
$acrPass   = az acr credential show -n $AcrName --query "passwords[0].value" -o tsv
az containerapp create -g $ResourceGroup -n $AppName --environment $AcaEnvName `
  --image "$acrServer/$ImageName" `
  --registry-server $acrServer --registry-username $acrUser --registry-password $acrPass `
  --target-port 8000 --ingress external --transport auto `
  --min-replicas 1 --max-replicas 1 `
  --env-vars DEPLOY_MARKER=$DeployMarker `
  --query "{name:name, fqdn:properties.configuration.ingress.fqdn}" -o json

$fqdn = az containerapp show -g $ResourceGroup -n $AppName --query "properties.configuration.ingress.fqdn" -o tsv

Write-Host "== private DNS zone $domain -> $staticIp, linked to both VNets =="
az network private-dns zone create -g $ResourceGroup -n $domain --query provisioningState -o tsv
az network private-dns record-set a add-record -g $ResourceGroup -z $domain -n "*" -a $staticIp --query "aRecords[].ipv4Address" -o tsv
az network private-dns link vnet create -g $ResourceGroup -z $domain -n link-a --virtual-network $VnetAName --registration-enabled false --query provisioningState -o tsv
az network private-dns link vnet create -g $ResourceGroup -z $domain -n link-b --virtual-network $VnetBName --registration-enabled false --query provisioningState -o tsv

Write-Host ""
Write-Host "=================================================================="
Write-Host " PRIVATE MCP URL (use as the Copilot Studio MCP tool Server URL):"
Write-Host "   https://$fqdn/mcp"
Write-Host "=================================================================="
Write-Host " The environment is internal-only: this FQDN does NOT resolve on the public internet."
Write-Host " Run 05-verify-and-lockdown.ps1 to confirm, then test from a VNet-linked Copilot Studio agent."
