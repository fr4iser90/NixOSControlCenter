# Stack Manager GUI — Fleet brainstorm (no implementation)

Status: **P0–P2 implemented in** `ui/gui/page.py` (Fleet / Host / Catalog).  
Design decisions in §0 remain binding; refine tags/placement later (P3).

Direction: one inventory (SSH creds), one cockpit (Target bar), truth per host
(`systemConfig` profiles/swarm). Fleet UI aggregates; it does not own hosts.

---

## 0. Locked decisions

| # | Topic | Decision |
|---|--------|----------|
| 1 | Inventory | **`~/.creds` only** — no second stack-manager host list |
| 2 | Fleet probe | **Refresh + short TTL cache** under `/var/lib/ncc/` (not `/etc/nixos`) |
| 3 | Tags | **Optional, declarative**, keyed by **creds id** (no duplicate IPs) |
| 4 | Non-NCC in creds | **Show greyed** (“no stacks agent”) — do not hide |
| 5 | Multi-manager Swarm | **Out of scope for v1** |
| 6 | Cockpit | **One GUI** (e.g. Gaming/Jarvis) → Target = remote; no GUI required on every node |
| 7 | Placement | Stays on each host’s monolith; fleet only aggregates / later suggests |
| 8 | GUI chrome | **≤3 tabs:** Fleet / Host / Catalog; Host = one table + filters (not 4 list boxes) |
| 9 | Visibility | **Pin + filter** in cockpit prefs; declared `profiles` on host; don’t silently omit runtime |

---

## 1. What exists today

| Layer | Reality |
|-------|---------|
| **GUI** | `ui/gui/page.py` → `HomelabPage` (“Stacks”): one **Target** at a time |
| **Chrome** | Global **Target bar** (`target_bus` / `~/.creds` via ssh-manager client) |
| **Data** | `ncc stacks status --json`, list-containers/ports/domains/stacks on **that** Target |
| **Config** | Per-host `systemConfig`: `enable`, `swarm` (`null` \| `manager` \| `worker`), `profiles`, `catalog` |
| **CLI** | Catalog list/install, fetch, init, swarm helpers — still **local-or-Target**, not a fleet map |

So today the GUI is already “multi-machine capable” only in the weak sense: pick Target → see that host. There is **no** fleet overview, no “which stack lives where”, no Swarm topology view.

---

## 2. Creds: reuse vs own inventory

### Recommendation: **one inventory — SSH `~/.creds`**

| Approach | Verdict |
|----------|---------|
| **Own stack-manager host list** | Reject for v1 — duplicates IPs/users, drifts from SSH, two UIs to maintain |
| **Reuse `~/.creds` (+ optional favorites)** | **Prefer** — Target bar already does this; Stacks must not invent a second address book |
| **Declarative fleet in `systemConfig.nix`** | Optional later: *labels* only (`roles`, `tags`, `swarmExpected`), keyed by the **same** host id as in creds — not a parallel IP list |

**Split of concerns**

```
~/.creds                          →  how to reach a machine (user@host)
ssh-manager client                →  connect / keys / Target session
stack-manager (per host config)   →  what that machine runs (profiles, swarm role)
stack-manager GUI                 →  pick Target → operate; optional fleet overlay
/var/lib/ncc/… (optional)         →  cache only (last status JSON), never SSOT for hosts
```

Do **not** put kitty/editor-style junk or connection stores under `systemConfig/`.
Do **not** recreate hybrid leaves for “fleet state”.

---

## 3. Mental model for the GUI

### A. Operating mode (default, keep)

```
[ Target: jarvis ▾ ]     ← global bar (creds)
┌ Stacks ─────────────────────────────┐
│ Overview for jarvis                 │
│ Containers / Ports / Domains / Stacks│
│ Actions: Refresh, Init Swarm, …     │
└─────────────────────────────────────┘
```

Same page, clearer copy: always show **which host** and **mode** (single / swarm manager / worker).

### B. Fleet overview (add later — optional tab or top section)

Not a second Target system — a **read-only map** that uses creds + light probes:

| Column | Source |
|--------|--------|
| Host | creds entry |
| Reachable | Target/SSH probe (cached) |
| Docker | remote `stacks status --json` |
| Mode | `swarm_status` + declared `swarm` role |
| Profiles | from that host’s config (remote read) or last-known cache |
| Tags | optional overlay (e.g. `gpu`, `arm`, `homelab`) |

