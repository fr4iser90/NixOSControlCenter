# Phase 32 — Companion shell UX (sessions · workspaces · tools · MCP · templates)

Status: **guidelines (SSOT) — next after 31**  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** [31-agent-trace-ux](./31-agent-trace-ux.md), [29-desktop-companion-avatar](./29-desktop-companion-avatar.md), [28-agent-templates-mcp-secrets](./28-agent-templates-mcp-secrets.md)

## Problem (from live Companion)

Current chrome is a **dense text-button strip** (`Hist` / `Skill` / `Cron` / `Jobs` + `+` / `UI` / pause / play / `×`) plus a **horizontal chat-tab row** (`Chat 1`, `hi`). That does not scale, looks empty/broken when theme icons are missing, and hides the real power surfaces (tools, MCP, workspaces, real template runs).

Phase 31 fixed **trace density** (thinking/tools). This phase fixes **shell IA**.

## How others do it (patterns to copy)

| Product | Session switch | Project/workspace | Tools / MCP | Workflows |
|---------|----------------|-------------------|-------------|-----------|
| Cursor | History icon → list; rename in place | Folder = project; chats scoped | Tools in agent stream; MCP in settings | Composer / rules, not a separate “template dump” |
| Claude Desktop / web | Sidebar or picker | Projects (optional) | Artifacts / tools collapsed | Projects + custom instructions |
| ChatGPT | History drawer | Custom GPTs / projects | Tools in message | GPTs |
| Qwen / DSH web | Session list in chrome | CWD / project implicit | Tool cards in stream | Headless runs still stream into UI |

**Takeaway for NCC Companion (narrow overlay):** never grow a permanent tab strip. One **active chat title** + **icon → popover list**. Power features live behind **icons** that open the same compact list panel we already have (or a small popover). Full settings stay in `ncc ai gui`.

## Gap analysis (today → needed)

| Area | Today | Needed |
|------|-------|--------|
| Sessions | Horizontal tabs, auto-title from first message | **Icon** → dropdown/list: switch, new, rename, delete, busy badge |
| Resize | Fixed-ish window; only `pos` in QSettings | **Resize grip**; persist `size` + `pos` |
| Templates | Skill panel seeds composer text (“Run template…”) | **Run in active chat** via `run_instance` / harness; stream into ThinkingBlock + tools + answer |
| Tools | No Companion surface | **Icon** → registry list (enable/disable soft; detail → full UI) |
| MCP | No Companion surface | **Icon** → servers list; toggle enable; add opens dialog or full UI |
| Workspaces | Only in full Settings | **Icon** → add/list; **active workspace** scopes new chats + template cwd |
| Chats × workspaces | Flat global slots | **Group in session dropdown** by workspace (see decision below) |
| Toolbar | Text labels, easy to look “blank” | Theme icons + short tooltips; max ~6 primary actions |
| Git outcomes | Buried in tool rows | Template/agent turns already show tools; ensure commit/push appear as tool rows with clear names (no special case required if adapters emit `tool`) |

## Locked decisions

1. **Session UI:** Replace tab strip with **current-title chip** + **Sessions icon** opening a list (QMenu or panel). Double-click / context menu → **rename**. Busy = `✦` on row.  
2. **Workspace scoping:** Session dropdown is **grouped by workspace** (`Workspace › chats`, plus “No workspace”). Active workspace is a chip next to harness; new chats inherit it. *Not* a second nested tab system — grouping only in the picker.  
3. **Templates:** Icon (or keep under Skills) → pick template → param dialog if needed → **run into current slot** with same Phase-31 trace widgets. Do not only paste a sentence into the composer.  
4. **Resize:** `setMinimumSize` + user resize; save `geometry` (or size+pos) in companion QSettings.  
5. **MCP / Tools / Workspace icons:** primary toolbar; Cron/Jobs stay secondary (overflow or keep one “More” menu).  
6. **Full UI button stays** for deep settings; Companion never becomes a second Settings app.

## Target chrome (compact)

```text
┌ avatar ─────────────────────────────┐
│ NCC   [ws ▾]  [harness auto → qwen] │
│ [▾ Chat title ✦]     ← sessions icon│
│ [💬][🔧][🔌][📁][▶tmpl][⋯][UI][×]   │
│ activity…                            │
│ ▸ Thinking · …                       │
│ ▸ tool rows…                         │
│ answer                               │
│ [message……………][Send]                │
└─────────────────────────────────────┘
```

Icons (theme with text fallback): sessions, tools, MCP, workspace, templates, more (cron/jobs/presence).

## Implementation slices

| Slice | Deliverable |
|-------|-------------|
| **A** | Sessions icon + list; rename; drop tab strip; persist titles on slots |
| **B** | Window resize + persist geometry |
| **C** | Active workspace chip + group sessions in picker; add workspace from icon |
| **D** | Template run-in-chat (stream events, not composer seed) |
| **E** | Tools + MCP panels (list/toggle; add → dialog or full UI) |
| **F** | Toolbar icon pass + overflow “More”; docs/roadmap |

## Acceptance

- [ ] No horizontal multi-tab row; session switch via icon list  
- [ ] Rename session persists for companion lifetime (+ optional disk later)  
- [ ] Resize companion; reopen restores size/position  
- [ ] Session list grouped by workspace; active ws on new chat  
- [ ] Template run shows thinking/tools/answer in Companion  
- [ ] Tools / MCP / Workspace reachable without opening full GUI first  
- [ ] Gates green

## Non-goals

- Live2D / VTuber  
- Full MCP marketplace inside Companion  
- Replacing `ncc ai gui` Templates/Settings pages  

## Test plan

- AST/wiring: sessions menu, geometry keys, workspace grouping  
- Manual: rename, resize restore, run one template with qwen harness, toggle MCP row  
