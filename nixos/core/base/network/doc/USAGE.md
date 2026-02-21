# Network System - Usage Guide

## Basic Usage

### Enabling the Module

As a core module, the network system provides essential networking functionality:

```nix
{
  network = {
    networkManager = {
      dns = "systemd-resolved";  # DNS configuration
    };
    networking = {
      firewall = {
        trustedNetworks = [
          "192.168.1.0/24"  # Trust local network
          "10.0.0.0/8"      # Trust VPN networks
        ];
      };
      services = {
        ssh = {
          exposure = "public";  # Allow SSH from anywhere (with warning)
          port = 22;
        };
        http = {
          exposure = "local";   # HTTP only from local network
          port = 80;
        };
      };
    };
  };
}
```

## Common Use Cases

### Use Case 1: Basic Desktop Network

**Scenario**: Desktop system with NetworkManager
**Configuration**:
```nix
{
  network = {
    networkManager = {
      dns = "systemd-resolved";
    };
  };
}
```
**Result**: NetworkManager enabled with systemd-resolved DNS

### Use Case 2: Server with Firewall

**Scenario**: Server with SSH and HTTP services
**Configuration**:
```nix
{
  network = {
    networking = {
      firewall = {
        trustedNetworks = [ "192.168.1.0/24" ];
      };
      services = {
        ssh = {
          exposure = "public";
          port = 22;
        };
        http = {
          exposure = "local";
          port = 80;
        };
      };
    };
  };
}
```
**Result**: Firewall with SSH (public) and HTTP (local) access

### Use Case 3: Development Server

**Scenario**: Development server with local services
**Configuration**:
```nix
{
  network = {
    networking = {
      firewall = {
        trustedNetworks = [ "192.168.1.0/24" ];
      };
      services = {
        ssh = {
          exposure = "local";
          port = 22;
        };
      };
    };
  };
}
```
**Result**: Firewall with local-only SSH access

## Configuration Options

### `networkManager.dns`

**Type**: `str`
**Default**: `"systemd-resolved"`
**Description**: DNS configuration
**Example**:
```nix
networkManager.dns = "systemd-resolved";
```

### `networking.firewall.trustedNetworks`

**Type**: `listOf str`
**Default**: `[]`
**Description**: Trusted networks for firewall
**Example**:
```nix
networking.firewall.trustedNetworks = [ "192.168.1.0/24" ];
```

### `networking.services.<name>.exposure`

**Type**: `enum [ "local" "public" ]`
**Description**: Service exposure level
**Example**:
```nix
networking.services.ssh.exposure = "public";
```

### `networking.services.<name>.port`

**Type**: `int`
**Description**: Service port
**Example**:
```nix
networking.services.ssh.port = 22;
```

## Advanced Topics

### Firewall System

The firewall automatically generates rules based on service configurations:

```nix
networking.services.ssh = {
  exposure = "public";  # Allow from anywhere
  port = 22;
  protocol = "tcp";
};
```

### Exposure Levels

- **local**: Only accessible from trusted networks
- **public**: Accessible from anywhere (generates security warnings)

### Automatic Rule Generation

For each configured service, the firewall:
- Opens the specified port/protocol
- Applies exposure-based filtering
- Generates iptables rules
- Provides security warnings for risky configurations

## Integration with Other Modules

### Integration with Desktop Module

The network module works with desktop environments:
```nix
{
  network = {
    networkManager = {
      dns = "systemd-resolved";
    };
  };
  desktop = {
    enable = true;
    environment = "plasma";
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Network not working
**Symptoms**: No network connection
**Solution**: 
1. Check NetworkManager service: `systemctl status NetworkManager`
2. Verify network configuration
3. Check network interfaces: `ip addr`
**Prevention**: Ensure NetworkManager is enabled

**Issue**: Firewall blocking services
**Symptoms**: Services not accessible
**Solution**: 
1. Check firewall rules: `iptables -L`
2. Verify service configuration
3. Check trusted networks
**Prevention**: Configure firewall rules correctly

**Issue**: Security warnings
**Symptoms**: Warnings about unsafe configurations
**Solution**: 
1. Review service exposure levels
2. Use "local" for development services
3. Carefully consider "public" exposure
**Prevention**: Use appropriate exposure levels

### Debug Commands

```bash
# Check NetworkManager
systemctl status NetworkManager

# Check network interfaces
ip addr

# Check firewall rules
iptables -L

# Check DNS
resolvectl status
```

## Performance Tips

- Use systemd-resolved for DNS (better performance)
- Configure trusted networks for firewall efficiency
- Use "local" exposure for development services

## Security Best Practices

- Use "local" exposure for development services
- Carefully consider "public" exposure implications
- Regularly review firewall rules and service configurations
- Use trusted networks for better security

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [Security](./SECURITY.md) - Security considerations
- [README.md](../README.md) - Module overview
