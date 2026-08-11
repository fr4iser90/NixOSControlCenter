# Remote Assist Manager

Secure desktop session sharing and optional remote assistance for debugging help — from view-only screen share to gated guest input with host approval.

## Overview

Remote Assist Manager lets a host share their session with a guest for troubleshooting or collaboration. The guest can watch like Discord screen share, or — when enabled — send input like TeamViewer, under host policies: freeze, disable input, dual cursors, and per-action approval (clicks, terminal keystrokes, clipboard, etc.).

## Features

- **View mode**: Stream-only sharing (guest sees, cannot control)
- **Assist mode**: Optional guest input with host always in control
- **Dual cursors**: Host and guest pointers rendered separately on the overlay
- **Host overlay controls**: Freeze guest, disable input, take over / reclaim focus
- **Gated input**: Guest actions require host approve/deny before they apply
- **Session lifecycle**: Invite → connect → mode select → end / auto-timeout
- **Audit trail**: Session events and approval decisions logged

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - Modes, trust model, data flow, design decisions
- [Usage Guide](./doc/USAGE.md) - Planned configuration and workflows
- [Security](./doc/SECURITY.md) - Threat model and hardening guidance

## Related Components

- **SSH Server Manager**: Request/approval pattern for temporary access (shell analogue)
- **Desktop / PipeWire**: Screen capture and portal stack for Wayland/X11 streaming