Click row → set Target → jump into detail page (A).

### C. “Stacks on server1 vs jetson”

Declarative truth stays **on each machine** (`profiles = [ … ]` in that host’s monolith).
The fleet UI only **aggregates**; it does not own placement.

Optional later: a “placement board” (drag profile → host) that writes via Target into that host’s `systemConfig.nix` — still no second inventory.

---

## 4. Swarm vs non-Swarm

| Kind | Typical hosts | GUI behavior |
|------|---------------|--------------|
| **Single-node** (`swarm = null`) | jetson, jarvis, many compute boxes | Compose/profile actions; hide Swarm topology; “Init Swarm” only if user opts in |
| **Swarm manager** | e.g. server1 | Show cluster role, workers (when API available), stack deploy to swarm |
| **Swarm worker** | server2 / server3 | Mostly status + join token flow; limited “deploy here” |

**Rules of thumb**

1. **Declared** role (`systemConfig` `swarm`) = intent; **runtime** (`docker info` / status JSON) = truth. GUI shows both if they disagree (warning chip).
2. **Compute profiles** (per options) never assume Swarm — even if the host is a worker for something else.
3. Fleet overview groups: `Homelab (swarm)` vs `Compute (single)` by tags/profiles, not by inventing new host lists.

---

## 5. Adaptability (what “anpassbar” should mean)

Without building yet, lock the knobs:

1. **Target** — which machine (creds).
2. **Scope filter** — All / Homelab / Compute / Swarm-only (UI filter over status + profiles).
3. **Density** — Overview cards vs dense tables (user preference in GUI, not in Nix).
4. **Actions set** — gated by: Target connected, role (virt/admin), swarm mode, profile family.
5. **Catalog** — browse/install already CLI; GUI later reuses same verbs against current Target.

Avoid: per-module theme forks, hardcoded hostnames in the page, embedding IPs in `page.py`.

---

## 6. Proposed information architecture (phases)

| Phase | Ship | Notes |
|-------|------|-------|
| **P0** | Polish current page | Host chip, mode chip, empty states, confirm dangerous Swarm actions |
| **P1** | Fleet strip / table | Rows from creds; status probe optional/cached; click → Target |
| **P2** | Catalog in GUI | `list-catalog` / `install` against Target (CLI parity) |
| **P3** | Placement helpers | Suggest host by arch/tag; write profiles via Target update path |

No P1 without: **creds = inventory SSOT** (locked above).

---

## 7. Decisions (accepted)

Formerly open; locked in §0.

1. Fleet probe → Refresh + short TTL cache under `/var/lib/ncc/`
2. Tags → optional declarative, id = creds key
3. Non-NCC hosts → greyed in fleet
4. Multi-manager Swarm → not v1
5. One cockpit → operate remotely via Target

---

## 8. Non-goals (this brainstorm)

- Replacing CLI
- Second credentials file for stacks
- Writing fleet state under `/etc/nixos/systemConfig/**` leaves
- Auto-init Swarm on every host from the fleet view

---

## 9. One-sentence direction

**Creds = address book, Target = scope, each host’s monolith = profiles/Swarm truth; GUI = Fleet / Host / Catalog with pin+filter, never a second inventory.**

---

## 10. Long-term fit

Yes — this scales past a hobby lab:

| Scale | Still works? | Why |
|-------|--------------|-----|
| 3–15 hosts | Yes | Creds + Target + per-host config is how ops tools work |
| Swarm + compute mix | Yes | Mode is a **property of the Target**, not a separate app |
| New catalog profiles | Yes | Catalog/CLI stay the verbs; GUI only surfaces them |
| Second operator PC | Yes | Same `~/.creds` pattern; no fleet DB to sync |

What would **not** age well: a second host DB, embedding placement only in the GUI, or one mega-page that tries to edit all hosts at once.

---

## 11. Highlight / hide / pin (visibility model)

Three layers — do not mix them:

| Layer | Who owns it | Examples | Survives reinstall? |
|-------|-------------|----------|---------------------|
| **A. Declared (host)** | That host’s monolith | `profiles = [ "homelab-core" ]` — what *should* run | Yes (Nix) |
| **B. Runtime** | Docker on Target | Running / stopped / unhealthy | No (live) |
| **C. Operator view** | Cockpit UI prefs (`~/.config/ncc/` or similar) | Pin, mute, “hide stopped”, density | Local to cockpit |

