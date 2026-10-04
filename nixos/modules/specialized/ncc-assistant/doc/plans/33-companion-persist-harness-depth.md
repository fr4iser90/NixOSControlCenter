# Phase 33 — Companion persist · workspace switch · harness depth · avatar skins

Status: **implemented (v1)**  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** [32-companion-shell-ux](./32-companion-shell-ux.md), [30-swappable-coding-harness](./30-swappable-coding-harness.md)

## Scope

1. Persist companion chats (id, title, workspace, transcript, harness) to disk; rename survives restart  
2. Switch workspace on an existing chat mid-session  
3. Template required-params dialog in Companion (not only Full UI)  
4. Full MCP catalog install / remove / toggle in Companion  
5. Auto-inject NCC MCP into `~/.qwen/settings.json` (and dsh tip/config when available)  
6. Multi-turn: keep per-slot history; fold into harness prompts  
7. Emit real `run_spawn` from harness mappers when Task/subagent tools appear  
8. Pluggable avatar skins (image / sprite folder; Live2D-export PNG sequence hook)

## Non-goals (still)

- Full Cubism Live2D SDK runtime (use exported PNG/WebP frames until packaged)  
- True ACP bidirectional SDK (prompt-history multi-turn is the v1 bridge)
