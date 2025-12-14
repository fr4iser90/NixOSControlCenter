# System Logging Module

This module provides comprehensive system logging and reporting capabilities for NixOS Control Center.

## Features

- **System Report Generation**: Automatic system reports during boot
- **Configurable Collectors**: Multiple data collection modules
- **Detail Levels**: Four levels of reporting detail (minimal, standard, detailed, full)
- **Collector Priority**: Configurable execution order for collectors
- **CLI Commands**: Manual report generation and collector management

## Available Collectors

### Core Collectors
- **profile**: System profile and basic information
- **bootloader**: Bootloader configuration and status
- **bootentries**: Available boot entries and configurations
- **packages**: Installed packages information

### Additional Collectors
- **desktop**: Desktop environment settings
- **network**: Network configuration and interfaces
- **services**: Systemd services status
- **sound**: Audio configuration and devices
- **system-config**: System configuration details
- **virtualization**: Virtualization status

## Configuration

The module is configured via `/etc/nixos/configs/logging-config.nix`:

```nix
{
  management = {
    logging = {
      enable = true;  # Enable system logging

      # Default detail level for all reports
      defaultDetailLevel = "standard";  # minimal|standard|detailed|full

      # Collector-specific configurations
      collectors = {
        # System profile collector
        profile = {
          enable = true;
          detailLevel = null;  # Use default (null = inherit)
          priority = 100;  # Execution priority (lower = sooner)
        };

        # Bootloader information
        bootloader = {
          enable = true;
          detailLevel = null;
          priority = 50;
        };

        # Boot entries
        bootentries = {
          enable = true;
          detailLevel = null;
          priority = 60;
        };

        # Installed packages
        packages = {
          enable = true;
          detailLevel = null;
          priority = 200;
        };
      };
    };
  };
}
```

## Usage

### Automatic Reports
System reports are generated automatically during boot and stored for analysis.

### Manual Reports
Use the CLI command for manual report generation:

```bash
# Generate default system report
ncc-log-system-report

# Generate detailed report
ncc-log-system-report --level detailed

# List available collectors
ncc-log-system-report --list-collectors

# Enable/disable specific collectors for this run
ncc-log-system-report --enable profile --disable packages
```

### Detail Levels
- **minimal**: Basic system information only
- **standard**: Standard system overview (default)
- **detailed**: Comprehensive system details
- **full**: Complete system dump (verbose)

## Integration

This module provides `reportingConfig` as flake argument that other modules can use:

```nix
{ config, lib, reportingConfig, ... }:
{
  # Use reportingConfig.ui for formatting
  # Use reportingConfig.reportLevels for level checks
  # Use reportingConfig.currentLevel for current detail level
}
```

## Dependencies

- Requires `core/cli-formatter` for output formatting
- Requires `core/command-center` for CLI integration
- Automatic symlink creation to `/etc/nixos/configs/logging-config.nix`

## Version History

- **v1.0**: Initial implementation with core collectors
