# Nixify - Usage Guide

## Basic Usage

### Enabling the Module

Enable nixify in your configuration:

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

## Common Use Cases

### Use Case 1: Basic Web Service

**Scenario**: Start web service for snapshot uploads
**Configuration**:
```nix
{
  enable = true;
  webService = {
    enable = true;
    port = 8080;
  };
}
```
**Result**: Web service running on port 8080

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable nixify module
**Example**:
```nix
enable = true;
```

### `webService.enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable web service
**Example**:
```nix
webService.enable = true;
```

### `webService.showStatusBadge`

**Type**: `bool`
**Default**: `true`
**Description**: Show Active/Disabled status badges for modules in the web interface. When disabled, status badges and status filter are hidden.
**Example**:
```nix
webService = {
  enable = true;
  showStatusBadge = false;  # Hide status badges
};
```

## Advanced Topics

### Snapshot Scripts

Snapshot scripts run on target systems:
- **Windows**: PowerShell script
- **macOS**: Shell script
- **Linux**: Shell script (supports multiple package managers)

### Web Service

The web service provides:
- HTTP API for snapshot upload
- Session management
- Config generation
- ISO building

## Commands

Available through ncc command-center:

- `ncc nixify service start` - Start web service
- `ncc nixify service status` - Service status
- `ncc nixify service stop` - Stop service
- `ncc nixify list` - List all sessions
- `ncc nixify show <session>` - Show session details
- `ncc nixify download <id>` - Download config/ISO

## Integration with Other Modules

### Integration with Network Module

The nixify module works with network configuration:
```nix
{
  enable = true;
}
```

## Troubleshooting

### Common Issues

**Issue**: Web service not starting
**Symptoms**: Service fails to start
**Solution**: 
1. Check port is available
2. Verify network configuration
3. Check service logs
**Prevention**: Ensure port is not in use

**Issue**: Snapshot upload fails
**Symptoms**: Cannot upload snapshots
**Solution**: 
1. Check web service is running
2. Verify network connectivity
3. Check firewall settings
**Prevention**: Ensure web service is accessible

## Performance Tips

- Use appropriate web service port
- Optimize snapshot scripts
- Monitor web service performance

## Security Best Practices

- Use authentication for web service
- Validate snapshots before processing
- Secure network access
- Monitor web service logs

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
