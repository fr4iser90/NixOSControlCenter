# NCC Assistant — product surfaces (SSOT)

English definitions for sorting UI, catalog items, and code.  
If a label conflicts with this file, **this file wins**.

## One-line map

| Surface | What it is | How it runs |
|---------|------------|-------------|
| **Workflow** | Reusable agent automation (catalog blueprint → instance) | **Once** now, or attached to **Cron** |
| **Skill** | Markdown instructions bundled into a workflow’s prompt | Never runs alone — only via a workflow |
| **Cron** | Timer / OnCalendar that starts a saved workflow instance (or playbook) | Systemd-style schedule, local time |
| **Tool** | Callable capability the agent may invoke mid-run | LLM tool-call / registry entry |
| **MCP** | External tool server (git, GitHub, …) wired into the agent | Install + enable; secrets/workspaces bind |
| **Plugin** | Desktop host feature (not an agent job) | Companion/GUI tick, e.g. Doomscroll |
| **Workspace** | Local git root (★ active scopes digests / defaults) | Registry under Settings / Companion |
| **Secret** | Named credential (token) | Bound into MCP / params — never into prompts |

There is **no Daily board**. Status briefing is the workflow **`workspace-brief`**, run once or via Cron.

---

## Naming: keep “Workflow”, drop “Template” from the product UI

| Term | Use |
|------|-----|
| **Workflow** | Product surface name (Companion ▶, GUI tab). What users sort and launch. |
| **Template** (internal) | Packaged catalog JSON under `templates/agents/*.json` — the *blueprint*. Prefer not in toolbar labels. |
| **Instance** | User-saved copy of a workflow (params, optional prompt override, optional Cron). |

**Recommendation:** UI label = **Workflows** (not “Workflow templates”).  
Internally, code may still say `agent_templates` / `TemplateConfigureDialog`; that is implementation jargon.

“Template” stays only where it means *catalog blueprint vs instance*, not as a second product system next to Workflows.

---

## Workflow

**Definition:** A packaged agent job: goal text + optional skill file + params + profile + MCP needs + dry-run / max-steps.

**Lifecycle**

1. **Catalog** — builtin JSON (`templates/agents/<id>.json`) + optional `prompts/skills/<name>.md`.
2. **Configure** — fill params, see transparent prompt (rendered goal + skill), optionally edit prompt.
3. **Run once** — execute with current params/prompt (edit is ephemeral unless saved).
4. **Save instance** — persist params / provider / optional **prompt override**.
5. **Cron** — optional: enable schedule on that instance (frequency from Check frequency / Cron tab).

**Transparency:** Configure dialog shows Profile, MCP, Secrets, dryRun, maxSteps, harness, skill path, and tabs:

- **Rendered prompt** (editable — what the agent gets)
- **Goal template** (read-only catalog)
- **Skill script** (read-only catalog)

Catalog skill/goal files are **never** rewritten by the UI. Overrides live on the **instance**.

**Examples:** `workspace-brief`, `autonomous-agent-run`, `privacy-policy-creator`, `github-code-review`.

**Not a workflow:** Doomscroll, raw LLM chat, a single MCP server, a CLI helper by itself.

---

## Skill

**Definition:** Instruction markdown (`prompts/skills/*.md`) referenced by a workflow’s `"skill"` field. Composed into the agent prompt as “Skill instructions: …”.

| Skills are | Skills are not |
|------------|----------------|
| Part of a workflow’s prompt | A Companion toolbar tab |
| Versioned with the module | Schedulable alone |
| Readable in the workflow dialog | Feature plugins |

Repo-root `.agents/skills/` (NCC coding agents) is a **different** layer for human/CI coding agents — not the Companion workflow skill files, though the ideas are similar.

---

## Cron

**Definition:** Recurring (or one-shot calendar) triggers that start a **saved** workflow instance / playbook. UI tab: **Cron**. Companion: clock icon.

| Cron owns | Cron does not own |
|-----------|-------------------|
| OnCalendar / daily-at / weekly / cron fields | The agent prompt text |
| Enable / last-run style schedule records | Workspace ★ selection |
| Binding schedule → playbook / instance | Desktop plugins |

**Briefing:** schedule `workspace-brief` under Cron — do **not** invent a Morning/Daily plugin for that.

Frequency pickers also appear inside a workflow’s Check frequency param; enabling “recurring schedule” writes a user Cron entry for that instance.

