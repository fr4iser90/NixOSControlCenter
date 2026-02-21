# Lock Manager - Usage Guide

## Basic Usage

### Enabling the Module

Enable the lock manager in your configuration:

```nix
{
  enable = true;
  snapshotDir = "/var/lib/nixos-control-center/snapshots";
  scanners = {
    desktop = true;
    steam = true;
    browser = true;
    ide = true;
    credentials = true;
    packages = true;
  };
}
```

## Common Use Cases

### Use Case 1: Basic System Discovery

**Scenario**: Document system state
**Configuration**:
```nix
{
  enable = true;
  scanners = {
    desktop = true;
    packages = true;
  };
}
```
**Result**: System state documented

### Use Case 2: Full System Discovery with Encryption

**Scenario**: Complete system discovery with encrypted storage
**Configuration**:
```nix
{
  enable = true;
  scanners = {
    desktop = true;
    steam = true;
    browser = true;
    ide = true;
    credentials = true;
    packages = true;
  };
  encryption = {
    enable = true;
    method = "sops";
    sops = {
      ageKeyFile = "/path/to/age-key.txt";
    };
  };
}
```
**Result**: Encrypted system snapshots created

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable lock manager
**Example**:
```nix
enable = true;
```

### `scanners`

**Type**: `submodule`
**Description**: Scanner configuration
**Example**:
```nix
scanners = {
  desktop = true;
  steam = true;
  browser = true;
  ide = true;
  credentials = true;
  packages = true;
};
```

### `encryption`

**Type**: `submodule`
**Description**: Encryption configuration
**Example**:
```nix
encryption = {
  enable = true;
  method = "sops";  # or "fido2" or "both"
  sops = {
    ageKeyFile = "/path/to/age-key.txt";
  };
};
```

## Advanced Topics

### Scanner Configuration

Each scanner can be individually enabled/disabled:
- **desktop**: Desktop settings (themes, wallpapers, etc.)
- **steam**: Steam game detection
- **browser**: Browser extensions, bookmarks, settings
- **ide**: IDE extensions, plugins, settings
- **credentials**: SSH/GPG key metadata (no private keys)
- **packages**: Installed packages (NixOS, Flatpak, etc.)

### Encryption Methods

#### SOPS Encryption

```nix
encryption = {
  enable = true;
  method = "sops";
  sops = {
    ageKeyFile = "/path/to/age-key.txt";
  };
};
```

#### FIDO2/YubiKey Encryption

```nix
encryption = {
  enable = true;
  method = "fido2";
  fido2 = {
    device = "/dev/hidraw0";  # Optional, auto-detected
  };
};
```

### GitHub Upload

```nix
github = {
  enable = true;
  repository = "your-username/your-repo";
  branch = "main";
  tokenFile = "/path/to/github-token.sops.yaml";
};
```

## Integration with Other Modules

### Integration with System Manager

The lock manager works with system management:
```nix
{
  enable = true;
}
```

## Commands

Available through ncc command-center:

- `ncc discover` - Create system snapshot
- `ncc fetch` - Fetch snapshots from GitHub
- `ncc restore` - Restore from snapshot

## Troubleshooting

### Common Issues

**Issue**: sops not found
**Symptoms**: Encryption fails
**Solution**: 
1. Install sops-nix module
2. Configure sops properly
3. Verify age key file exists
**Prevention**: Ensure sops is properly configured

**Issue**: FIDO2 not working
**Symptoms**: FIDO2 encryption fails
**Solution**: 
1. Install `age-plugin-yubikey`
2. Ensure YubiKey is plugged in
3. Check permissions: `sudo chmod 666 /dev/hidraw*`
4. Verify YubiKey: `age-plugin-yubikey -l`
**Prevention**: Ensure YubiKey is properly configured

**Issue**: GitHub upload fails
**Symptoms**: Cannot upload to GitHub
**Solution**: 
1. Check if token is valid
2. Ensure repository exists
3. Check token permissions (repo scope required)
4. Verify token file is properly decrypted
**Prevention**: Ensure GitHub token is correctly configured

## Performance Tips

- Enable only needed scanners
- Use appropriate encryption method
- Optimize snapshot storage
- Use differential snapshots for large systems

## Security Best Practices

- Use encryption for all snapshots
- Store encryption keys separately
- Use FIDO2/YubiKey for additional security
- Regularly verify snapshot integrity
- Keep encryption key backups separate

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Security](./SECURITY.md) - Security considerations
- [README.md](../README.md) - Module overview
