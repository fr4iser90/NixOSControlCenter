# Container Manager
virtualisation.oci-containers Rootless pretty problematic...
## Volume Initialization Middleware

The container manager includes a volume initialization middleware that automatically handles volume setup before container startup.

### Features

- Automatic directory creation
- Initial data population from Nix store paths
- Permission and ownership management
- State tracking with .initDataCopied flag
- Detailed logging
- Systemd service integration

### Configuration

Volumes are configured in the storage.volumes option:

```nix
storage.volumes = {
  myVolume = {
    path = "/var/lib/containers/myVolume";
    user = "podman";
    group = "podman";
    mode = "755";
    initData = ./initial-data; # Optional initial data
    backup = true; # Enable daily backups
  };
};
```

### Logs

Volume initialization logs are stored in:
```
/var/log/container-manager/volume-init.log
```

### Service

The middleware runs as a systemd service:
```
init-container-volumes.service
```

This service runs before container services (docker/podman) and ensures volumes are properly initialized.

### Manual Execution

The initialization script can be run manually:
```bash
init-container-volumes
```

### Backup System

Volumes with backup = true are automatically backed up daily to:
```
/var/lib/containers/backups/<volume-name>/
```

The system keeps the last 7 backups for each volume.
