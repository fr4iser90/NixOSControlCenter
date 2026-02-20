# Homelab Manager Feature

Feature for managing homelab environments using Docker containers, with support for both single-server and Docker Swarm modes.

## Features

- Environment creation and configuration
- Docker Compose stack management
- Swarm mode support
- User-based Docker access control
- Integrated command-center commands

## Requirements

- Docker installed and configured
- Appropriate user with Docker privileges (virtualization or admin role)
- System configuration for homelab stacks

## Usage

Enable the module in your user config:

```nix
{
  modules.infrastructure.homelab = {
    enable = true;
    stacks = [
      {
        name = "my-stack";
        compose = "/path/to/docker-compose.yml";
        env = "/path/to/.env";
      }
    ];
  };
}
```

## Commands

Available through ncc command-center:

- `ncc homelab create` - Create homelab environment
- `ncc homelab fetch` - Fetch stack definitions
- `ncc homelab status` - Show homelab status
- `ncc homelab update` - Update stacks
- `ncc homelab delete` - Remove homelab environment

## Configuration

See `template-config.nix` for available options.

## Dependencies

- Docker
- Optionally: Docker Swarm for multi-node setups

## Version History

See CHANGELOG.md for detailed changes.
