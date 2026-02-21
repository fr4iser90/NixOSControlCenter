# Audio System - Architecture

## Overview

High-level architecture description of the Audio System module.

## Components

### Module Structure

```
audio/
├── README.md                    # Module overview
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── audio-config.nix             # User configuration (symlinked)
└── handlers/                    # Audio system implementations
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

## Design Decisions

### Decision 1: Provider Pattern

**Context**: Need to support multiple audio systems with different configurations
**Decision**: Use provider pattern with separate files for each audio system
**Rationale**: Clean separation of concerns, easy to add new audio systems
**Alternatives**: Single file with conditionals (rejected - too complex)

### Decision 2: Dynamic Loading

**Context**: Audio system selection at runtime
**Decision**: Conditionally import audio system provider based on configuration
**Rationale**: Only load what's needed, cleaner module structure
**Trade-offs**: Slightly more complex default.nix, but better maintainability

## Data Flow

```
User Config → options.nix → default.nix → Provider Selection → Audio System Config
```

## Dependencies

### Internal Dependencies
- `core.management.module-manager` - Module configuration management

### External Dependencies
- `nixpkgs.pipewire` - PipeWire audio system
- `nixpkgs.pulseaudioFull` - PulseAudio audio system
- `nixpkgs.alsa-utils` - ALSA utilities

## Extension Points

How other modules can extend this module:
- Custom audio system providers can be added to `handlers/`
- Audio configuration can be extended via options

## Performance Considerations

- PipeWire provides low latency audio
- Common packages (pavucontrol, pamixer) always available
- Minimal overhead for audio system selection

## Security Considerations

- Audio system permissions
- User access to audio devices
- Service isolation
