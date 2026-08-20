# Stack Manager

Manages **catalog-based Docker workloads** (homelab gateways/media **and** compute/LLM profiles) via the external stack catalog repo (default: NCC-HomeLab).

## Overview

- **Fetch** catalog (`ncc stacks fetch`) → virt user home
- **Init** profiles (`ncc stacks init --profile …`) → `init-homelab.sh` / `init-compute.sh`
- **Ops** (`ncc stacks ops …`) → `stacks.sh`
- **Swarm** (`ncc stacks swarm …`) → `swarm.sh` (homelab family only)
- Docker daemon itself comes from **packages** (`packageModules` / `docker.root`)

## CLI

```
ncc stacks --gui
ncc stacks status [--json]
ncc stacks fetch | init | ops | swarm | list-*
```

Alias: `ncc homelab` → `ncc stacks`

## Config sketch

```nix
enable = true;
swarm = null; # or "manager" / "worker"
profiles = [ "homelab-core" ]; # or compute-llm-x86 / compute-llm-arm
catalog.repoUrl = "https://github.com/fr4iser90/NCC-HomeLab.git";
```

## Migration

`homelab-manager` → `stack-manager` via module migration plan `stack-manager-rename-v1`.
