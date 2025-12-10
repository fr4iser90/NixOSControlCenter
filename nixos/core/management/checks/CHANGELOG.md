# Changelog

All notable changes to the checks module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-09

### Added
- Complete restructuring to follow MODULE_TEMPLATE.md
- Proper separation of concerns: default.nix (imports only), config.nix (implementation)
- Versioning support with `_version` option
- User configuration file `checks-config.nix` with symlink management
- Shared utilities in `lib/` directory (types.nix, utils.nix)
- Comprehensive README.md documentation
- Prebuild and postbuild check organization
- Automatic symlink management for user config files

### Changed
- **BREAKING**: Moved options from `system.postbuild` to `systemConfig.management.checks.postbuild`
- **BREAKING**: Changed command registration from `core.command-center.commands` to `core.command-center.commands`
- **BREAKING**: Moved implementation from multiple files to single `config.nix`
- Restructured module to follow unified architecture pattern
- Consolidated prebuild and postbuild logic into config.nix
- Updated namespace usage throughout module

### Removed
- Legacy `default.nix` config blocks (implementation moved to config.nix)
- Legacy `postbuild/default.nix` (archived as `postbuild/old-default.nix`)
- Legacy `prebuild/default.nix` (archived as `prebuild/old-default.nix`)
- Direct option definitions in sub-modules

### Technical Details
- Module now properly implements management module pattern
- All implementation logic consolidated in `config.nix`
- Options properly defined in `options.nix`
- User config symlinked to `/etc/nixos/configs/checks-config.nix`
- Added proper assertions and validation
- Maintained all existing check functionality
- Improved error handling and user feedback
