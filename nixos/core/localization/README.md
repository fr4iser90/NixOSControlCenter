# Localization Module

The localization module manages system-wide locale and keyboard configuration.

## Overview

This module configures:
- System locales (language and region settings)
- Keyboard layout and options
- Console keymap
- X11/Wayland keyboard settings

## Configuration

Edit `/etc/nixos/configs/localization-config.nix` (symlink to `core/localization/user-configs/localization-config.nix`):

```nix
{
  localization = {
    locales = [ "de_DE.UTF-8" "en_US.UTF-8" ];
    keyboardLayout = "de";
    keyboardOptions = "terminate";
  };
}
```

## Options

### `locales`
- **Type**: `listOf str`
- **Default**: `[ "en_US.UTF-8" ]`
- **Description**: List of supported locales

### `keyboardLayout`
- **Type**: `str`
- **Default**: `"us"`
- **Description**: Keyboard layout (e.g., `"us"`, `"de"`, `"fr"`)

### `keyboardOptions`
- **Type**: `str`
- **Default**: `""`
- **Description**: Keyboard options (e.g., `"terminate:ctrl_alt_bksp"`)

## Usage

The module is always active (no `enable` option needed). Configuration is loaded from `localization-config.nix` and applied to:
- `i18n.defaultLocale` - System default locale
- `i18n.extraLocaleSettings` - Additional locale settings (LC_TIME, LC_MONETARY, etc.)
- `i18n.supportedLocales` - List of available locales
- `console.keyMap` - Console keyboard layout
- `services.xserver.xkb` - X11/Wayland keyboard settings

## Examples

### German Locale with German Keyboard
```nix
{
  localization = {
    locales = [ "de_DE.UTF-8" ];
    keyboardLayout = "de";
    keyboardOptions = "terminate";
  };
}
```

### Multiple Locales (German + English)
```nix
{
  localization = {
    locales = [ "de_DE.UTF-8" "en_US.UTF-8" ];
    keyboardLayout = "de";
    keyboardOptions = "";
  };
}
```

### US Keyboard with Custom Options
```nix
{
  localization = {
    locales = [ "en_US.UTF-8" ];
    keyboardLayout = "us";
    keyboardOptions = "terminate:ctrl_alt_bksp";
  };
}
```

