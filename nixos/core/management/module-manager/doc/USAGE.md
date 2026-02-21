# Module Manager - Usage Guide

## Basic Usage

### Accessing Module Config

```nix
# In other modules
let
  moduleConfig = getModuleConfig "module-name";
in
  moduleConfig.option-name
```

### Configuration Helpers

Configuration helpers are available via `_module.args.configHelpers`:

```nix
# In module config.nix
{ configHelpers, ... }:

configHelpers.createModuleConfig {
  # Configuration options
}
```

## Common Use Cases

### Use Case 1: Accessing Module Configuration

**Scenario**: Need to access another module's configuration
**Solution**:
```nix
let
  audioConfig = getModuleConfig "audio";
in
  audioConfig.system
```

### Use Case 2: Using Configuration Helpers

**Scenario**: Need to create module configuration
**Solution**:
```nix
{ configHelpers, ... }:

configHelpers.createModuleConfig {
  enable = true;
  option = "value";
}
```

## Advanced Topics

### Module Discovery Process

1. **Scan Directories**: Recursively scan module directories
2. **Read Metadata**: Extract metadata from `default.nix`
3. **Organize**: Group by category and subcategory
4. **Register**: Register in module registry

### Configuration Loading

1. **Load System Config**: Load from `/etc/nixos/configs/`
2. **Merge Template**: Merge with `template-config.nix` defaults
3. **Merge Options**: Merge with `options.nix` defaults
4. **Provide Access**: Make available via `getModuleConfig`

### Default Config Creation

The module automatically creates default configurations:
- On system activation
- For all discovered modules
- From `template-config.nix` if available
- Or minimal `{ enable = false; }` if not

## Integration with Other Modules

### Integration with System Manager

The module manager works with system-level management:
```nix
{
  module-manager = {
    # Automatic module discovery and management
  };
  system-manager = {
    # System-level services
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Module not discovered
**Symptoms**: Module not found or not loaded
**Solution**: 
1. Check module has `default.nix` with metadata
2. Verify module is in correct directory
3. Check discovery process
**Prevention**: Follow module structure guidelines

**Issue**: Config not loading
**Symptoms**: Module config not available
**Solution**: 
1. Check config file exists in `/etc/nixos/configs/`
2. Verify config path is correct
3. Check config merging process
**Prevention**: Ensure config files are created correctly

## Performance Tips

- Keep module structure consistent
- Use metadata efficiently
- Optimize config loading

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [API Reference](./API.md) - Complete API documentation
- [README.md](../README.md) - Module overview