---

## Tool

**Definition:** A named function the running agent can call (NCC registry / AI pack tools). Examples: config readers, focus status, workflow CLI wrappers exposed as tools.

| Tools | Workflows |
|-------|-----------|
| Fine-grained capabilities mid-run | Whole jobs with a goal + skill |
| Listed under **Tools** (enable/disable) | Listed under **Workflows** |
| Usually no schedule of their own | Once or Cron |

If something is “a button that runs a multi-step agent goal”, it is a **workflow**, not a tool.

---

## MCP

**Definition:** Model Context Protocol servers that expand the agent’s tool surface (e.g. `git`, `github`). Installed from catalog, bound to workspace and/or secret.

MCP is infrastructure for workflows and chat — not a workflow and not a plugin.

---

## Plugin

**Definition:** Optional **desktop** behavior hosted by Companion/GUI (FeaturePlugin). Runs on a tick / session policy. Today: **Doomscroll** (focus / net-block).

| Plugins | Workflows |
|---------|-----------|
| Host/OS UX | LLM agent jobs |
| No goal/skill prompt | Full transparent prompt |
| Configure under Plugins | Configure under Workflows |

**Morning Brief is not a plugin.** Use workflow `workspace-brief` + Cron.

---

## Workspace · Secret · Chat · Agent job

- **Workspace** — registered git root; ★ active workspace scopes digests and default repo params.
- **Secret** — named credential in `secrets.json`; referenced by id, never pasted into prompts.
- **Chat** — interactive multi-turn with tools; not a saved workflow (unless you promote a goal into one).
- **Agent / Jobs** — runtime execution / history of agent runs (including workflow runs).

---

## CLI: `ncc ai workflow *` vs Workflow catalog

| `ncc ai workflow audit\|plan\|task-start\|…` | Workflow catalog UI |
|---------------------------------------------|---------------------|
| Imperative **helpers** for the autonomous gap/PR loop | Launch packaged workflows |
| Operate on Daily-task JSON / gaps for ★ workspace | Create instances + Cron |
| Used *inside* workflows like `autonomous-agent-run` | User-facing surface |

Same English word “workflow” in the CLI verb; product surface for the catalog is still **Workflows**.

---

## How a scheduled brief runs (example)

```text
Cron (08:30 daily)
  → saved instance of workflow "workspace-brief"
      → resolve_goal(catalog render | instance prompt override)
          → agent + MCP (git/github) + tools
              → digest for ★ / selected workspaces
```

---

## Sorting checklist

When you add or rename something, pick **one** bucket:

1. **Multi-step agent goal + skill/params?** → **Workflow** (catalog JSON + optional skill md).
2. **Markdown instructions only for that workflow?** → **Skill** (file under `prompts/skills/`).
3. **Timer that starts a saved job?** → **Cron**.
4. **Single callable mid-run?** → **Tool**.
5. **External tool server?** → **MCP**.
6. **Desktop host behavior without an agent goal?** → **Plugin**.
7. **Git root / token?** → **Workspace** / **Secret**.

If you need two buckets, you probably split the design wrong (e.g. brief must not be Plugin + Workflow).

---

## UI surfaces (Companion / GUI)

| UI | Surface |
|----|---------|
| ▶ Workflows | Workflow catalog + configure / run once |
| ⏰ Cron | Schedules |
| 🧩 Plugins | Feature plugins only |
| 🔧 Tools | Registry tools enablement |
| 🔌 MCP | Install / toggle servers |
| 📁 Workspaces | Git roots + ★ active |
| Chat / Agent / Jobs | Interactive run + history |
| Settings | LLM, capacity, workspaces, secrets — not Daily |

---

## Companion shell UX (what opens where)

**Pattern (OpenHands / Cursor / Qwen Code):** left rail navigates; main pane is content. No tutorial footers in the chrome.

```
┌────┬──────────────────────────────────────┐
│ 💬 │  NCC  Workspace[…] Harness[Auto]     │  Home
│ ── │         [ Avatar 160×160 ]           │
│ ▶  │  Session ▾          Rename    New    │  Work
│ ⏰ │  ┌ activity / thinking / tools ┐     │
│ ☰  │  │  transcript                 │     │
│ ── │  │  Message…            Send   │     │
│ 🔧 │  └─────────────────────────────┘     │  Caps
│ 🔌 │                                      │
│ 🧩 │                                      │
│ ── │                                      │
│ 📁 │                                      │  Context
│ ⏱ │                                      │
│ ── │                                      │
│ ⚙  │                                      │  System
│    │                                      │
│ UI │                                      │  Window
│ ×  │                                      │
└────┴──────────────────────────────────────┘
```

