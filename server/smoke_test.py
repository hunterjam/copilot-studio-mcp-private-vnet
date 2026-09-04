"""
Local MCP handshake check. Point it at a running server and it performs the full MCP
initialize -> tools/list -> tools/call(server_info) sequence over Streamable HTTP.

Usage:
  python smoke_test.py                                  # defaults to http://127.0.0.1:8000/mcp
  python smoke_test.py https://<host>/mcp               # test a remote endpoint
"""
import sys
import json
import urllib.request

URL = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000/mcp"
HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
}


def post(payload, session=None):
    h = dict(HEADERS)
    if session:
        h["Mcp-Session-Id"] = session
    req = urllib.request.Request(URL, data=json.dumps(payload).encode(), headers=h, method="POST")
    resp = urllib.request.urlopen(req, timeout=30)
    sid = resp.headers.get("Mcp-Session-Id")
    body = resp.read().decode()
    # Streamable HTTP may return SSE framing; extract the JSON data line if so.
    if body.lstrip().startswith("event:") or "data:" in body[:64]:
        for line in body.splitlines():
            if line.startswith("data:"):
                body = line[5:].strip()
                break
    return sid, json.loads(body)


def main():
    init = {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "smoke", "version": "0.0.1"},
        },
    }
    sid, r = post(init)
    print("initialize ->", r.get("result", {}).get("serverInfo"))

    try:
        post({"jsonrpc": "2.0", "method": "notifications/initialized"}, session=sid)
    except Exception:
        pass

    _, r = post({"jsonrpc": "2.0", "id": 2, "method": "tools/list"}, session=sid)
    tools = [t["name"] for t in r.get("result", {}).get("tools", [])]
    print("tools/list ->", tools)

    _, r = post({
        "jsonrpc": "2.0", "id": 3, "method": "tools/call",
        "params": {"name": "server_info", "arguments": {}},
    }, session=sid)
    content = r.get("result", {}).get("content", [])
    text = content[0].get("text") if content else r
    print("tools/call server_info ->", text)
    print("\nSMOKE TEST PASSED" if tools and "server_info" in tools else "\nSMOKE TEST FAILED")


if __name__ == "__main__":
    main()
