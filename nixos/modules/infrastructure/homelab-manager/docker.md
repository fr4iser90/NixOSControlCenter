# Homelab Manager Docker Functionality

## Auto-Activation Logic

The homelab-manager module has special auto-activation logic in `modules/default.nix`:

```nix
# Special handling for homelab-manager auto-activation
cfg = systemConfig.modules or {};
homelabSwarm = systemConfig.homelab.swarm or null;
isSwarmManager = homelabSwarm != null && (homelabSwarm.role or null) == "manager";
isSingleServer = homelabSwarm == null;

shouldActivateHomelabManager = (cfg.homelab-manager.enable or false)
  || (isSingleServer && (systemConfig.homelab or null) != null)
  || isSwarmManager;

# Override homelab-manager enable status
getModuleEnabledWithHomelab = module:
  if module.category == "modules" && module.name == "homelab-manager"
  then shouldActivateHomelabManager
  else getModuleEnabled module;
```

## Activation Conditions

homelab-manager is automatically activated when:
1. `modules.infrastructure.homelab-manager.enable = true` (manual activation)
2. `systemConfig.homelab` is configured AND `homelab.swarm` is null (Single-Server mode)
3. `homelab.swarm.role = "manager"` (Swarm Manager mode)

## Docker Integration

The homelab-manager handles Docker containers and services with the following modules:

- Automatic Docker service management
- Swarm mode support (manager/worker)
- Container orchestration
- Network configuration
- Volume management

## Usage

```bash
# Manual activation
ncc module-manager  # Enable homelab-manager

# Auto-activation via homelab config
homelab-manager = {
  enable = true;
  swarm = null;  # Single-server mode
};
```

## Implementation Notes

- Core logic in `modules/default.nix`
- Docker-specific code in homelab-manager modules
- Auto-activation bypasses normal enable/disable rules
