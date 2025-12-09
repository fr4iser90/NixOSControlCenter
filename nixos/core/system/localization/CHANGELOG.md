# Changelog

All notable changes to the Localization System module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Localization System core module
- Comprehensive locale configuration with automatic language code extraction
- Keyboard layout and options configuration for console and X11/Wayland
- Symlink management for user configuration
- Intelligent locale settings generation

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Added symlink management for centralized config access
- Implemented automatic language code extraction from locale strings
- Added version tracking with `_version` option

### Locale Configuration
- **Default Locale**: Automatically set from first locale in list
- **Extra Locales**: All locales except default are added as supported locales
- **Extra Settings**: Automatic LC_* settings (TIME, MONETARY, PAPER, NAME, ADDRESS, TELEPHONE, MEASUREMENT)
- **Language Fallback**: Automatic LANGUAGE setting with fallback to en_US

### Keyboard Configuration
- **Console Keymap**: Automatic mapping from keyboard layout
- **X11/Wayland**: Unified keyboard settings for both display servers
- **Keyboard Options**: Support for special keyboard options (terminate, etc.)

### Configuration
- User configuration via `localization-config.nix` symlink
- Support for multiple locales with intelligent priority handling
- Keyboard layout validation and mapping

### Features
- **Always Active**: No enable option needed - localization is always configured
- **Intelligent Defaults**: Sensible defaults for common use cases
- **Multi-locale Support**: Support for multiple locales with proper fallback
- **Cross-platform**: Works for console, X11, and Wayland environments

### Examples Supported
- **Single Locale**: `["de_DE.UTF-8"]` with German keyboard
- **Multi-locale**: `["de_DE.UTF-8" "en_US.UTF-8"]` with German primary, English fallback
- **Custom Options**: Keyboard options like `"terminate:ctrl_alt_bksp"`

### Documentation
- Added comprehensive README.md with configuration examples
- Created CHANGELOG.md for version tracking
- Included usage examples for common localization scenarios
