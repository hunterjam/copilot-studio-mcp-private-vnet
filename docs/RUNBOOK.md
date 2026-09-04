# Runbook — private MCP over Power Platform VNet (end to end)

This ties the scripted Azure build to the two Power Platform / Copilot Studio UI steps and the
result interpretation. It reflects the **Azure Container Apps (internal environment)** hosting model.

## 0. Tenant constraint (read first)

Power Platform subnet injection links an **Azure enterprise‑policy resource** to a **Power Platform
environment**; both must be in the **same Entra tenant**. A split Azure‑tenant vs. M365‑tenant setup
cannot be bridged. Run everything in one tenant that contains both.

## 1. Sign in + variables

```powershell
az login --use-device-code --tenant <YOUR_TENANT_ID>
# edit infra/00-variables.ps1: SubscriptionId, TenantId, EnvironmentId, unique AcrName, geo/regions
. .\infra\00-variables.ps1
```

## 2. Build (scripted)

| Step | Script | Result |
| --- | --- | --- |
| Providers + ACR + image | `01-registry-and-image.ps1` | `Microsoft.App/Network/PowerPlatform` registered; image in ACR |
| Two paired VNets + delegated subnets + peering | `02-network.ps1` | PP subnet delegated in both regions; ACA subnet in VNet A |
| Enterprise policy | `03-enterprise-policy.ps1` | `Microsoft.PowerPlatform/enterprisePolicies` (two‑region); prints ARM ID |
| Internal ACA env + app + private DNS | `04-container-app.ps1` | prints the **private MCP URL** |
| Verify private‑only | `05-verify-and-lockdown.ps1` | public DNS + HTTPS must **fail** |

## 3. Link the policy to the environment (UI or PowerShell)

Subnet injection must be active before an agent can reach the private endpoint.

- **PPAC UI:** admin.powerplatform.microsoft.com → **Security → Data and privacy → Azure Virtual
  Network policies** → select the environment → select the policy → **Save**.
- **PowerShell:** `Enable-SubnetInjection -EnvironmentId <id> -PolicyArmId <arm id from step 2>`
- **Validate:** Manage → Environments → (env) → **History → Succeeded**. Allow **~30 min** to settle
  (enabling/disabling injection causes temporary instability).

## 4. Create the agent + add the MCP tool (Copilot Studio)

1. copilotstudio.microsoft.com → select the **VNet‑linked environment** → create an agent.
2. **Settings → generative orchestration → ON** (required for MCP tools).
3. **Tools → Add a tool → New tool → Model Context Protocol.**
4. **Server URL** = the private URL from step 2 (`https://<app>.<domain>/mcp`), **Auth** = None → **Create**.
5. Confirm `echo` and `server_info` enumerate. (Enumerating a *private* URL here is itself evidence
   that design‑time discovery routed over the VNet.)

## 5. The test — and what it proves

In the agent's **Test** pane: **“Call server_info and show the result.”**

| Result | Verdict |
| --- | --- |
| ✅ Marker returned **and** `05-verify` shows public unreachable | **Binary proof** the call traversed the delegated subnet. |
| ❌ Connection/timeout | Injection not settled, DNS zone not linked to the env's VNet, or peering missing. |
| ❌ Tool never enumerated at step 4 | Design‑time discovery needs a public path in your config; note as a limitation. |

## 6. Negative control (optional, for airtightness)

Run the same agent from a **non‑VNet** environment (or with the policy unlinked). Expect **failure** —
this rules out the private endpoint silently allowing public traffic. In the verified run we used the
stronger control of the endpoint being **completely unresolvable** from the public internet.

## 7. Teardown

```powershell
.\infra\99-teardown.ps1
# then: Disable-SubnetInjection -EnvironmentId <id>   (or unlink in PPAC)
```

## Common gotchas

- **Private DNS zone not linked to the environment's VNet** → the app FQDN resolves publicly (fails). The
  zone must be the ACA env's default domain with a `*` A‑record → the env's private static IP, linked to
  **both** VNets.
- **App ingress on an internal env:** use `--ingress external` (publishes on the env's *internal*
  endpoint with a clean FQDN). `--ingress internal` yields an app‑to‑app `.internal.` name instead.
- **Cold start 503** on first call after idle → retry; set `--min-replicas 1`.
