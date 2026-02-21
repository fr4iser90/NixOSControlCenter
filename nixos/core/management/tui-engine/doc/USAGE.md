# TUI Engine - Usage Guide

## Basic Usage

### Enabling the Module

The TUI engine is an optional core module:

```nix
{
  tui-engine = {
    enable = true;  # Enable TUI engine
  };
}
```

### Module Integration

Modules can use the TUI engine via the API:

```nix
# In module config.nix
{ config, ... }:

let
  tui = config.core.management.tui-engine.api;
in
  tui.createMenu {
    title = "Module Menu";
    items = [ ... ];
  }
```

## Common Use Cases

### Use Case 1: Interactive Menu

**Scenario**: Create interactive menu for module
**Solution**:
```nix
let
  tui = config.core.management.tui-engine.api;
in
  tui.createMenu {
    title = "Select Option";
    items = [ "Option 1" "Option 2" "Option 3" ];
  }
```

### Use Case 2: Input Form

**Scenario**: Get user input via form
**Solution**:
```nix
let
  tui = config.core.management.tui-engine.api;
in
  tui.createForm {
    fields = [
      { name = "username"; label = "Username"; }
      { name = "password"; label = "Password"; type = "password"; }
    ];
  }
```

### Use Case 3: Data Table

**Scenario**: Display data in table
**Solution**:
```nix
let
  tui = config.core.management.tui-engine.api;
in
  tui.createTable {
    headers = [ "Name" "Value" ];
    rows = [ [ "Item 1" "Value 1" ] [ "Item 2" "Value 2" ] ];
  }
```

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `false`
**Description**: Enable TUI engine
**Example**:
```nix
enable = true;
```

## Advanced Topics

### TUI Scripts

TUI scripts can be created using the engine:

```bash
# Run TUI interface
module-tui
```

### Go Integration

The TUI engine:
- Uses Go for performance
- Integrates with Nix build system
- Provides Nix packages for Go applications
- Uses gomod2nix for dependency management

## Integration with Other Modules

### Integration with CLI Formatter

The TUI engine works with CLI formatting:
```nix
let
  formatter = config.core.management.cli-formatter.api;
  tui = config.core.management.tui-engine.api;
in
  tui.createMenu {
    title = formatter.color "blue" "Menu Title";
    items = formatter.formatItems items;
  }
```

## Troubleshooting

### Common Issues

**Issue**: TUI not working
**Symptoms**: TUI interface not displaying
**Solution**: 
1. Check TUI engine is enabled
2. Verify API access: `config.core.management.tui-engine.api`
3. Check Go application is built
**Prevention**: Ensure TUI engine is enabled and Go app is built

**Issue**: Go build failing
**Symptoms**: Go application not building
**Solution**: 
1. Check Go dependencies: `go.mod`
2. Verify gomod2nix configuration
3. Check Go compiler is available
**Prevention**: Keep Go dependencies updated

## Performance Tips

- Use TUI components efficiently
- Cache TUI rendering when possible
- Optimize Go application performance

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [API Reference](./API.md) - Complete API documentation
- [README.md](../README.md) - Module overview
