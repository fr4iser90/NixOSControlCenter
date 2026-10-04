# Phase 31 — Agent trace UX (GUI + Companion)

Status: **implemented (v1)**  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** [30-swappable-coding-harness](./30-swappable-coding-harness.md), [29-desktop-companion-avatar](./29-desktop-companion-avatar.md), [25-ui-compact-traces](./25-ui-compact-traces.md)  
**Surfaces:** full Chat GUI · Companion avatar overlay · (later) Agent / Jobs detail

## Problem (today)

Harness streams work, but the UI treats everything as a flat text dump:

- Thinking + tools spam the transcript (Companion: `── thinking ──` + `[tool]` lines).
- No per-session harness control (auto-pick only; tiny label).
- Session / subagent work is not first-class — hard to switch when a child run starts.
- Full GUI has `ToolTraceWidget` + thinking bubble, but thinking is always open and not shared with Companion.

Reference bar: Qwen Code / DeepSeek Harness **web** UIs — collapsed reasoning, compact tool cards, clear run/session chrome. NCC stays Qt-native; we copy **interaction patterns**, not their CSS.

## North star

> **Answer text is primary. Everything else is a progressive-disclosure rail.**

One shared **trace model** drives both GUI and Companion. Density differs; structure does not.

---

## 1. Shared principles

| # | Rule |
|---|------|
| P1 | **Answer first** — assistant markdown is the default viewport; traces never steal the whole height. |
| P2 | **Collapsed by default** — thinking, tool args/results, status noise stay one-line until user expands. |
| P3 | **One chrome, two densities** — same widgets; Companion = compact chrome, GUI = comfortable. |
| P4 | **Session-scoped harness** — each chat owns a harness choice; auto is a mode, not a mystery. |
| P5 | **Runs are navigable** — parent turn + subagent/child runs appear as switchable sessions/tabs, not buried log lines. |
| P6 | **No raw JSON in the feed** — args/results only inside expanded panels; truncated previews on the row. |
| P7 | **Status ≠ content** — `status` / phase chatter goes to activity strip or avatar state, not the bubble. |
| P8 | **Color + icon** — status never color-only (ok / fail / running / cancelled). |
| P9 | **Persist prefs** — density, “auto-expand thinking while streaming”, last harness per slot. |
| P10 | **Same event contract** — only `thinking_delta` · `assistant_delta` · `tool` · `tool_result` · `status` · `error` · `done` (+ future `run_spawn` / `run_switch`). |

---

## 2. Information architecture

### Full GUI (Chat)

```text
┌─ chrome ────────────────────────────────────────────────────────────┐
│ Model ▾ │ Harness ▾ (auto/native/qwen/dsh) │ activity… │ Stop       │
├─ sessions ─┬─ transcript ───────────────────────────────────────────┤
│ Active     │  [user]                                                 │
│ + siblings │  ▸ Thinking · 2.1s                                      │
│ · subagents│  ▸ tool · read_file · 40ms · ok                         │
│            │  ▸ tool · shell · running…                              │
│            │  [assistant markdown — always expanded]                 │
│            │  …                                                      │
│            ├─ composer ─────────────────────────────────────────────┤
│            │  [ input ]                         [Send]               │
└────────────┴────────────────────────────────────────────────────────┘
```

### Companion (avatar)

```text
┌ avatar ┐  ┌ glass ──────────────────────────────────────────────┐
│ state  │  │ tabs: Chat1 · Chat2✦ · Sub▸review │ harness chip ▾ │
│        │  │ ▸ Thinking · …                                      │
│        │  │ ▸ 3 tools · last: shell                             │
│        │  │ last assistant lines (scroll, max ~N)               │
│        │  │ [composer]                                          │
└────────┘  └─────────────────────────────────────────────────────┘
```

Companion shows **summaries** of traces (counts / last tool), not full dumps. Expand opens a small popover or “Open full UI” at that turn.

---

## 3. Component specs

### 3.1 Thinking block (`ThinkingBlock`)

| State | Presentation |
|-------|----------------|
| Streaming | One-line header: `Thinking…` + optional shimmer; body **collapsed** unless pref “expand while streaming”. |
| Done | `▸ Thinking · 2.1s` (chevron); body hidden. |
| Expanded | Monospace/soft prose; max height ~12rem then inner scroll; “Copy”. |
| Empty / aborted | Hide block entirely. |

**Defaults:** collapsed when turn finishes; optional auto-collapse when first `assistant_delta` arrives.  
**Never** prepend `── thinking ──` into the answer bubble.

### 3.2 Tool row (`ToolTraceRow` — evolve today’s `ToolTraceWidget`)

Collapsed (default):

```text
▸  🔧  read_file   path/to/x   ·  42ms  ·  ✓
```

Expanded:

- Args (pretty JSON / key=value, truncated with “Show all”)
- Result (scrollable; secrets redacted; soft wrap)
- Optional: “Copy args”, “Copy result”, “Open in editor” (GUI only)

Grouping (optional P1): consecutive tools under one `▸ Tools · 5` accordion when count ≥ 4 in Companion; GUI keeps individual rows.

**Spam rules:**

- Do **not** mirror tool lines into the assistant text buffer.
- `status` with `phase=tool` → activity strip / avatar only.
- Cap live preview of result to ~200 chars on the row; full body only when expanded.

