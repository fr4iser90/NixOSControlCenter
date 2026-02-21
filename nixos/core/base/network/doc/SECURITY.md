# Network System - Security

## Security Considerations

### Firewall Warnings

The module generates warnings for potentially unsafe configurations:
- Services exposed publicly when recommended for local access
- Missing security considerations for service exposure

### Best Practices

- Use "local" exposure for development services
- Carefully consider "public" exposure implications
- Regularly review firewall rules and service configurations
- Use trusted networks for better security

### Threat Model

- **Network Attacks**: Firewall protects against unauthorized access
- **Service Exposure**: Services exposed publicly are at risk
- **Trusted Networks**: Trusted networks reduce security but improve usability

## Security Configuration

### Firewall Configuration

```nix
{
  network = {
    networking = {
      firewall = {
        trustedNetworks = [ "192.168.1.0/24" ];  # Trust local network
      };
      services = {
        ssh = {
          exposure = "local";  # Local only (safer)
          port = 22;
        };
      };
    };
  };
}
```

### Service Exposure Levels

- **local**: Only accessible from trusted networks (safer)
- **public**: Accessible from anywhere (less safe, generates warnings)

## Security Recommendations

1. **Use Local Exposure**: Prefer "local" for most services
2. **Review Warnings**: Pay attention to security warnings
3. **Trusted Networks**: Configure trusted networks carefully
4. **Regular Reviews**: Regularly review firewall rules
