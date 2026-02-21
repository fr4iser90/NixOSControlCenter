# Packages System - Usage Guide

## Basic Usage

### Enabling the Module

As a core module, the packages system is configured through the system config:

```nix
{
  packages = {
    # Legacy format (V1)
    packageModules = [ "gaming" "docker" "web-dev" ];

    # New format (V2)
    systemPackages = [ "firefox" "vscode" ];  # System-wide packages
    userPackages = {
      alice = [ "discord" "spotify" ];        # User-specific packages
    };

    # Preset configuration
    preset = {
      modules = [ "gaming-desktop" ];
    };
  };
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
    userPackages = {
      alice = [ "discord" "spotify" ];
      bob = [ "slack" "zoom" ];
    };
  };
}
```
**Result**: System-wide packages for all users, user-specific packages per user

## Configuration Options

### `packageModules` (V1 - Legacy)

**Type**: `listOf str`
**Default**: `[]`
**Description**: List of package modules to enable (legacy format)
**Example**:
```nix
packageModules = [ "gaming" "docker" ];
```

### `systemPackages` (V2)

**Type**: `listOf str`
**Default**: `[]`
**Description**: System-wide packages (installed for all users)
**Example**:
```nix
systemPackages = [ "firefox" "vscode" ];
```

### `userPackages` (V2)

**Type**: `attrsOf (listOf str)`
**Default**: `{}`
**Description**: User-specific packages (installed via home-manager per user)
**Example**:
```nix
userPackages = {
  alice = [ "discord" "spotify" ];
};
```

### `preset.modules`

**Type**: `listOf str`
**Default**: `[]`
**Description**: Preset configurations
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
**Description**: Force root Docker (null = auto-detect)
**Example**:
```nix
docker.root = false;  # Force rootless
```

## Advanced Topics

### Feature System

The module organizes packages by features:
- **Metadata**: Each feature has metadata (dependencies, conflicts, system type)
- **Dependency Resolution**: Automatic resolution of feature dependencies
- **Conflict Detection**: Detection and warning of conflicting features
- **System Type Filtering**: Desktop vs server feature filtering

### Docker Intelligence

The module automatically selects Docker mode:
- **Rootless**: Default mode for most users
- **Root**: Automatically enabled when Docker Swarm or AI-Workspace is active
- **Manual Override**: Can be manually specified via `docker.root`

### Legacy Support

The module maintains backward compatibility:
- **packageModules**: Old format still supported
- **Automatic Conversion**: Old format converted to new feature system
- **Migration Path**: Clear migration from V1 to V2 format

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

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
