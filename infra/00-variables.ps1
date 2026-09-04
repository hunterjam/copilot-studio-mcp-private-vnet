<#
  00-variables.ps1  —  EDIT THIS FIRST, then dot-source it before each step:
      . .\00-variables.ps1

  These variables drive every other script. Names that must be globally unique are flagged.
  Defaults target the US Power Platform geography (unitedstates), which requires TWO paired
  Azure regions (eastus + westus) and therefore two VNets. See README for single-region geos.
#>

# ---- Identity (REQUIRED) ----------------------------------------------------
$Global:SubscriptionId = "<YOUR_SUBSCRIPTION_ID>"      # Azure sub in the SAME Entra tenant as Power Platform
$Global:TenantId       = "<YOUR_TENANT_ID>"            # for `az login --tenant`
$Global:EnvironmentId  = "<POWER_PLATFORM_ENVIRONMENT_ID>"  # PPAC -> Environments -> (env) -> Environment ID

# ---- Power Platform geography -> Azure region pair --------------------------
# unitedstates = eastus + westus (two VNets). For single-region geos (e.g. sweden), see README.
$Global:PpGeo   = "unitedstates"
$Global:RegionA = "eastus"
$Global:RegionB = "westus"

# ---- Resource group ---------------------------------------------------------
$Global:ResourceGroup = "rg-mcp-vnet-test"

# ---- Networking -------------------------------------------------------------
$Global:VnetAName   = "vnet-mcp-a"          # in RegionA
$Global:VnetBName   = "vnet-mcp-b"          # in RegionB
$Global:VnetAPrefix = "10.10.0.0/16"
$Global:VnetBPrefix = "10.20.0.0/16"
$Global:PpSubnet    = "snet-powerplatform"  # delegated to Microsoft.PowerPlatform/enterprisePolicies (both VNets)
$Global:PpSubnetAPrefix = "10.10.1.0/24"
$Global:PpSubnetBPrefix = "10.20.1.0/24"
$Global:AcaSubnet   = "snet-aca"            # delegated to Microsoft.App/environments (in VNet A)
$Global:AcaSubnetPrefix = "10.10.4.0/23"    # ACA workload-profile infra subnet (min /27; /23 is safe)

# ---- Container registry + image (ACR name MUST be globally unique) -----------
$Global:AcrName   = "mcpvnetacr<UNIQUE>"    # 5-50 lowercase alphanumerics, globally unique
$Global:ImageName = "mcp-vnet-echo:v1"

# ---- Container Apps + policy ------------------------------------------------
$Global:AcaEnvName = "cae-mcp-vnet"
$Global:AppName    = "ca-mcp-vnet"
$Global:PolicyName = "ep-mcp-vnet"
$Global:DeployMarker = "mcp-vnet-$(Get-Date -Format yyyyMMdd-HHmm)"

# UTF-8 console so `az acr build` log streaming doesn't crash on Windows (cp1252).
$env:PYTHONIOENCODING = "utf-8"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host "Variables loaded. Subscription=$SubscriptionId  RG=$ResourceGroup  Geo=$PpGeo ($RegionA + $RegionB)"
