# System Checks

Comprehensive system validation and safety checks for NixOS Control Center.

## Overview

The checks module provides two types of system validation:

- **Prebuild Checks**: Run before system builds to catch configuration issues
- **Postbuild Checks**: Run after system activation to ensure system health

## Features

### Prebuild Checks
- **CPU Validation**: Check CPU configuration and compatibility
- **GPU Detection**: Verify GPU drivers and configuration
- **Memory Analysis**: Validate memory settings and availability
- **User Verification**: Check user accounts and permissions

### Postbuild Checks
- **Password Security**: Ensure admin users have valid passwords
- **Filesystem Integrity**: Check critical directories and permissions
- **Service Validation**: Verify critical system services are running

## Usage

### Prebuild Checks
```bash
# Build with safety checks (recommended)
build switch

# Skip checks (not recommended)
build switch --force
```

### Postbuild Checks
Postbuild checks run automatically after system activation via `config.system.activationScripts`.

## Configuration

Configure via `systemConfig.core.management.system-manager.submodules.system-checks` in your `flake.nix`:

```nix
{
  systemConfig.core.management.system-manager.submodules.system-checks = {
    enable = true;  # Default: true

    prebuild = {
      enable = true;
      checks = {
        cpu.enable = true;
        gpu.enable = true;
        memory.enable = true;
        users.enable = true;
      };
    };

    postbuild = {
      enable = true;
      checks = {
        passwords.enable = true;
        filesystem.enable = true;
        services.enable = true;
      };
    };
  };
}
```

## Architecture

### Directory Structure

```
checks/
├── README.md                    # This file
├── default.nix                  # Main module imports
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── checks-config.nix           # User configuration
├── lib/                        # Shared utilities
│   ├── default.nix             # Library exports
│   ├── types.nix               # Type definitions
│   └── utils.nix               # Utility functions
├── prebuild/                   # Prebuild check modules
│   ├── old-default.nix         # Archived implementation
│   └── checks/
│       ├── hardware/
│       │   ├── cpu.nix
│       │   ├── gpu.nix
│       │   ├── memory.nix
│       │   └── utils.nix
│       └── system/
│           └── users.nix
└── postbuild/                  # Postbuild check modules
    └── old-default.nix         # Archived implementation
```

### Key Components

- **`default.nix`**: Module structure and conditional imports
- **`options.nix`**: Defines check configuration options
- **`config.nix`**: Complete implementation of all checks
- **`checks-config.nix`**: User configuration file
- **`lib/`**: Shared utilities for check processing

## Check Details

### CPU Check
- Validates CPU microcode updates
- Checks for hardware virtualization support
- Verifies CPU frequency scaling

### GPU Check
- Detects GPU hardware
- Validates driver installation
- Checks for hardware acceleration

### Memory Check
- Validates memory configuration
- Checks swap space availability
- Monitors memory usage patterns

### User Check
- Verifies user account integrity
- Checks group memberships
- Validates permission settings

### Password Check
- Ensures admin users have passwords set
- Interactive password setup for new users
- Security validation

### Filesystem Check
- Creates required system directories
- Sets correct permissions
- Validates secret storage locations

### Service Check
- Monitors critical system services
- Automatic service restart on failure
- Dependency validation

## Development

### Adding New Checks

1. **Prebuild Check**: Add to `prebuild/checks/` directory
2. **Postbuild Check**: Define in `config.nix` postbuildChecks section
3. **Enable in options**: Add to `options.nix` and `checks-config.nix`

### Check Script Format
```bash
#!/usr/bin/env bash
# Check logic here
# Return 0 for success, 1 for failure
```

## Symlink Management

User configuration is automatically symlinked to `/etc/nixos/configs/checks-config.nix` for easy editing.

## Dependencies

- `core.cli-formatter` - For formatted output
- `systemConfig.command-center` - For command registration

## Troubleshooting

### Prebuild Checks Failing
- Use `--force` flag to skip checks temporarily
- Check individual check logs for specific failures
- Verify hardware configuration

### Postbuild Checks Failing
- Check system logs: `journalctl -u nixos-postbuild`
- Verify service status: `systemctl status <service>`
- Check directory permissions

### Permission Issues
- Ensure user has sudo access for admin operations
- Check `/etc/nixos/secrets/` directory permissions

## Versioning

This module follows semantic versioning:
- **Current Version**: 1.0
- **Breaking Changes**: Will require migration
- **Backward Compatibility**: Maintained within major versions
