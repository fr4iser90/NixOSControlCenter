# Container Manager Module

This NixOS module provides a declarative container management solution supporting Docker and Podman with rootless operation.

## Features

- **Multi-manager support**: Choose between Docker and Podman
- **Rootless operation**: Secure container execution without root privileges
- **Network management**: Predefined networks with automatic creation
- **Volume management**: Configurable storage volumes with permissions
- **Security**: Sub-UID/GID mapping and container isolation

## Configuration

### Main Options

- `containerManager.containerManager`: Select container runtime (docker/podman)
- `containerManager.networks`: Configure container networks
- `containerManager.volumes`: Define persistent storage volumes
- `security.subUidRanges`: Configure sub-UID ranges for containers
- `security.subGidRanges`: Configure sub-GID ranges for containers

### Docker Rootless Options

- `containerManager.docker.rootless.enable`: Enable rootless Docker mode (default: false)
- `containerManager.docker.rootless.setSocketVariable`: Automatically set DOCKER_HOST variable (default: true)
- `containerManager.docker.rootless.daemon.settings`: Docker daemon configuration (JSON format)
  - Default includes address pools for container manager networks

### Network Configuration

Predefined networks include:
- proxy (172.40.0.0/16)
- security (172.41.0.0/16) 
- database (172.42.0.0/16)
- backup (172.43.0.0/16)
- monitoring (172.44.0.0/16)
- media (172.45.0.0/16)
- storage (172.46.0.0/16)
- management (172.47.0.0/16)
- games (172.50.0.0/16)

### Volume Configuration

Volume options:
- `path`: Absolute path to volume
- `user`: Owner user
- `group`: Owner group  
- `mode`: Permissions (default: 755)
- `backup`: Enable daily backups
- `initData`: Initial data for volume

### Security Configuration

- Sub-UID/GID mapping for container users
- Dedicated system user for container management
- Rootless operation with proper privilege separation

## Usage

1. Select container manager in configuration:
```nix
containerManager.containerManager = "docker"; # or "podman"
```

2. Configure networks:
```nix
containerManager.networks = {
  custom = {
    subnet = "172.51.0.0/16";
    gateway = "172.51.0.1";
  };
};
```

3. Define volumes:
```nix 
containerManager.volumes = {
  app-data = {
    path = "/var/lib/myapp/data";
    user = "myuser";
    mode = "750";
    backup = true;
  };
};
```

4. Configure security:
```nix
security = {
  subUidRanges = [ { startUid = 100000; count = 65536; } ];
  subGidRanges = [ { startGid = 100000; count = 65536; } ];
};
```

## Files

- `base.nix`: Core container manager configuration
- `selection.nix`: Container manager selection logic
- `networks.nix`: Network configuration and setup
- `volumes.nix`: Volume management
- `security-options.nix`: Security configuration
