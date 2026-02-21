# System Manager - Usage Guide

## Basic Usage

### System Updates

```bash
# Update configuration from remote repository
ncc system-update

# Update from local directory
ncc system-update --local /path/to/nixos

# Update channels (flake inputs)
ncc system-update --channels
```

### System Checks

```bash
# Run system health checks
ncc system-checks

# Check system configuration
ncc system-checks --config
```

### Backups

Backups are automatically created:
- Before system updates
- Before configuration migrations
- On system activation (if configured)

## Common Use Cases

### Use Case 1: System Update from Remote

**Scenario**: Update system from Git repository
**Command**:
```bash
ncc system-update
```
**Result**: System updated from remote repository

### Use Case 2: System Update from Local

**Scenario**: Update system from local directory
**Command**:
```bash
ncc system-update --local /path/to/nixos
```
**Result**: System updated from local directory

### Use Case 3: Health Checks

**Scenario**: Check system health
**Command**:
```bash
ncc system-checks
```
**Result**: System health report

## Configuration Options

### `enableVersionChecker`

**Type**: `bool`
**Default**: `true`
**Description**: Enable version checking (always available in Core)
**Example**:
```nix
enableVersionChecker = true;
```

### `enableDeprecationWarnings`

**Type**: `bool`
**Default**: `true`
**Description**: Enable deprecation warnings
**Example**:
```nix
enableDeprecationWarnings = true;
```

### `enableUpdates`

**Type**: `bool`
**Default**: `false`
**Description**: Enable automatic updates (optional)
**Example**:
```nix
enableUpdates = true;
```

### `auto-build`

**Type**: `bool`
**Default**: `false`
**Description**: Automatically build after updates
**Example**:
```nix
auto-build = true;
```

### `enableChecks`

**Type**: `bool`
**Default**: `true`
**Description**: Enable system health checks component
**Example**:
```nix
enableChecks = true;
```

## Advanced Topics

### Update System

The update system supports:
- **Remote Updates**: From Git repository
- **Local Updates**: From local directory
- **Channel Updates**: Flake input updates
- **Automatic Backups**: Before updates

### Backup System

The backup system:
- Creates backups in `/var/backup/nixos/`
- Keeps last N backups (configurable)
- Automatic cleanup of old backups
- Timestamped backup names

### Health Checks

System checks include:
- Hardware detection
- Configuration validation
- Service status
- System health metrics

## Integration with Other Modules

### Integration with Module Manager

The system manager works with module management:
```nix
{
  system-manager = {
    enableChecks = true;  # System health checks
  };
  module-manager = {
    # Module discovery and management
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Update failed
**Symptoms**: System update not working
**Solution**: 
1. Check network connection (for remote updates)
2. Verify update source is accessible
3. Check backup was created
**Prevention**: Ensure update source is accessible

**Issue**: Backup not created
**Symptoms**: No backup before update
**Solution**: 
1. Check backup directory permissions
2. Verify backup helpers are working
3. Check disk space
**Prevention**: Ensure backup directory is writable

**Issue**: Health checks failing
**Symptoms**: System health checks not working
**Solution**: 
1. Check health check components are enabled
2. Verify system-checks component is working
3. Review health check configuration
**Prevention**: Keep health check components enabled

## Performance Tips

- Use automatic backups (safety first)
- Keep backups organized (automatic cleanup)
- Use health checks regularly
- Optimize update process

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [API Reference](./API.md) - Complete API documentation
- [README.md](../README.md) - Module overview
