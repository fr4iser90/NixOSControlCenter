# Features

Current product status for NixOS Control Center.  
`[x]` = present in tree and usable · `[~]` = partial · `[ ]` = planned / missing

## Install & system lifecycle

- [x] Install wizard (CLI / fzf / GUI via `nix-shell`)
- [x] Dry-run install (`install-dry` / `NCC_DRY_RUN`)
- [x] `ncc system-update` — local tree or git remote
- [x] Backups before update
- [x] Module + config migrations (`apply-migrations`)
- [x] Prebuild checks (CPU / GPU / memory / platform / users / …)
- [~] Post-build validation
- [ ] One-click rollback UX (Nix generations exist; NCC polish TBD)

## Hardware & base system

- [x] Hardware detection (CPU / GPU / RAM / platform)
- [x] GPU paths: AMD, Intel, NVIDIA, hybrid, Jetson, VM, none
- [x] Network (NetworkManager, WiFi, firewall basics)
- [x] Desktop domain (enable/configure DE)
- [x] Users / roles
- [x] Boot / bootentry management
- [x] Audio, localization
- [~] Deeper CPU power / frequency UX
- [~] Memory / swap guided UX

## Packages

- [x] Feature sets + recipes + user presets (catalog)
- [x] CLI + GUI package management
- [x] Gaming / docker / web-dev / virt / … sets
- [~] “Windows-easy” install flows (still rebuild-based)

## Surfaces

- [x] CLI (`ncc <domain> …`) via cli-registry
- [x] GUI engine (PySide6) + many domain pages
- [x] TUI engine + selected domain TUIs
- [~] Full TUI coverage for every domain
- [ ] Polished themes / light-dark product theming

## Optional modules (features)

- [x] stack-manager (Docker / Swarm workloads; replaces homelab-manager)
- [x] VM (QEMU/KVM)
- [x] SSH manager (host + client tools)
- [x] lock-manager (discovery snapshots)
- [x] nixify (scan foreign OS → NixOS config; ISO/Calamares partial)
- [x] ncc-assistant (`ncc ai`)
- [x] chronicle (event / session logging)
- [~] ai-workspace (schemas / services; uneven surface)
- [ ] remote-assist-manager (**docs only** — no `default.nix` yet)

## Fleet / remote

- [x] GUI / CLI target session over SSH (pieces)
- [x] stack-manager fleet tags / Swarm
- [~] Cohesive multi-host control center
- [ ] Full remote-assist product

## Known hard limits

See [`limitations.md`](./limitations.md) (kernel anti-cheat games, fleet maturity).
