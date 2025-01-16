# Container Manager

A rootless Podman-based container management system for NixOS.

## Features

- Rootless container management
- Dedicated podman user with proper UID/GID mapping
- Configurable logging (journald, json-file, syslog)
- Network configuration with bridge interface
- Resource limits for CPU, memory and swap
- Automatic container pruning
- Systemd integration with socket and service
- Volume management with proper permissions
- Health checks and restart policies

## Configuration

Enable the container manager in your NixOS configuration:

```nix
{
  containerManager.enable = true;
}
```

### Core Options

- `containerManager.user`: User for rootless container management (default: podman)
- `containerManager.network`: Network configuration (bridge name, subnet)
- `containerManager.defaultLogging`: Default logging configuration
- `containerManager.defaultResources`: Default resource limits

### Example: Pi-hole Container

```nix
{
  containerManager.containers.pihole = {
    enable = true;
    webPassword = "securepassword";
    dns = [ "1.1.1.1" "1.0.0.1" ];
    subdomain = "pihole";
    domain = "local";
  };
}
```

## Network Requirements

The container manager requires the following ports to be open:

- TCP: 53 (DNS), 80 (HTTP), 443 (HTTPS)
- UDP: 53 (DNS)

## System Requirements

- Linux kernel 5.13 or newer
- Systemd init system
- Podman and related dependencies
- Proper UID/GID mapping configuration

## Volume Management

Volumes are automatically created with proper permissions in:

```
/var/lib/podman/.local/share/containers/
```

Each container has its own subdirectory for persistent storage.

## Systemd Integration

The container manager provides:

- `podman.service`: Main container management service
- `podman.socket`: API socket for container management

## Backup System

Volumes are automatically backed up daily to:

```
/var/lib/containers/backups/
```

The system keeps the last 7 backups for each volume.

## Troubleshooting

Check logs with:

```bash
journalctl -u podman.service
```

Verify container status:

```bash
sudo -u podman podman ps -a
```

## Development

To add new containers:

1. Create a new directory under `containers/`
2. Add a `default.nix` with container configuration
3. Import the container in `containers/default.nix`
