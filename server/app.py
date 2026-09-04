"""
Minimal Streamable-HTTP MCP server for the Copilot Studio + Power Platform VNet test.

Purpose
-------
Prove whether a Microsoft Copilot Studio agent can call a PRIVATE MCP endpoint (hosted in
Azure with no public network path) over a delegated Power Platform VNet subnet.

Tools exposed:
  - echo(message):  returns the message -> confirms the agent reached this server.
  - server_info():  returns a unique deploy marker + host + UTC timestamp. If a Copilot
                    Studio agent can read this while the endpoint has NO public path, the
                    request must have traversed the delegated Power Platform subnet.

Transport
---------
Copilot Studio supports the *Streamable HTTP* MCP transport only (SSE was retired after
Aug 2025). The server exposes the Streamable HTTP endpoint at path /mcp.

  -> Copilot Studio "Server URL":  https://<host>/mcp

Run locally:
  pip install -r requirements.txt
  python app.py                      # http://localhost:8000/mcp

Run under a container / uvicorn:
  python -m uvicorn app:app --host 0.0.0.0 --port 8000

Verified against the MCP Python SDK 2.x (the ergonomic server class is MCPServer;
it was named FastMCP in the 1.x SDK).
"""
import os
import socket
import datetime

from mcp.server.mcpserver import MCPServer
from mcp.server.transport_security import TransportSecuritySettings

DEPLOY_MARKER = os.environ.get("DEPLOY_MARKER", "mcp-vnet-test")

server = MCPServer(name="mcp-vnet-echo")


@server.tool()
def echo(message: str) -> str:
    """Echo the supplied message back. Use to confirm connectivity to this private MCP server."""
    return f"ECHO: {message}"


@server.tool()
def server_info() -> str:
    """Return a unique marker proving THIS private MCP server handled the call."""
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()
    return (
        f"Reached PRIVATE MCP server marker='{DEPLOY_MARKER}' host='{socket.gethostname()}' utc='{now}'. "
        f"If a Copilot Studio agent returned this while the endpoint has NO public network path, the "
        f"request traversed the delegated Power Platform VNet subnet."
    )


# ASGI app for uvicorn / container hosting. Serves the MCP Streamable HTTP endpoint at /mcp.
#   - stateless_http=True  -> each call self-contained (simplest for a connectivity probe)
#   - json_response=True   -> plain JSON responses (most compatible with the CS MCP client)
#   - DNS-rebinding protection off -> don't reject the platform-assigned Host header
app = server.streamable_http_app(
    stateless_http=True,
    json_response=True,
    host="0.0.0.0",
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
