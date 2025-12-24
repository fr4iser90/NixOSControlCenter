# Changelog

All notable changes to the command-center module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-09

### Added
- Complete restructuring to follow MODULE_TEMPLATE.md
- Proper separation of concerns: default.nix (imports only), config.nix (implementation)
- Versioning support with `_version` option
- User configuration file `command-center-config.nix` with symlink management
- Shared utilities in `lib/` directory (types.nix, utils.nix)
- Comprehensive README.md documentation
- Automatic command categorization
- Symlink management for user config files

### Changed
- **BREAKING**: Moved options from `options.core.command-center` to `options.systemConfig.command-center`
- **BREAKING**: Changed namespace from `config.core.management.system-manager.submodules.cli-registry` to `systemConfig.command-center`
- Restructured module to follow unified architecture pattern
- Moved CLI implementation from `cli/default.nix` to `config.nix`
- Moved command types from `registry/types.nix` to `lib/types.nix`
- Created utility functions in `lib/utils.nix`

### Removed
- Legacy `cli/default.nix` (archived as `cli/old-default.nix`)
- Legacy `registry/default.nix` (archived as `registry/old-default.nix`)

### Technical Details
- Module now properly implements core module pattern
- All implementation logic moved to `config.nix`
- Options properly defined in `options.nix`
- User config symlinked to `/etc/nixos/configs/command-center-config.nix`
- Added proper assertions and validation
