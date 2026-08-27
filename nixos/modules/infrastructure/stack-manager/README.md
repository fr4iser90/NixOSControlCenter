# Stack Manager

Manages **catalog-based Docker workloads** (homelab gateways/media **and** compute/LLM profiles) via the external stack catalog repo (default: [NCC-Stacks](https://github.com/fr4iser90/NCC-Stacks)).

## Overview

- **Fetch** catalog (`ncc stacks fetch`) → virt user home
- **Browse** (`ncc stacks list-profiles` / `list-catalog`) → local, `NCC_STACKS_ROOT`, or `--remote` ephemeral clone
- **Install** (`ncc stacks install --profile …` | `group/service`) → profile bundle or single stack
- **Init** profiles (`ncc stacks init --profile …`) → `init-homelab.sh` / `init-compute.sh`
- **Ops** (`ncc stacks ops …`) → `stacks.sh`
- **Swarm** (`ncc stacks swarm …`) → `swarm.sh` (homelab family only)
- Docker daemon itself comes from **packages** (`packageModules` / `docker.root`)

## CLI

CLI contract: [cli.md](./doc/cli.md)

Setup architecture (host vs workloads, NCC ↔ NCC-Stacks contract): [doc/setup-flow.md](./doc/setup-flow.md)


```
ncc stacks --gui
ncc stacks status [--json]
ncc stacks list-profiles [--remote] [--all] [-v]
ncc stacks list-catalog [--remote] [--family …] [-v]
ncc stacks fetch | install | init | ops | swarm | list-*
```

## Config sketch

```nix
enable = true;
swarm = null; # or "manager" / "worker"
profiles = [ "homelab-core" ]; # or compute-llm-x86 / compute-llm-arm
catalog.repoUrl = "https://github.com/fr4iser90/NCC-Stacks.git";
```

## Migration

`homelab-manager` → `stack-manager` via module migration plan `stack-manager-rename-v1`.
