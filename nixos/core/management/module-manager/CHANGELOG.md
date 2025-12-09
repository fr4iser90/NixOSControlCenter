# Changelog

All notable changes to the Module Manager module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Module Manager core module
- Dynamic module discovery from `systemConfig.system.*`, `systemConfig.management.*`, and `systemConfig.features.*`
- Interactive fzf-based interface for module toggling (`ncc module-manager` command)
- Automatic configuration file generation for different module categories
- Real-time module status display
- Automatic system rebuild after module changes
- Symlink management for user configuration
- Utility library functions in `lib/default.nix`
- Comprehensive documentation and README

### Technical
- Implemented proper MODULE_TEMPLATE structure with separation of concerns
- Created module-manager-config.nix for future extensibility
- Added symlink management in config.nix for centralized config access
- Extracted utility functions from handlers to dedicated lib/ directory
- Added version tracking with `_version` option in options.nix

### Categories Supported
- **System modules**: Core OS functionality (default enabled)
- **Management modules**: System management tools (default enabled)
- **Feature modules**: Optional user features (default disabled)

### Dependencies
- `fzf`: Interactive fuzzy finder for module selection
- `nix`: For configuration evaluation and system rebuilds
- `bash`: Shell environment for script execution
