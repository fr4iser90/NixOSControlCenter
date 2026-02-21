# Chronicle - Usage Guide

## Basic Usage

### Enabling the Module

Enable chronicle in your configuration:

```nix
{
  enable = true;
  outputDir = "$HOME/.local/share/chronicle";
  format = "html";
  mode = "automatic";
}
```

## Common Use Cases

### Use Case 1: Basic Logging

**Scenario**: Enable basic system logging
**Configuration**:
```nix
{
  enable = true;
  outputDir = "$HOME/.local/share/chronicle";
  format = "html";
  mode = "automatic";
}
```
**Result**: Automatic system logging enabled

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable chronicle module
**Example**:
```nix
enable = true;
```

### `outputDir`

**Type**: `string`
**Default**: `"$HOME/.local/share/chronicle"`
**Description**: Output directory for chronicle logs
**Example**:
```nix
outputDir = "$HOME/.local/share/chronicle";
```

### `format`

**Type**: `string`
**Default**: `"html"`
**Description**: Output format (html, json, etc.)
**Example**:
```nix
format = "html";
```

### `mode`

**Type**: `string`
**Default**: `"automatic"`
**Description**: Logging mode (automatic, manual, etc.)
**Example**:
```nix
mode = "automatic";
```

## Advanced Topics

### Output Formats

Chronicle supports multiple output formats:
- **HTML**: Human-readable HTML output
- **JSON**: Machine-readable JSON output
- **Other**: Custom formatters can be added

### Analysis Tools

Chronicle provides analysis capabilities:
- Pattern recognition
- Anomaly detection
- LLM-based analysis

## Integration with Other Modules

### Integration with System Manager

The chronicle module works with system management:
```nix
{
  enable = true;
}
```

## Troubleshooting

### Common Issues

**Issue**: Logs not being generated
**Symptoms**: No output files created
**Solution**: 
1. Check output directory permissions
2. Verify module is enabled
3. Check mode configuration
**Prevention**: Ensure output directory is writable

## Performance Tips

- Use appropriate output format
- Optimize analysis tools
- Monitor resource usage

## Security Best Practices

- Use privacy-focused logging
- Secure output directory
- Control access to logs

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [API Documentation](../api/README.md) - API reference
- [README.md](../README.md) - Module overview
