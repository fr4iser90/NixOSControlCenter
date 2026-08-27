# NixOS Control Center - Usage Guide

## Basic Usage

### Main Command

The `ncc` command is the main entry point:

```bash
# List all available commands
ncc

# Execute a command
ncc system-update

# Get help for a command
ncc help system-update
```

### Command Categories

Commands are organized by categories:
- System management
- Module management
- Configuration
- Development
- Custom categories

## Common Use Cases

### Use Case 1: System Update

**Scenario**: Update system configuration
**Command**:
```bash
ncc system-update
```
**Result**: System configuration updated

### Use Case 2: Module Management

**Scenario**: Manage modules
**Command**:
```bash
ncc module-list
ncc module-enable module-name
```
**Result**: Modules managed

## Configuration Options

### `dangerousIgnore`

**Type**: `bool`  
**Default**: `false`  
**Where**: `systemConfig` → **`nixos-control-center`** (Core CLI host policy)  
**Effect**: Skip cli-registry dangerous yes/no for all commands marked `dangerous`.  
**Per run** (no rebuild): `--yes` / `-y` / `--auto`, or `NCC_ASSUME_YES=1`.  
**Does not** turn on build+switch — that is `system-manager.autoBuild`.

```nix
nixos-control-center = {
  dangerousIgnore = true;  # unattended / scripting hosts
};
```

Also see **system-manager.autoBuild** and Control Center ⚙ → **Safety**.

## Advanced Topics

### Command Orchestration

NCC orchestrates commands by:
- Collecting commands from CLI registry
- Organizing by categories
- Providing unified execution interface
- Handling dangerous operations

### Dangerous Operations

NCC warns about dangerous operations:
- System modifications
- Data deletion
- Configuration changes
- Can be bypassed with `dangerousIgnore = true`

## Integration with Other Modules

### Integration with CLI Registry

NCC works with command registration:
```nix
{
  cli-registry = {
    # Commands registered here
  };
  nixos-control-center = {
    # NCC orchestrates commands
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Command not found
**Symptoms**: Command not available via `ncc`
**Solution**: 
1. Check command is registered in CLI registry
2. Verify command name is correct
3. Check module is loaded
**Prevention**: Ensure commands are properly registered

**Issue**: Dangerous operation warning
**Symptoms**: Warning about dangerous operation
**Solution**: 
1. Review operation carefully
2. Use `dangerousIgnore = true` if safe for automation
3. Confirm operation is intended
**Prevention**: Understand operation implications

## Performance Tips

- Use command categories for organization
- Cache command lookups when possible
- Optimize command execution

## See Also

- [Architecture](./architecture.md) - System architecture
- [API Reference](./api.md) - Complete API documentation
- [README.md](../README.md) - Module overview
