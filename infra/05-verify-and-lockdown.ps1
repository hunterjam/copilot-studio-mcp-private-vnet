<#
  05-verify-and-lockdown.ps1  —  Prove the endpoint is private-only.

  The internal Container Apps environment has no public IP, so the app FQDN should NOT resolve or
  connect from the public internet. A SUCCESS here (failure to reach it publicly) is the negative
  control: combined with a successful call from a VNet-linked Copilot Studio agent, it proves the
  agent's traffic traversed the delegated Power Platform subnet.

  Run after: . .\infra\00-variables.ps1  (and after 04-container-app.ps1)
#>

az account set --subscription $SubscriptionId
$fqdn = az containerapp show -g $ResourceGroup -n $AppName --query "properties.configuration.ingress.fqdn" -o tsv
Write-Host "Testing PUBLIC reachability of: https://$fqdn/mcp"
Write-Host ""

Write-Host "== public DNS resolution (expected: FAILS / does not exist) =="
try { Resolve-DnsName $fqdn -ErrorAction Stop | Select-Object Name, Type, IPAddress | Format-Table -Auto }
catch { Write-Host "  DNS resolution failed (EXPECTED): $($_.Exception.Message)" }

Write-Host "== public HTTPS reachability (expected: FAILS / unreachable) =="
$py = @"
import urllib.request, socket, datetime
socket.setdefaulttimeout(15)
print('  UTC now:', datetime.datetime.now(datetime.timezone.utc).isoformat())
try:
    urllib.request.urlopen('https://$fqdn/mcp'); print('  PUBLIC: REACHABLE (UNEXPECTED - endpoint is not private!)')
except Exception as e:
    print('  PUBLIC: NOT reachable (EXPECTED):', type(e).__name__, str(e)[:140])
"@
$py | python -

Write-Host ""
Write-Host "If both checks show NOT reachable, the endpoint is private-only. Now run the agent test:"
Write-Host "  Copilot Studio (in the VNet-linked env) -> agent -> generative orchestration ON ->"
Write-Host "  add MCP tool with Server URL https://$fqdn/mcp -> ask: 'Call server_info and show the result.'"
Write-Host "  A returned marker = BINARY PROOF the call traversed the delegated Power Platform subnet."