### Sidebar icons (grouped top→bottom)

| Group | Icon | Opens in main | Submenu? |
|-------|------|----------------|----------|
| **Home** | 💬 Chat | Chat pane | **No** |
| **Work** | ▶ Workflows | Workflow list | **No** |
| | ⏰ Cron | Schedule list | **No** |
| | ☰ Jobs | Agent jobs | **No** |
| **Caps** | 🔧 Tools | Tool list | **No** |
| | 🔌 MCP | MCP list | **No** |
| | 🧩 Plugins | Plugin list | **No** |
| **Context** | 📁 Workspaces | Workspace list | **No** |
| | ⏱ History | Past sessions | **No** |
| **System** | ⚙ Settings | Presence / theme / skin / inject | **No** |
| **Window** | UI · × | Full AI / Quit | **No** |

Thin rules separate groups. **No sidebar QMenu / overflow.** Session switcher is the only menu (session row).

**Session row** (under avatar): `[Session ▾]` · `Rename` · `New` — one toolbar, same height.

### What belongs where

| Zone | Contents | Not here |
|------|----------|----------|
| **Header** | Product name `NCC`; status only if unusual (`Paused`, `Autonomous`, `N busy`, idle armed); workspace + harness chips | Raw enum `available`; how-to tips |
| **Avatar** | 160×160 under header (drag to move) | Icon rail |
| **Session row** | `[Session ▾]` · `Rename` · `New` (same height) | Surface navigation; tiny misplaced icons |
| **Sidebar** | Grouped rail: Home (Chat) → Work (Workflows/Cron/Jobs) → Caps (Tools/MCP/Plugins) → Context (Workspaces/History) → System (Settings) → Window (UI/Quit) | Random icon dump; QMenus |
| **Chat pane** | Activity line; **thinking** block (collapsible); **tool traces** (name/args/result); transcript; composer | Catalog lists; cron tables |
| **Surface pane** | Short title (`Workflows`, `Cron`, …) + actionable list | “Tap to…” instructions |
| **Dialogs** | Workflow configure (prompt transparency); cron inspect/delete | — |
| **Footer** | Resize grip only | “Sidebar = navigate…” tutorials |

### Chat stream (harness-style, like Qwen / DeepSeek)

During a run the main pane shows, top→bottom:

1. **Activity** — short phase (`Thinking…`, `Template … · qwen`).
2. **Thinking** — model reasoning (`ThinkingBlock`, collapsible).
3. **Tool traces** — each call as a compact card (name, args, result) — same idea as Qwen Code / OpenHands tool panels.
4. **Transcript** — assistant reply text in the bubble.
5. **Composer** — next user message.

Skills / prompt injections are **not** dumped as chrome tips. They appear inside the **workflow configure** dialog (Rendered prompt / Skill tabs) before Run, and as part of the agent goal once a workflow/template run starts.

### Rules (uniform)

| Click | Opens | Never |
|-------|--------|--------|
| Sidebar **Chat** | Main chat | — |
| Sidebar **surface** | List in main pane | Full AI window |
| Same surface again | Back to chat | — |
| **← Back to chat** | Chat | — |
| Workflow row | Configure dialog (prompt / Run once / OK) | Session picker |
| Cron row | Detail dialog; **Delete** if user | Full UI |
| Plugin / Tool / MCP row | Toggle / configure here | Unrelated jump |
| Workspace row | Set ★ active → chat | — |
| History row | Load session into slot | — |
| **UI** | Full AI window (opt-in) | Default for every tap |

---

## Related paths

| Path | Role |
|------|------|
| `python/ncc_assistant/templates/agents/*.json` | Workflow catalog (blueprints) |
| `prompts/skills/*.md` | Skill scripts |
| `~/.config/ncc-assistant/` instances / schedules | User instances + Cron |
| `python/ncc_assistant/plugins/` | Feature plugins |
| `doc/usage.md` | Human how-to |
| `doc/roadmap.md` | Phased plans |

Human entry: [usage.md](./usage.md). Module stub: [../README.md](../README.md).
