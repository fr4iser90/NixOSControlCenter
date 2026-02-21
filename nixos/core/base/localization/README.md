# Localization System

A core NixOS Control Center module that provides system localization and internationalization configuration. This module manages locales, keyboard layouts, timezone, and regional settings.

## Overview

The Localization System module is a **core module** that manages system-wide localization settings for NixOS. It configures locales, keyboard layouts, timezone, and other regional preferences.

## Features

- **Multiple Locales**: Support for multiple locale configurations
- **Keyboard Layouts**: Configurable keyboard layouts and options
- **Timezone Management**: System timezone configuration
- **Regional Settings**: Locale-specific settings and formats
- **System Integration**: Proper integration with NixOS localization services

## Architecture

### File Structure

```
localization/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
└── template-config.nix          # Default configuration template
```

## Configuration

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

## Technical Details

### Locales

The module configures system locales:

- **Default Locale**: First locale in the list is used as default
- **UTF-8 Support**: All locales use UTF-8 encoding
- **Multiple Locales**: Can specify multiple locales for different applications

### Keyboard Configuration

The module configures keyboard settings:

- **Layout**: Keyboard layout (e.g., "us", "de", "fr")
- **Options**: Keyboard options (e.g., "terminate:ctrl_alt_bksp")
- **System-Wide**: Applied system-wide for all users

### Timezone

The module configures system timezone:

- **Timezone Format**: IANA timezone format (e.g., "Europe/Berlin")
- **System-Wide**: Applied system-wide
- **Automatic Updates**: Timezone changes apply immediately

## Usage

### Basic Configuration

1. Edit your localization configuration:
   ```nix
   {
     localization = {
       locales = [ "en_US.UTF-8" ];
       keyboardLayout = "us";
       timeZone = "America/New_York";
     };
   }
   ```

2. Rebuild system:
   ```bash
   sudo nixos-rebuild switch
   ```

### Multiple Locales

```nix
{
  localization = {
    locales = [
      "en_US.UTF-8"  # Default locale
      "de_DE.UTF-8"  # German locale
      "fr_FR.UTF-8"  # French locale
    ];
  };
}
```

### Keyboard Options

```nix
{
  localization = {
    keyboardLayout = "de";
    keyboardOptions = "terminate:ctrl_alt_bksp";  # Ctrl+Alt+Backspace to terminate X
  };
}
```

## Dependencies

- **glibc**: Locale data
- **tzdata**: Timezone data

## Troubleshooting

### Common Issues

1. **Locale Not Available**: Ensure locale is generated in NixOS configuration
2. **Keyboard Not Working**: Check keyboard layout matches your hardware
3. **Timezone Wrong**: Verify timezone format is correct

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

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Simple Configuration**: Direct NixOS option mapping
- **System Integration**: Proper integration with NixOS localization
- **Validation**: Input validation for locale and timezone formats

## Related Components

- **User Module**: User-specific locale preferences
- **Desktop Module**: Desktop environment locale integration
