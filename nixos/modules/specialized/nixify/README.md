# Nixify

A module that extracts system state from Windows/macOS/Linux and generates declarative NixOS configurations.

> **Important:** The module runs on NixOS. The snapshot scripts run on target systems (Windows/macOS/Linux).

## Overview

**Nixify** extracts system state from Windows/macOS/Linux and generates declarative NixOS configurations from it.

## Quick Start

### On NixOS System (Start Service)

```nix
{
  enable = true;
  webService = {
    enable = true;
    port = 8080;
    host = "0.0.0.0";
  };
}
```

### On Target System (Windows/macOS/Linux)

**Windows:**
1. Download script: `curl http://nixos-ip:8080/download/windows -o nixify-scan.ps1`
2. Execute: `powershell -ExecutionPolicy Bypass -File nixify-scan.ps1`
3. Report is automatically uploaded

**macOS:**
1. Download script: `curl http://nixos-ip:8080/download/macos -o nixify-scan.sh`
2. Execute: `chmod +x nixify-scan.sh && ./nixify-scan.sh`
3. Report is automatically uploaded

**Linux:**
1. Download script: `curl http://nixos-ip:8080/download/linux -o nixify-scan.sh`
2. Execute: `chmod +x nixify-scan.sh && ./nixify-scan.sh`
3. Report is automatically uploaded

**Supported Linux Distributions:**
- Ubuntu/Debian (apt)
- Fedora/RHEL (dnf)
- Arch (pacman)
- openSUSE (zypper)
- NixOS (replication)

**Important:** No `ncc` needed on target systems! Only standalone scripts.

## Features

- **Cross-Platform Scanning**: Windows, macOS, and Linux support
- **System State Extraction**: Captures installed packages, configurations, and more
- **NixOS Config Generation**: Generates declarative NixOS configurations
- **Web Service**: HTTP API for snapshot upload and management
- **ISO Builder**: Creates bootable NixOS ISOs

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **System Manager**: System-level management
- **Lock Manager**: System discovery and documentation
