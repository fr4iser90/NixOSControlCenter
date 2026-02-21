# CLI Registry - Usage Guide

## Basic Usage

### Registering Commands

Modules register commands via `commands.nix`:

```nix
# In module/commands.nix
{ config, lib, pkgs, moduleName, ... }:

{
  config.core.management.cli-registry.commandSets.${moduleName} = [
    {
      name = "module-command";
      description = "Module command description";
      category = "module-category";
      script = pkgs.writeScriptBin "module-command" "...";
    };
  ];
}
```

### User-Defined Commands

Optional user-defined commands:

```nix
{
  cli-registry = {
    commands = [
      {
        name = "custom-command";
        description = "Custom user command";
        category = "custom";
        script = pkgs.writeScriptBin "custom-command" "...";
      };
    ];
  };
}
```

## Common Use Cases

### Use Case 1: Module Command Registration

**Scenario**: Register commands from a module
**Configuration**:
```nix
# In module/commands.nix
{
  config.core.management.cli-registry.commandSets.my-module = [
    {
      name = "my-command";
      description = "My module command";
      category = "my-category";
      script = pkgs.writeScriptBin "my-command" "...";
    };
  ];
}
```
**Result**: Command registered and available via `ncc`

### Use Case 2: User-Defined Commands

**Scenario**: Add custom user commands
**Configuration**:
```nix
{
  cli-registry = {
    commands = [
      {
        name = "my-script";
        description = "My custom script";
        category = "custom";
        script = pkgs.writeScriptBin "my-script" "...";
      };
    ];
  };
}
```
**Result**: Custom command available via `ncc`

## Configuration Options

### `commands`

**Type**: `listOf commandType`
**Default**: `[]`
**Description**: Additional user-defined commands
**Example**:
```nix
commands = [
  {
    name = "custom-command";
    description = "Custom command";
    category = "custom";
    script = pkgs.writeScriptBin "custom-command" "...";
  };
];
```

## Advanced Topics

### Command Categories

Categories are automatically derived from registered commands:
- System management
- Module management
- Configuration
- Development
- Custom categories

### Command Discovery

The module automatically:
- Collects commands from all modules
- Organizes them by categories
- Provides unified access interface

## Integration with Other Modules

### Integration with CLI Formatter

The CLI registry works with command formatting:
```nix
{
  config.core.management.cli-registry.commandSets.module = [
    {
      name = "command";
      script = pkgs.writeScriptBin "command" ''
        ${formatter.box "Title" "Content"}
      '';
    };
  ];
}
```

## Troubleshooting

### Common Issues

**Issue**: Command not registered
**Symptoms**: Command not available via `ncc`
**Solution**: 
1. Check command registration in `commands.nix`
2. Verify command structure is correct
3. Check module is loaded
**Prevention**: Follow command registration pattern

**Issue**: Command category wrong
**Symptoms**: Command in wrong category
**Solution**: 
1. Check command category in registration
2. Verify category name is correct
3. Check category organization
**Prevention**: Use consistent category names

## Performance Tips

- Register commands efficiently
- Use appropriate categories
- Keep command descriptions clear

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [API Reference](./API.md) - Complete API documentation
- [README.md](../README.md) - Module overview
