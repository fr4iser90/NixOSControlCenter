# NCC CLI Command Pattern

## The Golden Rule

```
ncc <domain> <action> [subaction] [args]
```

**Every command belongs to a domain. Always.**

---

## Philosophy

NCC is not a flat command collection. It's a **modular system control center**.

The CLI should reflect this architecture:
- **Hierarchical** - Not flat
- **Domain-driven** - Commands grouped by domain
- **Scalable** - Adding new commands doesn't pollute top-level
- **Professional** - Like Docker, Git, Kubectl

---

## Pattern Structure

### Level 1: Root
```
ncc
```
Shows only **domains** (top-level modules).

### Level 2: Domain
```
ncc <domain>
```
Shows all **actions** available in that domain.

### Level 3: Action
```
ncc <domain> <action>
```
Executes the action or shows subactions.

### Level 4: Subaction (optional)
```
ncc <domain> <action> <subaction>
```
For complex nested commands.

---

## Examples

### Good ✅
```bash
ncc system update               # Domain: system, Action: update
ncc system update-channels      # Domain: system, Action: update-channels
ncc vm test arch run           # Domain: vm, Action: test, Subaction: arch run
ncc modules enable vm          # Domain: modules, Action: enable, Args: vm
ncc chronicle start            # Domain: chronicle, Action: start
```

### Bad ❌
```bash
ncc system-update              # Flat command (old style)
ncc vm-status                  # Flat command (old style)
ncc test-arch-run              # No domain context
```

---

## Domain Hierarchy

> **Domains are user-facing namespaces** and **do not have to match module folder names**.
> Keep module folders generic/technical if you want; choose domains that are short and clean for CLI UX.

### Core Domains
System lifecycle management
```
ncc system <action>
```

### Management Domains
```
ncc modules <action>           # Module management
ncc desktop <action>           # Desktop environment
```

### Infrastructure Domains
```
ncc vm <action>                # Virtual machines
```

### Specialized Domains
```
ncc chronicle <action>         # Work memory
ncc nixify <action>            # System DNA extractor
```

---

## Command Resolution

### Without Arguments → TUI
```bash
ncc system              # Opens System Manager TUI
ncc vm                  # Opens VM Manager TUI
ncc chronicle           # Opens Chronicle TUI
```

### With Arguments → CLI
```bash
ncc system build        # Executes build directly
ncc vm status           # Shows status directly
ncc chronicle start     # Starts recording directly
```

---

## TUI Integration

Every domain provides:

1. **TUI Mode** (no args)
   - Interactive menu
   - Visual navigation
   - For exploration

2. **CLI Mode** (with args)
   - Direct execution
   - For scripting
   - For automation

---

## Comparison with Industry Standards

### Docker
```bash
docker container ls         # domain: container, action: ls
docker image build          # domain: image, action: build
docker volume prune         # domain: volume, action: prune
```

### Git
```bash
git remote add              # domain: remote, action: add
git branch delete           # domain: branch, action: delete
git stash pop               # domain: stash, action: pop
```

### Kubectl
```bash
kubectl get pods            # domain: get, action: pods
kubectl create deployment   # domain: create, action: deployment
kubectl delete service      # domain: delete, action: service
```

### NCC (Our Pattern)
```bash
ncc system update           # domain: system, action: update
ncc vm test run arch        # domain: vm, action: test, subaction: run arch
ncc modules enable vm       # domain: modules, action: enable, args: vm
```

---

## Benefits

### 1. Scalability
Adding 100 new VM distros doesn't add 200 top-level commands.
They all go under `ncc vm test <distro> <action>`.

### 2. Discoverability
```bash
ncc                    # What domains exist?
ncc system             # What can I do with system?
ncc vm test            # What distros are available?
```

### 3. Consistency
Every command follows the same pattern.
No mixing of flat and hierarchical.

### 4. Professional
Looks and feels like enterprise tools.
Not like a collection of scripts.

---

## Implementation Rules

### Rule 1: No Flat Commands
❌ `ncc system-update`
✅ `ncc system update`

### Rule 2: Every Command Has a Domain
❌ `ncc test-arch-run`
✅ `ncc vm test arch run`

### Rule 3: Domain First, Always
```
ncc <domain> <action> [subaction] [args]
```

### Rule 4: TUI for No Args
```bash
ncc <domain>           # → TUI
ncc <domain> <action>  # → CLI
```

### Rule 5: Subactions for Complexity
```bash
ncc vm test arch run       # test is action, arch run is subaction
ncc vm test arch reset     # test is action, arch reset is subaction
```

---

## Registry Integration

Commands are registered with domain context:

```nix
{
  name = "update";           # Action name
  domain = "system";         # Domain it belongs to
  description = "...";
  script = "...";
}
```

The registry automatically:
1. Groups commands by domain
2. Builds hierarchical structure
3. Generates help text
4. Creates TUI menus

---

## Migration Strategy

### Phase 1: Document Pattern (This Document)
Define the golden rule and structure.

### Phase 2: Add Domain Support to Registry
Extend types.nix with `domain` field.

### Phase 3: Migrate Existing Commands
Convert flat commands to hierarchical.

### Phase 4: Update Scripts
Adjust main script for domain resolution.

### Phase 5: Remove Old Commands
Remove all flat commands. No aliases. Clean break.

---

## Domain Definitions

See [DOMAINS.md](./DOMAINS.md) for complete domain structure.

---

## This Is The Way

No exceptions. No "special cases".

Every command follows:
```
ncc <domain> <action> [subaction] [args]
```

Always.