### 3.3 Assistant answer

- Markdown bubble, always expanded.
- Streaming append; no fake “Generating…” wall (keep current GUI behavior).
- Separate from thinking/tools in the widget tree (not one `QPlainTextEdit`).

### 3.4 Harness control

| Control | Behavior |
|---------|----------|
| Chip / combo | `auto` · `native` · `qwen` · `dsh` (+ probe badges: available / missing). |
| Scope | **Per chat slot / session**, stored on slot + session meta. |
| `auto` | Resolve via coding tags / `codingHarness` (existing `resolve_harness_name`); show **resolved** name as secondary: `auto → qwen`. |
| Change mid-chat | Applies to **next** send (do not kill in-flight run unless user Stop). |
| Unavailable | Disable option + tooltip with install hint (`custom/example_*_harness.nix`). |

Companion: same control as a compact chip (not buried in Settings).

### 3.5 Sessions & subagents

| Concept | UX |
|---------|-----|
| Chat slot | Tab / list entry (existing Companion tabs; GUI session list). |
| Child run / subagent | When harness or agent spawns a nested run → emit `run_spawn` → **new session or nested tab** under parent. |
| Switch | Click tab / list; active stream continues in background; busy indicator on inactive tabs (✦). |
| Breadcrumb | Parent title › child title in chrome when nested. |
| Back | Explicit “↑ parent” when viewing a child. |

Until adapters emit `run_spawn`, approximate with: “Open as new chat” from a tool/status line that looks like a subagent start (heuristic, documented as interim).

### 3.6 Activity strip

Single line under chrome (GUI) or under harness chip (Companion):

- `Thinking…` · `Running read_file` · `Streaming (qwen)` · `Waiting confirm` · idle empty  
Never append these into the transcript.

---

## 4. Density modes

| Mode | Where | Thinking | Tools |
|------|-------|----------|-------|
| Compact | Companion default; GUI optional | header only | one-line rows; group ≥4 |
| Comfortable | GUI default | header + first 2 lines peek optional | individual rows, slightly taller |

Persist: `QSettings` keys under `ncc-assistant` / companion.

---

## 5. Visual language (Qt, not web clone)

- **Surfaces:** soft panels, 8–12px radius, subtle border — match existing Bubble / ToolTrace chrome.
- **Hierarchy:** answer = full contrast; thinking/tools = muted header text; icons monochrome + status glyph.
- **Motion:** short expand/collapse (≤150ms); avatar states already map to thinking/speaking — keep that, stop feeding raw tokens to the bubble.
- **Avoid:** neon glow, purple AI clichés, emoji spam in headers (one glyph max per row).
- **Avatar:** state machine only (idle / thinking / speaking / error / paused); never scroll logs on the avatar itself.

---

## 6. Logging vs UI

| Stream | Destination |
|--------|-------------|
| User-facing events | Trace widgets above |
| Debug / adapter stderr | `journalctl` / optional debug drawer (off by default) |
| CLI `agent run` | Compact TTY: thinking collapsed (`…`), tools one-liners; `--verbose` for full |

Goal: Companion/GUI never feel like a terminal log mirror.

---

## 7. Implementation slices (ordered)

| Slice | Deliverable | Surfaces |
|-------|-------------|----------|
| **A** | Shared `ThinkingBlock` + stop dumping thinking into plain text | GUI + Companion |
| **B** | Unify Companion tools on `ToolTraceRow`; strip `[tool]` from reply_buf | Companion → then GUI polish |
| **C** | Harness chip per session + persist + `auto → resolved` | Companion + GUI chrome |
| **D** | Activity strip; silence `status` in transcript | both |
| **E** | `run_spawn` / session switch for subagents (+ interim heuristic) | both |
| **F** | Density toggle + prefs; CLI `--verbose` alignment | both + CLI |

Do **not** start F before A–C. Guidelines freeze first; slice A is the first code PR.

---

## 8. Acceptance criteria

- [ ] Thinking never appears fully expanded by default after a completed turn.
- [ ] Tool args/results require one click to see; 20 tools remain usable without drowning the answer.
- [ ] User can set harness per chat (`auto` shows resolved target).
- [ ] Companion and GUI use the same widget types (or thin density wrappers).
- [ ] `status` events do not grow the transcript.
- [ ] Busy background chats/subagents show a tab badge; switching does not drop the stream.
- [ ] No secrets in expanded tool results (existing redaction path).

## 9. Non-goals (this phase)

- Pixel-perfect clone of Qwen/DSH web themes.
- Live2D / VTuber.
- Replacing the event contract with ACP UI protocol (later, phase 30 follow-up).
- Virtualized 1000-row traces (revisit if needed after E).

## 10. Test plan

- Unit: event → widget state (thinking collapsed after `done`; tool row collapsed).
- Manual: qwen long think + many tools in Companion and GUI; switch harness mid-session; two tabs busy.
- Regression: confirm dialogs / presence pause still work with new chrome.

---

## Decisions (locked)

1. Mid-turn harness change: **queue-only** (next send).  
2. Subagent: **nested tab** under parent + breadcrumb + `↑ parent`.  
3. Companion thinking expand: **in-overlay** collapsible `ThinkingBlock`.
