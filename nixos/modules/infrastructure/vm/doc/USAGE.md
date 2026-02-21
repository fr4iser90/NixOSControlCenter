# VM Manager - Usage Guide

## Basic Usage

### Enabling the Module

Enable the VM manager in your configuration:

```nix
{
  enable = true;
  storage = {
    enable = true;
  };
}
```

## Common Use Cases

### Use Case 1: Basic VM Management

**Scenario**: Create and manage VMs
**Configuration**:
```nix
{
  enable = true;
}
```
**Result**: VM management capabilities enabled

### Use Case 2: VM with Storage Management

**Scenario**: VMs with dedicated storage
**Configuration**:
```nix
{
  enable = true;
  storage = {
    enable = true;
  };
}
```
**Result**: VM storage management enabled

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable VM manager
**Example**:
```nix
enable = true;
```

### `storage.enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable storage management for VMs
**Example**:
```nix
storage.enable = true;
```

### `stateDir`

**Type**: `path`
**Default**: `"/var/lib/virt"`
**Description**: Base directory for virtualization state
**Example**:
```nix
stateDir = "/var/lib/virt";
```

## Advanced Topics

### VM Creation

VMs can be created and configured through the module:
- VM definitions in `machines/`
- Storage configuration
- Network configuration

### Storage Management

Storage management provides:
- VM disk management
- Storage pool configuration
- Disk image handling

## Integration with Other Modules

### Integration with Hardware Module

The VM manager works with hardware configuration:
```nix
{
  enable = true;
}
```

## Troubleshooting

### Common Issues

**Issue**: VM not starting
**Symptoms**: VM fails to start
**Solution**: 
1. Check virtualization is enabled in BIOS
2. Verify QEMU/KVM is installed
3. Check VM configuration
**Prevention**: Ensure virtualization support is enabled

**Issue**: Storage issues
**Symptoms**: VM storage not working
**Solution**: 
1. Check storage configuration
2. Verify storage backend is available
3. Check permissions
**Prevention**: Configure storage correctly

## Performance Tips

- Use appropriate VM resources
- Optimize storage configuration
- Use hardware acceleration when available

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
