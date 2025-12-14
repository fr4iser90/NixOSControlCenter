# ANALYSIS: Modular vs Monolithic Configuration

## PROBLEM IDENTIFIED

The flake needs configuration values **BEFORE** system build for:
- `nixosConfigurations."${hostname}"` - hostname must be known during flake eval
- `nixpkgs` selection based on `system.channel`
- `home-manager` selection based on `system.channel`
- `stateVersion` based on `system.channel`

## CURRENT SOLUTION (BROKEN - TOO LATE)

**Config Manager loads during SYSTEM BUILD** - flake braucht configs VORHER!

```
Flake Eval: ❌ Configs noch nicht verfügbar (Module noch nicht geladen)
System Build: ✅ Configs werden geladen (zu spät!)
```

## WHY IT FAILS

1. **Flake evaluation happens FIRST** - before any modules are loaded
2. **Modules are loaded during system build** - after flake eval
3. **Config Manager is a module** - loads during build, not eval

## WORKING SOLUTIONS

### Solution 1: MONOLITHIC (What you want)
- `system-config.nix` in `/etc/nixos/` root
- Flake loads it during eval: `systemConfig = import ./system-config.nix`
- **Pros:** Works immediately, no --impure
- **Cons:** Monolithic file, not modular

### Solution 2: HYBRID
- Keep `system-config.nix` for flake values
- Modular configs for everything else
- **Pros:** Minimal flake values, modular system configs
- **Cons:** Two places to edit configs

### Solution 3: SIMPLIFY FLAKE
- Remove nixpkgs/channel selection from flake
- Always use stable versions
- Load hostname from module defaults
- **Pros:** Clean flake, modular configs work
- **Cons:** No dynamic channel selection

### Solution 4: IMPURE (What you rejected)
- Load configs during flake eval with --impure
- **Pros:** Modular, works with complex flake logic
- **Cons:** --impure flag required

## RECOMMENDATION

**Go back to monolithic for now.** The modular approach requires either:
1. --impure (you rejected)
2. Simplified flake (remove complex logic)
3. Hybrid approach (flake values separate)

Since you want complex flake logic + no --impure + modular configs, **it's impossible** with current Nix limitations.

## IMPLEMENTATION: MONOLITHIC REVERT

1. Create `/etc/nixos/system-config.nix` with all values
2. Update flake to load it: `systemConfig = import ./system-config.nix`
3. Remove Config Manager module
4. Keep modular config files as templates/documentation

## VERDICT

**The modular dream is beautiful, but Nix flake evaluation happens too early.** Without --impure, modular configs during flake eval are impossible.

**Monolithic it is.** At least it works reliably.
