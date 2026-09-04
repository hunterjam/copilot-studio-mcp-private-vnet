# Power Platform + Copilot Studio walkthrough (the maker/admin experience)

What linking the VNet and wiring the MCP tool looks like from inside Power Platform. The platform
side is deliberately thin: Power Platform **consumes** the Azure enterprise policy — it does not build
the network.

## Part 1 — Prepare the environment (PPAC)

1. **Managed Environment (required).** admin.powerplatform.microsoft.com → **Manage → Environments** →
   select the environment → **Enable Managed Environments**. VNet support only works on Managed
   Environments. (Supported types: Production, Default, Sandbox, Developer. Not Trial / Dataverse‑for‑Teams.)
2. **Region.** Note the environment's region (Manage → Environments → detail). The Azure VNets must be in
   the paired region(s): US → eastus + westus. This drives one‑VNet vs. two‑VNet topology.

## Part 2 — Link the enterprise policy (PPAC)

This is the core Power Platform action — it joins the environment to the Azure subnet delegation.

1. **Security** (left nav) → **Data and privacy** → **Azure Virtual Network policies**.
2. Select the **environment** → select the **enterprise policy** (created in Azure) → **Save**.
3. **Validate:** Manage → Environments → (env) → **History → Status = Succeeded**.

> You can *link* in the UI but can only *unlink* via PowerShell `Disable-SubnetInjection`. Enabling
> injection causes **~30 min** of environment instability while containers initialize.

## Part 3 — Wire the MCP tool (Copilot Studio)

Once linked, authoring is unchanged — the private routing happens invisibly at runtime.

1. copilotstudio.microsoft.com → select the **VNet‑linked environment** → create/open an **agent**
   (standard harness). *(Requires a Copilot Studio license + maker access; if blocked, assign the
   Copilot Studio license and the **Environment Maker** role.)*
2. **Settings → generative orchestration → ON** (required for MCP tools to be invoked).
3. **Tools → Add a tool → New tool → Model Context Protocol.**
4. **Server name/description**, **Server URL** = the private MCP URL (`https://<app>.<domain>/mcp`),
   **Auth** = None (for the test) → **Create**.
5. Confirm `echo` and `server_info` enumerate, add the tool to the agent.

## Part 4 — Test

In the **Test** pane: **“Call server_info and show the result.”** A returned marker while the endpoint
has no public path = proof the traffic traversed the delegated subnet.

**What you'll observe about routing:** the maker UI gives **no per‑call “this went over the VNet”
indicator** — success/failure *is* the signal. That's exactly why the rig makes the endpoint private‑only:
a successful call can only mean the delegated subnet was used.

## One‑breath summary

> Make the environment Managed, link it to the Azure enterprise policy under **Security → Data and
> privacy → Azure Virtual Network policies**, validate **History → Succeeded**, then in Copilot Studio
> turn on generative orchestration and add the MCP server by its **private** URL. Power Platform injects
> a runtime container into the delegated subnet; the agent reaches the private endpoint over the VNet.

## Troubleshooting

- **Agent hallucinates a toolset / “no server_info tool.”** The MCP tool isn't attached to *this* agent,
  or generative orchestration is off. Attach the tool + enable generative orchestration + re‑test.
- **Tool call errors 5xx then succeeds on retry.** Container cold start — set min‑replicas ≥ 1.
- **“User license not found” / can't create agents.** Assign a Copilot Studio license and the
  Environment Maker role to the maker.
