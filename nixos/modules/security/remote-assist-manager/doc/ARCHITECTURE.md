# Remote Assist Manager - Architecture

## Overview

Remote Assist Manager is a host-controlled session layer for desktop sharing and assisted debugging. Streaming and input are separate capabilities: a session can share video without granting input; input is never implied by presence on the stream.

Implementation status: **docs-first**. Structure below describes the intended module layout and runtime model.

## Components

### Module Structure (planned)

```
remote-assist-manager/
├── README.md
├── default.nix
├── options.nix
├── config.nix
├── template-config.nix
├── commands.nix
├── doc/
│   ├── ARCHITECTURE.md
│   ├── USAGE.md
│   └── SECURITY.md
├── handlers/                 # session start/stop, mode changes, approve/deny
├── lib/                      # policy, event types, overlay state
├── scripts/
└── ui/                       # host overlay + guest client surfaces
    ├── gui/
    └── tui/
```

### Roles

| Role | Responsibility |
|------|----------------|
| **Host** | Owns the desktop session; starts/ends share; sets mode; freezes/disables input; approves gated actions |
| **Guest** | Joins via invite; views stream; may propose input only if mode allows |

### Session Modes

| Mode | Stream | Guest input | Host gate |
|------|--------|-------------|-----------|
| `view` | yes | no | n/a |
| `assist` | yes | yes (live) | host can freeze / disable anytime |
| `gated` | yes | proposed only | every (or policy-selected) action needs approve |

Mode can be raised or lowered during a live session by the host. Raising privilege (`view` → `assist` / `gated`) should require an explicit host confirmation; lowering should be immediate.

### Host Overlay Controls

Always available to the host while a session is active:

- **Freeze guest** — pause guest interaction (and optionally show a frozen cursor); stream may continue
- **Disable input** — drop to effective `view` without ending the session
- **Approve / Deny** — resolve pending gated actions (queue visible on overlay)
- **End session** — tear down stream + input channel

### Dual Cursor Model

- Host cursor remains the system pointer
- Guest cursor is an overlay indicator (distinct color/shape)
- In `assist`, guest motion may drive a virtual pointer under host policy
- In `gated`, guest motion/clicks become pending proposals until approved
- Host can always move independently; freeze does not steal host control

### Command Surface (planned)

| Command | Purpose | Who |
|---------|---------|-----|
| `remote-assist-start` | Start share session (default `view`) | Host |
| `remote-assist-invite` | Create/join invite token or link | Host |
| `remote-assist-set-mode` | Switch `view` / `assist` / `gated` | Host |
| `remote-assist-freeze` | Freeze / unfreeze guest | Host |
| `remote-assist-input` | Enable / disable guest input | Host |
| `remote-assist-approve` | Approve pending action | Host |
| `remote-assist-deny` | Deny pending action | Host |
| `remote-assist-end` | End session | Host |
| `remote-assist-status` | Show session + queue state | Host / local |

### Workflow Types

#### 1. View-only share (Discord-like)

```
Host start (view) → Invite → Guest joins → Stream only → Host end / timeout
```

#### 2. Live assist (TeamViewer-like, host-overridable)

```
Host start → Raise to assist → Guest input live → Host freeze/disable as needed → End
```

#### 3. Gated assist (approve every sensitive action)

```
Host start → Raise to gated → Guest proposes action → Host approve/deny → Apply or drop → End
```

## Design Decisions

### Decision 1: Security category, not specialized product

**Context**: Module mixes UX (share) with remote control trust boundaries  
**Decision**: Place under `modules/security/remote-assist-manager`  
**Rationale**: Input from outside is an access-control problem; mirrors `ssh-server-manager`  
**Alternatives**: `system/` (too discovery-oriented), `specialized/` (premature product bucket)

### Decision 2: Stream and input are separate channels

**Context**: Guests often only need to see the screen  
**Decision**: Joining a session never grants input; modes opt in  
**Rationale**: Least privilege; accidental control is a common remote-support failure mode

### Decision 3: Gated actions as first-class events

**Context**: Terminal keystrokes and filesystem clicks are high risk  
**Decision**: Model guest input as typed events with policy → allow / queue / drop  
**Rationale**: Enables per-class rules (e.g. always gate terminal, allow pointer move in assist)

### Decision 4: Host overlay is the control plane

**Context**: Host must interrupt instantly without leaving the app under debug  
**Decision**: Always-on overlay for freeze / input / approve / end  
**Rationale**: Security control must not depend on switching windows under stress

## Data Flow

```
Invite → Authn/join → Session (mode)
                ├─ Video/audio capture → encode → guest view
                └─ Guest input events → policy
                         ├─ view: drop
                         ├─ assist: apply (unless frozen/disabled)
                         └─ gated: queue → host decision → apply/drop
                → Audit log
```

### Gated action pipeline

```
Guest event → Classify (pointer | key | clipboard | …)
           → Policy match (auto-allow | require-approve | deny)
           → Pending queue + host notification
           → Approve → inject into session
           → Deny / timeout → discard + log
```

## Policy Classes (planned)

| Class | Examples | Suggested default in `gated` |
|-------|----------|------------------------------|
| `pointer.move` | cursor motion | auto-allow (visual only) or approve-on-click |
| `pointer.click` | button down/up | require-approve |
| `pointer.drag` | drag/drop | require-approve |
| `keyboard.text` | printable keys | require-approve |
| `keyboard.chord` | Ctrl/Alt shortcuts | require-approve |
| `terminal.input` | focus in terminal / PTY | require-approve (strict) |
| `clipboard` | paste/sync | deny or require-approve |
| `file.drop` | DnD into windows | require-approve |

Exact defaults are configuration; architecture only requires events to be classifiable.

## Dependencies

### Internal Dependencies

- Desktop / display session (Wayland or X11)
- Notification path (desktop notifications for pending approvals)
- Optional: patterns from `ssh-server-manager` for request lifecycle + audit

### External Dependencies (expected)

- Screen capture via portal / PipeWire (Wayland) or equivalent X11 path
- Secure transport for stream + signaling (implementation choice deferred)
- Input injection API appropriate to the compositor/session

## Extension Points

- Custom policy classes and matchers (e.g. only gate when focused app is a terminal)
- Notification backends (desktop, webhook)
- Alternative transports / codecs without changing mode/policy API
- UI themes for dual-cursor overlay

## Performance Considerations

- Capture and encode latency for usable remote debugging
- Approval queue must stay responsive under bursty guest input
- Freeze/disable must be local-fast (host path), not round-trip dependent

## Security Considerations

- Session auth, invite secrecy, mode escalation
- Input injection boundaries and freeze reliability
- Audit integrity for approvals
- Clipboard and file-drop as high-risk channels

See [SECURITY.md](./SECURITY.md).
