# Localization System - Usage Guide

## Basic Usage

### Enabling the Module

As a core module, the localization system is configured through the system config:

```nix
{
  localization = {
    locales = [ "en_US.UTF-8" "de_DE.UTF-8" ];  # Supported locales
    keyboardLayout = "de";                       # Keyboard layout
    keyboardOptions = "terminate:ctrl_alt_bksp"; # Keyboard options
    timeZone = "Europe/Berlin";                 # System timezone
  };
}
```

## Common Use Cases

### Use Case 1: Single Locale

**Scenario**: System in one language
**Configuration**:
```nix
{
  localization = {
    locales = [ "en_US.UTF-8" ];
    keyboardLayout = "us";
    timeZone = "America/New_York";
  };
}
```
**Result**: English system with US keyboard and Eastern timezone

### Use Case 2: Multiple Locales

**Scenario**: Multilingual system
**Configuration**:
```nix
{
  localization = {
    locales = [
      "en_US.UTF-8"  # Default locale
      "de_DE.UTF-8"  # German locale
      "fr_FR.UTF-8"  # French locale
    ];
    keyboardLayout = "de";
    timeZone = "Europe/Berlin";
  };
}
```
**Result**: Multilingual system with German keyboard

### Use Case 3: Keyboard Options

**Scenario**: Need special keyboard options
**Configuration**:
```nix
{
  localization = {
    keyboardLayout = "de";
    keyboardOptions = "terminate:ctrl_alt_bksp";  # Ctrl+Alt+Backspace to terminate X
  };
}
```
**Result**: German keyboard with termination option

## Configuration Options

### `locales`

**Type**: `listOf str`
**Default**: `[ "en_US.UTF-8" ]`
**Description**: List of supported locales
**Example**:
```nix
locales = [ "en_US.UTF-8" "de_DE.UTF-8" ];
```

### `keyboardLayout`

**Type**: `str`
**Default**: `"us"`
**Description**: Keyboard layout (e.g., "us", "de", "fr")
**Example**:
```nix
keyboardLayout = "de";
```

### `keyboardOptions`

**Type**: `str`
**Default**: `""`
**Description**: Keyboard options (e.g., "terminate:ctrl_alt_bksp")
**Example**:
```nix
keyboardOptions = "terminate:ctrl_alt_bksp";
```

### `timeZone`

**Type**: `str`
**Default**: `"Europe/Berlin"`
**Description**: System timezone (IANA format)
**Example**:
```nix
timeZone = "America/New_York";
```

## Advanced Topics

### Locale Configuration

The module configures system locales:
- **Default Locale**: First locale in the list is used as default
- **UTF-8 Support**: All locales use UTF-8 encoding
- **Multiple Locales**: Can specify multiple locales for different applications

### Keyboard Configuration

The module configures keyboard settings:
- **Layout**: Keyboard layout (e.g., "us", "de", "fr")
- **Options**: Keyboard options (e.g., "terminate:ctrl_alt_bksp")
- **System-Wide**: Applied system-wide for all users

### Timezone Configuration

The module configures system timezone:
- **Timezone Format**: IANA timezone format (e.g., "Europe/Berlin")
- **System-Wide**: Applied system-wide
- **Automatic Updates**: Timezone changes apply immediately

## Integration with Other Modules

### Integration with User Module

The localization module works with user settings:
```nix
{
  localization = {
    locales = [ "en_US.UTF-8" "de_DE.UTF-8" ];
  };
  user = {
    # User-specific locale preferences can be set here
  };
}
```

## Troubleshooting

### Common Issues

**Issue**: Locale not available
**Symptoms**: Locale not found or not generated
**Solution**: 
1. Ensure locale is generated in NixOS configuration
2. Check locale format is correct (e.g., "en_US.UTF-8")
3. Verify locale data is available
**Prevention**: Use standard locale formats

**Issue**: Keyboard not working
**Symptoms**: Wrong keyboard layout or keys not working
**Solution**: 
1. Check keyboard layout matches your hardware
2. Verify keyboard layout name is correct
3. Test keyboard layout: `localectl status`
**Prevention**: Use correct keyboard layout names

**Issue**: Timezone wrong
**Symptoms**: System time incorrect
**Solution**: 
1. Verify timezone format is correct (IANA format)
2. Check timezone data: `timedatectl status`
3. Ensure timezone is set correctly
**Prevention**: Use IANA timezone format

### Debug Commands

```bash
# Check current locale
locale

# Check available locales
locale -a

# Check keyboard layout
localectl status

# Check timezone
timedatectl status
```

## Performance Tips

- Use only necessary locales (reduces build time)
- Keep timezone data updated
- Use standard keyboard layouts for best compatibility

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
