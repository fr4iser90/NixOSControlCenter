# Boot Entry Manager - Usage Guide

## Basic Usage

### Enabling the Module

Enable the boot entry manager in your configuration:

```nix
{
  enable = true;
}
```

## Common Use Cases

### Use Case 1: Custom Boot Entry

**Scenario**: Create custom boot entry with specific kernel parameters
**Configuration**:
```json
// /etc/nixos/boot/entries/custom.json
{
  "title": "Custom NixOS",
  "kernel": "/boot/EFI/nixos/kernel.efi",
  "initrd": "/boot/EFI/nixos/initrd.efi",
  "cmdline": "root=/dev/sda1 quiet splash custom_option=1"
}
```
**Result**: Custom boot entry created and synchronized

### Use Case 2: Multi-Boot Setup

**Scenario**: Multi-boot environment with multiple OSes
**Configuration**:
```json
// /etc/nixos/boot/entries/nixos.json
{
  "title": "NixOS",
  "kernel": "/boot/EFI/nixos/kernel.efi",
  "initrd": "/boot/EFI/nixos/initrd.efi",
  "order": 1
}

// /etc/nixos/boot/entries/windows.json
{
  "title": "Windows",
  "kernel": "/boot/EFI/Microsoft/Boot/bootmgfw.efi",
  "order": 2
}
```
**Result**: Multiple boot entries synchronized

### Use Case 3: Custom Kernel

**Scenario**: Boot with custom kernel
**Configuration**:
```json
{
  "title": "Custom Kernel",
  "kernel": "/boot/custom-kernel",
  "initrd": "/boot/custom-initrd",
  "cmdline": "root=UUID=... custom.kernel.option=1",
  "order": 2
}
```
**Result**: Custom kernel boot entry created

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable boot entry manager
**Example**:
```nix
enable = true;
```

## Advanced Topics

### Boot Entry Management

Boot entries are managed through JSON files in `/etc/nixos/boot/entries/`:

```json
{
  "title": "NixOS",
  "kernel": "/boot/EFI/nixos/kernel.efi",
  "initrd": "/boot/EFI/nixos/initrd.efi",
  "cmdline": "root=UUID=... quiet splash",
  "order": 1
}
```

### Management Commands

The module provides command-line tools:

- **`ncc bootentry-manager list`**: List all boot entries
- **`ncc bootentry-manager rename <old> <new>`**: Rename a boot entry
- **`ncc bootentry-manager reset <name>`**: Reset entry to default

### Entry Synchronization

- **Automatic Sync**: Entries are synchronized during system activation
- **Provider-Specific**: Each provider handles entry creation appropriately
- **Backup Support**: Previous configurations are backed up

## Integration with Other Modules

### Integration with Boot Module

The boot entry manager works with bootloader configuration:
```nix
{
  enable = true;
}
```

## Troubleshooting

### Common Issues

**Issue**: Entries not appearing
**Symptoms**: Boot entries not showing in bootloader
**Solution**: 
1. Check JSON syntax: `jq . /etc/nixos/boot/entries/*.json`
2. Verify required fields are present
3. Check bootloader provider is correct
**Prevention**: Validate JSON syntax before activation

**Issue**: Bootloader conflicts
**Symptoms**: Multiple bootloaders or entries not working
**Solution**: 
1. Ensure only one bootloader provider is active
2. Check bootloader configuration
3. Verify entry format matches bootloader
**Prevention**: Use correct bootloader provider

**Issue**: Permission issues
**Symptoms**: Cannot create or modify entries
**Solution**: 
1. Check file permissions in `/etc/nixos/boot/`
2. Verify user has appropriate permissions
3. Check activation script permissions
**Prevention**: Ensure proper permissions are set

### Debug Commands

```bash
# Check JSON syntax
jq . /etc/nixos/boot/entries/*.json

# View bootloader entries
efibootmgr  # For systemd-boot
grep -A 10 "menuentry" /boot/grub/grub.cfg  # For GRUB

# Check activation logs
journalctl -u nixos-activation
```

## Performance Tips

- Keep entry files minimal (only necessary entries)
- Use appropriate entry ordering
- Validate JSON before activation

## Security Best Practices

- Only load entries from trusted locations
- Validate kernel and initrd paths
- Restrict boot entry modification access
- Use secure boot when possible

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