### Highlight (pin / star)

- **Pin stack or profile** in the cockpit view → always at top of lists for that Target (or fleet-wide pin by `host/stack` key).
- **Pin host** in fleet table → favorites row (can mirror ssh `.creds.favorites` if it already exists).
- Optional later: declarative `stack-manager.ui.pins` — usually overkill; UI prefs are enough.

### Hide / don’t show

| Intent | Mechanism |
|--------|-----------|
| “This profile isn’t installed on this box” | Not in that host’s `profiles` → catalog can still show under **Browse**, not under **Installed** |
| “Noise: stopped one-offs” | Filter chip: **Running only** / **Unhealthy** / **All** (view layer C) |
| “I never care about this catalog family” | Scope filter: Homelab / Compute / Swarm (view layer C) |
| “Host has no NCC stacks” | Fleet: grey row, still visible (locked) |
| “Secret / internal stack name” | Don’t hide in ops UI; use naming + tags. Hiding ops data from yourself is a footgun |

**Rule:** Never delete or omit runtime truth by default. **Filter and pin**; don’t silently drop.

### Tags for emphasis (declarative, id = creds key)

```text
# sketch only — future option shape
fleet.hosts.server1.tags = [ "swarm" "edge" ];
fleet.hosts.jetson.tags  = [ "gpu" "arm" "compute" ];
```

GUI: color/chip by tag; filter “tag:gpu”. Tags do **not** replace profiles.

---

## 12. How to imagine the GUI (layout)

Not a dashboard of 12 cards. **Two levels + light tabs.**

```
┌ NCC ═══════════════════════════════════════════════════════════┐
│ Target: [ jarvis ▾ ]   status chip   [Refresh]                 │  ← global
├ Stacks ────────────────────────────────────────────────────────┤
│ [ Fleet ]  [ Host ]  [ Catalog ]                               │  ← 3 tabs max
│                                                                │
│ ═══ Host (when Target = jarvis) ═══                            │
│  jarvis · single-node · profiles: compute-llm-arm              │
│  Filters: [ All ▾ ] [ Running only ]  Search: ________         │
│                                                                │
│  ┌ Overview (compact) ─────────────────────────────────────┐   │
│  │ Docker · Swarm · Domain · Virt                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌ Workloads (one table, not four list boxes) ─────────────┐   │
│  │ ★ pinned                                                │   │
│  │ Name        Kind      Status    Ports                   │   │
│  │ traefik     compose   up        80,443                  │   │
│  │ …                                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│  Detail pane / drawer when row selected                        │
│  Actions: Start Stop Logs (gated) · Init Swarm (confirm)       │
└────────────────────────────────────────────────────────────────┘
```

### Tabs (keep to three)

| Tab | Job |
|-----|-----|
| **Fleet** | Creds rows → pick Target (P1) |
| **Host** | Current Target: overview + workloads (today’s page, cleaned up) |
| **Catalog** | Browse/install against Target (P2) |

Sub-views under Host (**Containers / Ports / Domains**) → prefer **one table + filter chips** over four stacked `QListWidget`s (current layout). Optional secondary segmented control if needed — not four equal tabs.

### Why not more tabs?

Portainer/Rancher style: **context (endpoint) first**, then one workload list. Extra tabs for Ports/Domains duplicate the same objects. Domains/ports = columns or detail drawer.

---

## 13. Further thinking worth locking now (still no code)

| Topic | Stance |
|-------|--------|
| **Search** | Always; filters stacks/containers by name |
| **Unhealthy first** | Sort: pinned → unhealthy → running → stopped |
| **Dangerous actions** | Confirm + Target name in dialog (already NCC pattern) |
| **Offline Target** | Host tab shows last cache + “stale”; no fake live lists |
| **Deep links** | Later: `ncc stacks --gui --target jarvis` opens Host tab |
| **Notifications** | Out of v1 (no tray spam for every container restart) |
| **RBAC in GUI** | Respect virt/admin same as CLI; guests don’t get Swarm init |

Worth a **follow-up brainstorm** only if you want: exact Nix option for `fleet.hosts.*.tags`, or wireframes for Catalog install flow. Not required to start P0.

---

## 14. Picture in one breath

**Long-term:** cockpit + creds + per-host Nix stays professional.  
**Day-to-day:** Target bar chooses machine; Stacks has **Fleet / Host / Catalog**; Host is one filtered table with pins; hide via filters, not by deleting truth.
