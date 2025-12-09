# Changelog

All notable changes to the Audio System module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Audio System core module
- Support for multiple audio systems: PipeWire, PulseAudio, and ALSA
- Dynamic audio system selection and configuration loading
- Symlink management for user configuration
- Comprehensive audio tools and utilities
- Provider-based architecture for audio system implementations

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created providers/ directory for audio system implementations
- Added symlink management for centralized config access
- Implemented validation for audio system selection
- Added version tracking with `_version` option

### Audio Systems
- **PipeWire**: Modern audio system with low latency and PulseAudio compatibility
- **PulseAudio**: Traditional audio system with wide application support
- **ALSA**: Low-level audio interface for advanced users
- **None**: Minimal audio configuration option

### Configuration
- Dynamic loading based on `system` option ("pipewire", "pulseaudio", "alsa", "none")
- User configuration via `audio-config.nix` symlink
- Validation of audio system selection
- Default system: PipeWire

### Features
- **PipeWire**: Low-latency audio with WirePlumber session manager
- **PulseAudio**: Network audio and legacy application support
- **ALSA**: Direct hardware access with comprehensive utilities
- **Common Tools**: pavucontrol GUI and pamixer CLI for all systems

### Dependencies
- PipeWire: `pipewire`, `wireplumber`, `qpwgraph`
- PulseAudio: `pulseaudioFull`
- ALSA: `alsa-utils`, `alsa-tools`, `alsa-plugins`
- Common: `pavucontrol`, `pamixer`

### Documentation
- Added comprehensive README.md with usage instructions
- Created CHANGELOG.md for version tracking
- Provider-based architecture documentation
