# CLI Formatter - Usage Guide

## Basic Usage

### Accessing the API

```nix
# In other modules
let
  formatter = config.core.management.cli-formatter.api;
in
  formatter.box "Title" "Content"
```

### Available Functions

- **Text Formatting**: Colors, styles, alignment
- **Layouts**: Boxes, sections, columns
- **Interactive**: Menus, prompts, spinners
- **Components**: Progress bars, tables, lists
- **TUI Integration**: Advanced TUI components

## Common Use Cases

### Use Case 1: Simple Text Formatting

```nix
let
  formatter = config.core.management.cli-formatter.api;
in
  formatter.color "red" "Error message"
```

### Use Case 2: Interactive Menu

```nix
let
  formatter = config.core.management.cli-formatter.api;
in
  formatter.menu {
    title = "Select Option";
    items = [ "Option 1" "Option 2" "Option 3" ];
  }
```

### Use Case 3: Custom Component

```nix
{
  cli-formatter = {
    components = {
      custom-status = {
        enable = true;
        refreshInterval = 5;
        template = "...";
      };
    };
  };
}
```

## Configuration Options

### `config`

**Type**: `attrs`
**Default**: `{}`
**Description**: CLI formatter configuration options
**Example**:
```nix
config = {
  # Custom configuration
};
```

### `components.<name>`

**Type**: `submodule`
**Description**: Custom component definition
**Example**:
```nix
components.custom = {
  enable = true;
  refreshInterval = 5;
  template = "...";
};
```

## Advanced Topics

### Component Templates

Components use templates with CLI formatter API:
```nix
template = ''
  ${formatter.box "Status" "System is running"}
'';
```

### Integration with TUI Engine

The CLI formatter integrates with TUI engine:
```nix
let
  formatter = config.core.management.cli-formatter.api;
  tui = config.core.management.tui-engine.api;
in
  tui.createMenu {
    title = "Menu";
    items = formatter.formatItems items;
  }
```

## Integration with Other Modules

### Integration with CLI Registry

The CLI formatter works with command registration:
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

**Issue**: Formatting not working
**Symptoms**: Output not formatted correctly
**Solution**: 
1. Check API access: `config.core.management.cli-formatter.api`
2. Verify component configuration
3. Check template syntax
**Prevention**: Use correct API access pattern

**Issue**: Component not updating
**Symptoms**: Component not refreshing
**Solution**: 
1. Check refresh interval configuration
2. Verify component is enabled
3. Check template evaluation
**Prevention**: Configure refresh intervals correctly

## Performance Tips

- Use components efficiently (don't create too many)
- Cache formatted output when possible
- Use appropriate refresh intervals

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [API Reference](./API.md) - Complete API documentation
- [README.md](../README.md) - Module overview
