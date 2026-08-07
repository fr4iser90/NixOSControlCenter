# Phase 1 — Tool registry & MCP client

Status: **done** (see ROADMAP.md)

**Status:** planned  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 0  
**Unblocks:** phase 2 (agent), phase 5 (Tools UI)

## Problem

Tools live only in `TOOL_DEFINITIONS` inside `runtime.py`. Users cannot add
local helpers or attach external MCP servers for the *assistant itself* to call.
NCC already *is* an MCP server; it is not yet an MCP **client**.

## Goals

1. Unified **tool registry** consumed by chat, agent, CLI, and MCP server export.
2. Support tool kinds: `builtin`, `shell` (allowlisted), `mcp` (client).
3. GUI **Tools** section: list, enable/disable, test invoke, add/edit MCP server.
4. Config + user-local overrides without breaking pure eval.

## Non-goals

- Arbitrary unrestricted shell (`allowShell` default false).
- Replacing FastMCP server export (keep exporting enabled tools).
- Full MCP resources/prompts UI (tools first; resources later if needed).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| T1 | Registry API: list / get / call by name | P0 |
| T2 | Load builtins from current `TOOL_DEFINITIONS` | P0 |
| T3 | Load user tools from `~/.config/ncc-assistant/tools/*.json` | P0 |
| T4 | Load MCP client servers from Nix `tools.mcpServers` + user JSON | P0 |
| T5 | MCP client: stdio (command+args+env); optional SSE later | P0 |
| T6 | Namespace MCP tools (`mcp.<server>.<tool>`) to avoid collisions | P0 |
| T7 | Enable/disable per tool or per server | P1 |
| T8 | Shell tool type: argv template + JSON schema + timeout | P1 |
| T9 | GUI Tools panel (see also phase 5) | P0 |
| T10 | `ncc ai tools` lists registry (builtins + mcp + shell) | P1 |
| T11 | Health: reconnect / fail soft if MCP server dies mid-session | P2 |

## Data shapes (draft)

User tool file example (`~/.config/ncc-assistant/tools/hello.json`):

```json
{
  "name": "hello_echo",
  "kind": "shell",
  "description": "Echo a string (demo)",
  "enabled": true,
  "command": ["echo", "{{message}}"],
  "inputSchema": {
    "type": "object",
    "properties": { "message": { "type": "string" } },
    "required": ["message"]
  },
  "timeoutSec": 15
}
```

MCP server entry (Nix or user JSON):

```json
{
  "filesystem": {
    "enable": true,
    "transport": "stdio",
    "command": "uvx",
    "args": ["mcp-server-filesystem", "/home/fr4iser/Documents"],
    "env": {}
  }
}
```

## Nix options (draft)

```nix
tools = {
  allowShell = false;           # master switch for kind=shell
  shellAllowlist = [ ];         # optional binary basename allowlist
  mcpServers = { };             # attrset of server defs
  # optional: extraBuiltinFilter = [ "apply_system" ]; # hide from agent etc.
};
```

## Runtime design notes

- `ToolRuntime` gains registry injection; `call(name, args)` resolves builtin → shell → mcp.
- MCP client process lifecycle: start on first use or session start; stop on GUI exit / idle timeout.
- Confirm hook still wraps `apply_module_config` / `apply_system` regardless of caller.
- Agent (phase 2) must see the same enabled set unless a job overrides allowlist.

## UI requirements (Tools)

- Table/list: name, source (builtin/mcp/shell), enabled, description.
- Actions: Enable, Disable, Test (JSON args dialog), Remove (user tools only).
- “Add MCP server” form: name, command, args, env, enable.
- Show connection errors inline (not only journal).

## Acceptance criteria

- [ ] Chat can call an MCP tool from a configured stdio server.
- [ ] Disabled tools never appear in LLM tool list.
- [ ] Shell tools refuse to run when `allowShell = false`.
- [ ] `ncc ai mcp` still serves at least builtins (ideally enabled registry subset).
- [ ] Tools panel can add a user MCP server without rebuild (user JSON).

## Test plan

- Unit: registry merge order (Nix < user override).
- Integration: mock MCP stdio server returning one tool; chat/agent invocation.
- Negative: collision names, dead server, shell blocked.
