# Azure Portal walkthrough (GUI) — internal Container Apps hosting

Click‑path version of the scripted Azure build, for when you want to do it in **portal.azure.com**
or explain it to a customer's Azure admin. Mirrors `infra/02`–`05`.

> Prereqs: an Azure subscription in the **same Entra tenant** as Power Platform; **Network
> Contributor + Owner/Contributor**; a Power Platform Admin to link the policy. US geography needs
> **two** VNets (eastus + westus). Most Power Platform geographies (US, Europe, UK, **Sweden**, …) are
> two‑region and need two VNets; only a geography that maps to a **single Azure region** needs one.
> Confirm yours with `Get-EnvironmentRegion` before assuming.

## 1. Resource providers
**Subscriptions → (your sub) → Settings → Resource providers** → register: `Microsoft.Network`,
`Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.OperationalInsights`, `Microsoft.PowerPlatform`.

## 2. Container registry + image
- **Container registries → Create** → Basic, admin user enabled.
- Build the image: easiest is `az acr build -r <acr> -t mcp-vnet-echo:v1 ./server` (ACR Tasks, no local Docker).

## 3. Virtual networks + subnets
- **Virtual networks → Create** → `vnet-mcp-a` in **East US**, address space `10.10.0.0/16`.
  - Subnet `snet-powerplatform` `10.10.1.0/24` → after creation, **Subnets → snet-powerplatform →
    Subnet delegation → `Microsoft.PowerPlatform/enterprisePolicies`**.
  - Subnet `snet-aca` `10.10.4.0/23` → **delegate to `Microsoft.App/environments`**.
- **Virtual networks → Create** → `vnet-mcp-b` in **West US**, `10.20.0.0/16`, subnet
  `snet-powerplatform` `10.20.1.0/24` delegated to `Microsoft.PowerPlatform/enterprisePolicies`.
- **Peer them:** vnet‑mcp‑a → **Peerings → Add** → remote = vnet‑mcp‑b (allow access both ways).

## 4. Enterprise policy (custom template — no dedicated blade)
- **Deploy a custom template → Build your own template in the editor** → load `infra/enterprise-policy.json` → **Save**.
- Parameters: **policyName** `ep-mcp-vnet`; **powerplatformEnvironmentRegion** = the Power Platform
  geography token (e.g. `unitedstates` — *not* an Azure region); **vNetOneSubnetName** `snet-powerplatform`;
  **vNetOneResourceId** = the **VNet‑level** resource ID of `vnet-mcp-a` (no `/subnets/...`); **vNetTwo\***
  = the same for `vnet-mcp-b`. (Leave VnetTwo blank **only** if your geography maps to a single Azure
  region — most, including Sweden/Europe/UK/US, are two‑region.)
- **Review + create.**

## 5. Internal Container Apps environment + app
- **Container Apps → Create** → **Networking**: use your own VNet, **infrastructure subnet** = `snet-aca`,
  **Internal** = **Enabled** (this makes the env private‑only, with a private static IP in `snet-aca`).
- Create the container app from the ACR image, **target port 8000**. On an internal env, set ingress to
  **“Accepting traffic from anywhere”** (external) — on an internal env this publishes on the env's
  *internal* endpoint with a clean FQDN + managed TLS. Set **min replicas = 1** to avoid cold starts.
- Note the app **FQDN** and the environment's **static IP** (a `10.10.4.x` private address).

## 6. Private DNS
- **Private DNS zones → Create** → name = the ACA env **default domain**
  (e.g. `<random>.eastus.azurecontainerapps.io`).
- Add a record set: name `*`, type **A**, IP = the env's **private static IP**.
- **Virtual network links → Add** → link to **both** `vnet-mcp-a` and `vnet-mcp-b` (auto‑registration off).

## 7. Verify private‑only
From your machine (public internet), the app FQDN must **fail** to resolve/connect. That's the negative
control — combined with a successful call from a VNet‑linked Copilot Studio agent, it proves the private path.

## Portal ↔ script map

| Portal step | Script |
| --- | --- |
| 1 Providers, 2 ACR+image | `01-registry-and-image.ps1` |
| 3 VNets/subnets/peering | `02-network.ps1` |
| 4 Enterprise policy | `03-enterprise-policy.ps1` (+ `enterprise-policy.json`) |
| 5 ACA env + app, 6 Private DNS | `04-container-app.ps1` |
| 7 Verify | `05-verify-and-lockdown.ps1` |
