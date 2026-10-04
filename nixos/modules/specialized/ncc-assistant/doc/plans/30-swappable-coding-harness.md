# Phase 30 — Swappable coding harness (native / Qwen / DeepSeek)

Status: **implemented (v1 adapters)**  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** companion (29), MCP server, agent templates

## Goal

Keep NCC-owned NixOS tools, cron/schedules, secrets, presence, and GUI/companion —
delegate **coding agent loops** (git review, AGENTS.md, skills maintainers, …) to an
external harness when enabled, with a stable event contract so the UI can show
**thinking**, **tool calls**, and **streamed replies**.

## Backends

| Name | Role |
|------|------|
| `native` | `ChatSession` / `AgentRunner` + `ToolRuntime` (default) |
| `qwen` | `qwen -p … --output-format stream-json` (must be on PATH) |
| `dsh` | `dsh --profile headless "…"` or `npx @deepseek-ai/dsh` |

## Config

```nix
# systemConfig / template-config
agent.harness = "native";       # default chat/agent
agent.codingHarness = "auto";   # coding/git tags → qwen|dsh if installed
```

Env (set by package wrapper): `NCC_ASSISTANT_HARNESS`, `NCC_ASSISTANT_CODING_HARNESS`.  
Companion override: `NCC_ASSISTANT_COMPANION_HARNESS`.  
Bins: `NCC_ASSISTANT_QWEN_BIN`, `NCC_ASSISTANT_DSH_BIN`.

## CLI

```bash
ncc ai harness status
ncc ai harness probe qwen
ncc ai agent run --harness qwen --goal "review this repo"
ncc ai companion   # coding-like prompts auto-route when codingHarness≠native
```

## Installing Qwen on guarded / tmpfs hosts

Global `npm i -g` may be blocked by a secure npm wrapper
(`NPM_SECURITY_ALLOW_GLOBAL=1` after `export`). Even then, `@qwen-code/qwen-code`
is huge (Electron / DevTools via dotslash) and often fills **tmpfs `/tmp`**
(= RAM) → `No space left on device` and OOM.

Prefer Nix custom examples (rename without `example_` prefix):

- `nixos/custom/example_qwen_code_harness.nix` — nixpkgs `qwen-code` + disk TMPDIR
- `nixos/custom/example_deepseek_harness.nix` — `dsh` (nixpkgs when available, else npx)
- `nixos/custom/example_coding_harness.nix` — both with toggles

Or manual:

```bash
# Official standalone (home prefix, not npm -g)
curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh | bash

# Or npm with disk-backed TMPDIR
mkdir -p "$HOME/tmp"
export TMPDIR="$HOME/tmp" NPM_CONFIG_CACHE="$HOME/.npm-cache"
export NPM_SECURITY_ALLOW_GLOBAL=1
npm i -g @qwen-code/qwen-code@latest
```

## NCC tools from external harness

Register the NCC MCP server in the harness settings (Qwen MCP / dsh MCP plugin)
pointing at `ncc ai mcp` / `ncc-assistant mcp`. Mutating NixOS tools stay behind
NCC confirm/presence.

## Event contract

`thinking_delta` · `assistant_delta` · `tool` · `tool_result` · `status` · `error` · `done`

## Follow-ups

- Bidirectional ACP/SDK sessions (multi-turn) instead of one-shot headless
- Auto-inject NCC MCP into qwen/dsh on first run
- UI chrome for harness / thinking / tools / subagents → [31-agent-trace-ux](./31-agent-trace-ux.md)
- Emit `run_spawn` when harness starts a nested/subagent run (feeds phase 31 session switch)
