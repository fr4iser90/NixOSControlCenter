# Audio System

A core NixOS Control Center module that provides comprehensive audio system management. This module supports multiple audio systems (PipeWire, PulseAudio, ALSA) and provides a unified configuration interface.

## Overview

The Audio System module is a **core module** that manages audio services and configurations for NixOS. It supports multiple audio backends and provides a simple interface to switch between different audio systems.

## Features

- **Multiple Audio Systems**: Support for PipeWire, PulseAudio, and ALSA
- **Automatic Configuration**: Dynamic loading of appropriate audio system configuration
- **Audio Tools**: Common audio utilities and control applications
- **System Integration**: Proper integration with NixOS audio services

## Architecture

### File Structure

```
audio/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── audio-config.nix             # User configuration (symlinked)
└── providers/                   # Audio system implementations
    ├── pipewire.nix            # PipeWire audio system
    ├── pulseaudio.nix          # PulseAudio audio system
    └── alsa.nix                # ALSA audio system
```

### Audio Systems

#### PipeWire (`system = "pipewire"`)
- Modern audio system with low latency capabilities
- PulseAudio compatibility layer
- WirePlumber session manager
- Recommended for most users

#### PulseAudio (`system = "pulseaudio"`)
- Traditional Linux audio system
- Wide application compatibility
- Network audio support
- Legacy support

#### ALSA (`system = "alsa"`)
- Low-level audio interface
- Minimal resource usage
- Direct hardware access
- For advanced users

#### None (`system = "none"`)
- No audio system configured
- Minimal audio support only

## Configuration

As a core module, the audio system is enabled by default. Configure it through the user config:

```nix
{
  audio = {
    enable = true;           # Enable audio system (default: true)
    system = "pipewire";     # Audio system: "pipewire", "pulseaudio", "alsa", "none"
  };
}
```

## Technical Details

### Dynamic Loading

The module dynamically loads the appropriate audio system configuration based on the `system` option:

- **default.nix**: Conditionally imports the selected audio system provider
- **providers/**: Contains specific configurations for each audio system
- **Validation**: Ensures only valid audio systems are selected

### Common Packages

Regardless of the selected audio system, the following packages are always available:
- `pavucontrol`: Audio control GUI
- `pamixer`: Command-line volume control

### System Integration

Each audio system provider:
- Configures appropriate NixOS services
- Sets up necessary packages
- Manages service dependencies
- Provides system-wide audio capabilities

## Usage

### Switching Audio Systems

1. Edit `audio-config.nix`:
   ```nix
   {
     audio = {
       system = "pulseaudio";  # Change from pipewire to pulseaudio
     };
   }
   ```

2. Rebuild system:
   ```bash
   sudo nixos-rebuild switch
   ```

### Audio Control

- **GUI**: Use `pavucontrol` for graphical audio control
- **CLI**: Use `pamixer` for command-line volume control
- **System**: Audio settings are applied system-wide

## Dependencies

- **PipeWire**: `pipewire`, `wireplumber`
- **PulseAudio**: `pulseaudioFull`
- **ALSA**: `alsa-utils`, `alsa-tools`, `alsa-plugins`

## Troubleshooting

### Common Issues

1. **No Audio**: Check if audio system is enabled and correct system selected
2. **Application Issues**: Some applications may need specific audio system
3. **Bluetooth Audio**: Ensure PipeWire or PulseAudio for Bluetooth support

### Debug Commands

```bash
# Check audio services
systemctl --user status pipewire.service
systemctl status pulseaudio.service

# List audio devices
aplay -l
pactl list sinks
```

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Provider Pattern**: Different audio systems as providers
- **Dynamic Loading**: Runtime selection of audio system
- **Configuration Validation**: Input validation for audio system selection
- **Clean Separation**: System-specific logic in separate provider files
