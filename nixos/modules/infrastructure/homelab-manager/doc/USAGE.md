# Homelab Manager - Usage Guide

## Basic Usage

### Enabling the Module

Enable the module in your configuration:

```nix
{
  enable = true;
  stacks = [
    {
      name = "my-stack";
      compose = "/path/to/docker-compose.yml";
      env = "/path/to/.env";
    }
  ];
}
```

## Common Use Cases

### Use Case 1: Single-Server Homelab

**Scenario**: Single server with Docker Compose stacks
**Configuration**:
```nix
{
  enable = true;
  stacks = [
    {
      name = "web-services";
      compose = "/etc/nixos/homelab/web-services/docker-compose.yml";
    }
  ];
}
```
**Result**: Docker Compose stacks managed on single server

### Use Case 2: Docker Swarm Setup

**Scenario**: Multi-node Docker Swarm cluster
**Configuration**:
```nix
{
  enable = true;
  # Swarm mode auto-detected
  stacks = [
    {
      name = "swarm-stack";
      compose = "/etc/nixos/homelab/swarm/docker-compose.yml";
    }
  ];
}
```
**Result**: Docker Swarm stacks deployed across cluster

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable homelab manager
**Example**:
```nix
enable = true;
```

### `stacks`

**Type**: `listOf stackType`
**Default**: `[]`
**Description**: List of Docker Compose stacks
**Example**:
```nix
stacks = [
  {
    name = "my-stack";
    compose = "/path/to/docker-compose.yml";
    env = "/path/to/.env";
  };
];
```

## Advanced Topics

### Docker Swarm Mode

The module automatically detects Docker Swarm mode:
- **Single-Server**: Uses Docker Compose
- **Swarm Mode**: Uses Docker Swarm stack deployment
- **Auto-Detection**: No manual configuration needed

### User-Based Access Control

Docker access is controlled by user roles:
- **Virtualization Role**: Full Docker access
- **Admin Role**: Full Docker access
- **Other Roles**: No Docker access

## Integration with Other Modules

### Integration with Packages Module

The homelab manager works with Docker packages:
```nix
{
  enable = true;
}
```

## Commands

Available through ncc command-center:

- `ncc homelab create` - Create homelab environment
- `ncc homelab fetch` - Fetch stack definitions
- `ncc homelab status` - Show homelab status
- `ncc homelab update` - Update stacks
- `ncc homelab delete` - Remove homelab environment

## Troubleshooting

### Common Issues

**Issue**: Docker not accessible
**Symptoms**: Cannot access Docker commands
**Solution**: 
1. Check user role (needs virtualization or admin)
2. Verify Docker is installed
3. Check Docker service is running
**Prevention**: Ensure user has correct role

**Issue**: Swarm mode not detected
**Symptoms**: Swarm features not working
**Solution**: 
1. Check Docker Swarm is initialized
2. Verify Swarm mode is active
3. Check Docker service status
**Prevention**: Initialize Swarm before enabling module

## Performance Tips

- Use Swarm mode for multi-node setups
- Optimize Docker Compose configurations
- Monitor resource usage

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
