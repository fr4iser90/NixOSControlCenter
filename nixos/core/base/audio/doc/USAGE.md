# Audio System - Usage Guide

## Basic Usage

### Enabling the Module

As a core module, the audio system is enabled by default:

```nix
{
  enable = true;           # Enable audio system (default: true)
  system = "pipewire";     # Audio system: "pipewire", "pulseaudio", "alsa", "none"
}
```

## Common Use Cases

### Use Case 1: Modern System with PipeWire

**Scenario**: Modern desktop system, want low latency audio
**Configuration**:
```nix
{
  enable = true;
  system = "pipewire";
}
```
**Result**: Modern audio system with low latency and PulseAudio compatibility

### Use Case 2: Legacy System with PulseAudio

**Scenario**: Older system or need wide application compatibility
**Configuration**:
```nix
{
  enable = true;
  system = "pulseaudio";
}
```
**Result**: Traditional audio system with wide compatibility

### Use Case 3: Minimal System with ALSA

**Scenario**: Minimal system, direct hardware access needed
**Configuration**:
```nix
{
  enable = true;
  system = "alsa";
}
```
**Result**: Low-level audio interface with minimal overhead

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `true`
**Description**: Enable audio system
**Example**:
```nix
enable = true;
```

### `system`

**Type**: `enum [ "pipewire" "pulseaudio" "alsa" "none" ]`
**Default**: `"pipewire"`
**Description**: Audio system to use
**Example**:
```nix
system = "pulseaudio";
```

## Advanced Topics

### Switching Audio Systems

1. Edit your audio configuration:
   ```nix
   {
     system = "pulseaudio";  # Change from pipewire to pulseaudio
   }
   ```

2. Rebuild system:
   ```bash
   sudo nixos-rebuild switch
   ```

3. Restart audio services if needed

### Audio Control

- **GUI**: Use `pavucontrol` for graphical audio control
- **CLI**: Use `pamixer` for command-line volume control
- **System**: Audio settings are applied system-wide

## Integration with Other Modules

### Integration with Desktop Module

The audio module works with desktop environments:
```nix
{
  enable = true;
  system = "pipewire";
}
```

## Troubleshooting

### Common Issues

**Issue**: No audio output
**Symptoms**: No sound from speakers/headphones
**Solution**: 
1. Check if audio system is enabled: `systemctl --user status pipewire.service`
2. Verify correct audio system selected
3. Check audio device: `aplay -l`
**Prevention**: Ensure audio system matches your hardware

**Issue**: Application can't access audio
**Symptoms**: Application shows no audio devices
**Solution**: 
1. Check if application needs specific audio system
2. Verify audio services are running
3. Check user permissions for audio devices
**Prevention**: Use PipeWire for best compatibility

**Issue**: Bluetooth audio not working
**Symptoms**: Bluetooth devices not showing as audio output
**Solution**: 
1. Ensure PipeWire or PulseAudio is used (ALSA doesn't support Bluetooth well)
2. Check Bluetooth service: `systemctl status bluetooth`
3. Verify audio system Bluetooth support
**Prevention**: Use PipeWire for Bluetooth audio

### Debug Commands

```bash
# Check audio services
systemctl --user status pipewire.service
systemctl status pulseaudio.service

# List audio devices
aplay -l
pactl list sinks

# Check audio system
pactl info  # PulseAudio/PipeWire
```

## Performance Tips

- Use PipeWire for modern systems (low latency)
- Use PulseAudio for maximum compatibility
- Use ALSA only for minimal systems
- Keep audio services running for best performance

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
