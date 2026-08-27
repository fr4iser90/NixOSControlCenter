# Packages System - Usage Guide

## Basic Usage

### Enabling the Module

As a core module, the packages system is configured through the system config:

```nix
{
  # Global (core.base.packages)
  packages = {
    packageModules = [ "gaming" "docker" "web-dev" ];  # sets / presets expand to sets
    systemPackages = [ "firefox" "vscode" ];           # for all users
    preset = {
      modules = [ "gaming-desktop" ];
    };
  };

  # Per-user (users.<name>.userPackages) — not under packages
  users.alice.userPackages = [ "discord" "spotify" ];
}
```

## Common Use Cases

### Use Case 1: Gaming Desktop

**Scenario**: Gaming desktop with gaming packages
**Configuration**:
```nix
{
  packages = {
    packageModules = [ "gaming" "streaming" ];
  };
}
```
**Result**: Gaming packages and streaming software installed

### Use Case 2: Development Workstation

**Scenario**: Development workstation with dev tools
**Configuration**:
```nix
{
  packages = {
    packageModules = [ "web-dev" "python-dev" "docker-rootless" ];
  };
}
```
**Result**: Development tools and Docker (rootless) installed

### Use Case 3: Preset Configuration

**Scenario**: Complete gaming desktop setup
**Configuration**:
```nix
{
  packages = {
    preset = {
      modules = [ "gaming-desktop" ];
    };
  };
}
```
**Result**: Complete gaming environment with all necessary packages

### Use Case 4: System and User Packages

**Scenario**: System-wide and user-specific packages
**Configuration**:
```nix
{
  packages = {
    systemPackages = [ "firefox" "vscode" ];
  };
  users = {
    alice.userPackages = [ "discord" "spotify" ];
    bob.userPackages = [ "slack" "zoom" ];
  };
}
```
**Result**: System-wide packages for all users, user-specific packages per user leaf

## Configuration Options

### `packageModules` (sets)

**Type**: `listOf str`
**Default**: `[]`
**Description**: List of package sets to enable
**Example**:
```nix
packageModules = [ "gaming" "docker" ];
```

### `systemPackages`

**Type**: `listOf str`
**Default**: `[]`
**Description**: System-wide packages (installed for all users)
**Example**:
```nix
systemPackages = [ "firefox" "vscode" ];
```

### Per-user packages (`users.<name>.userPackages`)

**Not** under `core.base.packages`. Live on the user leaf:

```nix
users.alice.userPackages = [ "discord" "spotify" ];
```

Installed via `users.users.<name>.packages`. CLI/GUI (`ncc packages add`) write here.

### User presets (`components/user-presets/`)

Files with `packages = [ … ]` add those attrs to the current user's `userPackages` (via `ncc-priv`), **not** `packageModules`.

System recipes live in `components/recipes/` (`modules = [ set… ]`) and expand to `packageModules` (needs root).

### `preset.modules`

**Type**: `listOf str`
**Default**: `[]`
**Description**: Legacy/system preset list on the packages config (machine-role shortcuts)
**Example**:
```nix
preset.modules = [ "gaming-desktop" ];
```

### `docker.enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable Docker support
**Example**:
```nix
docker.enable = true;
```

### `docker.root`

**Type**: `nullOr bool`
**Default**: `null`
**Description**: Docker privilege override (`null` = smart)
**Example**:
```nix
docker.root = false;  # Force rootless
docker.root = true;   # Force root Docker
# null (default): rootless, unless Homelab Swarm or AI-Workspace is active → root
```

## Advanced Topics

### Feature System

The module organizes packages by features:
- **Metadata**: Each feature has metadata (dependencies, conflicts, system type)
- **Dependency Resolution**: Automatic resolution of feature dependencies
- **Conflict Detection**: Detection and warning of conflicting features
- **System Type Filtering**: Desktop vs server feature filtering

### Docker Intelligence

Selecting `docker` in packageModules enables Docker with smart mode (`lib/docker-mode.nix`):
- **Rootless** (default): safer for desktop / single-admin use
- **Root**: when Homelab Swarm or AI-Workspace is active
- **Manual Override**: `docker.root = true|false`

### User packages

User-specific packages live only under `users.<name>.userPackages` (not under `core.base.packages`).
`ncc system-update` migrates legacy `packages.userPackages = { user = […]; }` onto those leaves and removes the old key.

## Integration with Other Modules

### Integration with System Manager

The packages module works with system type detection:
```nix
{
  system-manager = {
    systemType = "desktop";  # or "server"
  };
  packages = {
    packageModules = [ "gaming" ];  # Desktop features
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Package not found
**Symptoms**: Package not installed or error about missing package
**Solution**: 
1. Check package name in metadata: `lib/metadata.nix`
2. Verify package exists in nixpkgs
3. Check feature dependencies
**Prevention**: Use correct package names from metadata

**Issue**: Dependency conflicts
**Symptoms**: Warnings about conflicting features
**Solution**: 
1. Review feature dependencies
2. Remove conflicting features
3. Check feature metadata for conflicts
**Prevention**: Review feature dependencies before enabling

**Issue**: Docker mode wrong
**Symptoms**: Docker not working or wrong mode
**Solution**: 
1. Verify Docker mode selection logic
2. Check system configuration (Swarm/AI-Workspace)
3. Manually set `docker.root` if needed
**Prevention**: Understand Docker mode selection logic

### Debug Commands

```bash
# Check installed packages
nix-env -q

# Check package metadata
cat /etc/nixos/modules/core/base/packages/lib/metadata.nix

# Check Docker mode
docker info | grep "Root Dir"
```

## Performance Tips

- Use presets for common setups (faster configuration)
- Use feature-based packages (automatic dependency resolution)
- Keep package metadata updated
- Use system/user package separation for better organization

## See Also

- [Architecture](./architecture.md) - System architecture
- [README.md](../README.md) - Module overview
