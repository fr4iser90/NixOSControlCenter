# CLI Formatter - Usage Guide

## Basic Usage

### Accessing the API

```nix
# In other modules — discovery only (never config.core.management.*)
ui = getModuleApi "cli-formatter";
# ${ui.messages.info "…"} ${ui.messages.success "…"} ${ui.messages.error "…"}
# ${ui.boxes.box "Title" "Content"}  # or ui.prompts / ui.tables / …
```

### Available Functions

- **Text Formatting**: Colors, styles, alignment
- **Layouts**: Boxes, sections, columns
- **Interactive**: Menus, prompts, spinners
- **Components**: Progress bars, tables, lists
- **TUI Integration**: Advanced TUI components
- **Status**: `ui.messages.*` / `ui.badges.*` for user-facing CLI status

## Common Use Cases

### Use Case 1: Simple status messages

```nix
ui = getModuleApi "cli-formatter";
# In a writeShellScript:
# ${ui.messages.error "Something failed"}
# ${ui.messages.success "Done"}
```

### Use Case 2: Interactive Menu

```nix
ui = getModuleApi "cli-formatter";
# ${ui.menus.menu { title = "Select Option"; items = [ "Option 1" "Option 2" ]; }}
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
ui = getModuleApi "cli-formatter";
tui = (getModuleApi "tui-engine").fromConfig config;
# Use ui.* for status/layout; tui.* for interactive menus
```

## Integration with Other Modules

### Integration with CLI Registry

Register commands via the registry API (not hardcoded option paths):
```nix
cliRegistry = getModuleApi "cli-registry";
ui = getModuleApi "cli-formatter";
# cliRegistry.registerCommandsFor "my-module" [ { … script with ui.messages … } ]
```

## Troubleshooting

### Common Issues

**Issue**: Formatting not working
**Symptoms**: Output not formatted correctly
**Solution**: 
1. Check API access: `ui = getModuleApi "cli-formatter"`
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
