# Boot System - Usage Guide

## Basic Usage

### Enabling the Module

As a core module, the boot system is always active. Configure it through the system config:

```nix
{
  boot = {
    bootloader = "systemd-boot";  # Bootloader: "systemd-boot", "grub", "refind"
  };
}
```

### Minimal Configuration

```nix
{
  boot = {
    bootloader = "systemd-boot";  # Default bootloader
  };
}
```

## Common Use Cases

### Use Case 1: UEFI System with systemd-boot

**Scenario**: Modern UEFI system, want fast boot times
**Configuration**:
```nix
{
  boot = {
    bootloader = "systemd-boot";
  };
}
```
**Result**: Fast, modern bootloader with minimal configuration

### Use Case 2: Legacy BIOS System with GRUB

**Scenario**: Older system with BIOS, need traditional bootloader
**Configuration**:
```nix
{
  boot = {
    bootloader = "grub";
  };
}
```
**Result**: GRUB bootloader with BIOS support

### Use Case 3: Multi-Boot System with rEFInd

**Scenario**: Multiple operating systems, want graphical boot manager
**Configuration**:
```nix
{
  boot = {
    bootloader = "refind";
  };
}
```
**Result**: Graphical boot manager with multi-OS support

## Configuration Options

### `bootloader`

**Type**: `enum [ "systemd-boot" "grub" "refind" ]`
**Default**: `"systemd-boot"`
**Description**: Bootloader to use
**Example**:
```nix
bootloader = "grub";
```

## Advanced Topics

### Switching Bootloaders

1. Edit your boot configuration:
   ```nix
   {
     boot = {
       bootloader = "grub";  # Change from systemd-boot to grub
     };
   }
   ```

2. Rebuild system:
   ```bash
   sudo nixos-rebuild switch
   ```

3. Reboot to use the new bootloader

### Boot Management

- **Boot Entries**: Managed automatically by selected bootloader
- **Kernel Updates**: Latest kernel packages used by default
- **Initrd**: Optimized with Zstd compression

## Integration with Other Modules

### Integration with Hardware Module

The boot module works with hardware detection:
```nix
{
  hardware = {
    # Hardware-specific boot configurations
  };
  boot = {
    bootloader = "systemd-boot";
  };
}
```

### Integration with System Manager

System type affects boot configuration:
```nix
{
  system-manager = {
    systemType = "desktop";  # or "server"
  };
  boot = {
    bootloader = "systemd-boot";
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Boot failure after switching bootloaders
**Symptoms**: System doesn't boot
**Solution**: 
1. Check if bootloader is compatible with your system (UEFI vs BIOS)
2. Verify boot partition is correctly configured
3. Check bootloader installation
**Prevention**: Test bootloader compatibility before switching

**Issue**: Missing boot entries
**Symptoms**: Boot entries not showing up
**Solution**: 
1. Verify bootloader is properly configured
2. Check boot partition mount
3. Rebuild bootloader configuration
**Prevention**: Ensure boot partition is correctly mounted

**Issue**: Slow boot times
**Symptoms**: System takes long to boot
**Solution**: 
1. Check initrd compression settings
2. Verify kernel packages are up to date
3. Review bootloader configuration
**Prevention**: Use optimized initrd compression

### Debug Commands

```bash
# Check bootloader status
bootctl status  # systemd-boot
grub-mkconfig   # GRUB

# List boot entries
bootctl list    # systemd-boot

# Check kernel version
uname -r

# Check boot partition
lsblk
mount | grep boot
```

## Performance Tips

- Use systemd-boot for UEFI systems (fastest)
- Keep kernel packages up to date
- Use Zstd compression for initrd (default)
- Minimize bootloader configuration complexity

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
