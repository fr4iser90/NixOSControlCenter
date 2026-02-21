# Desktop System - Usage Guide

## Basic Usage

### Enabling the Module

As a core module, the desktop system can be enabled/disabled:

```nix
{
  enable = true;              # Enable desktop environment (default: true)
  environment = "plasma";     # Desktop environment: "plasma", "gnome", "xfce"
  display = {
    manager = "sddm";         # Display manager: "sddm", "gdm", "lightdm"
    server = "wayland";       # Display server: "wayland", "x11", "hybrid"
  };
  theme = {
    dark = true;              # Use dark theme (default: true)
  };
}
```

## Common Use Cases

### Use Case 1: Modern Desktop with Plasma

**Scenario**: Modern desktop system, want customizable environment
**Configuration**:
```nix
{
  enable = true;
  environment = "plasma";
  display = {
    manager = "sddm";
    server = "wayland";
  };
}
```
**Result**: Modern KDE Plasma desktop with Wayland

### Use Case 2: Productivity Desktop with GNOME

**Scenario**: Productivity-focused, want clean interface
**Configuration**:
```nix
{
  enable = true;
  environment = "gnome";
  display = {
    manager = "gdm";
    server = "wayland";
  };
}
```
**Result**: Clean GNOME desktop with excellent Wayland support

### Use Case 3: Lightweight Desktop with XFCE

**Scenario**: Older hardware, need lightweight environment
**Configuration**:
```nix
{
  enable = true;
  environment = "xfce";
  display = {
    manager = "lightdm";
    server = "x11";
  };
}
```
**Result**: Lightweight XFCE desktop with X11

## Configuration Options

### `enable`

**Type**: `bool`
**Default**: `true`
**Description**: Enable desktop environment
**Example**:
```nix
enable = true;
```

### `environment`

**Type**: `enum [ "plasma" "gnome" "xfce" ]`
**Default**: `"plasma"`
**Description**: Desktop environment to use
**Example**:
```nix
environment = "gnome";
```

### `display.manager`

**Type**: `enum [ "sddm" "gdm" "lightdm" ]`
**Default**: `"sddm"`
**Description**: Display manager
**Example**:
```nix
display.manager = "gdm";
```

### `display.server`

**Type**: `enum [ "wayland" "x11" "hybrid" ]`
**Default**: `"wayland"`
**Description**: Display server
**Example**:
```nix
display.server = "x11";
```

### `theme.dark`

**Type**: `bool`
**Default**: `true`
**Description**: Use dark theme
**Example**:
```nix
theme.dark = false;
```

## Advanced Topics

### Switching Desktop Environments

1. Edit your desktop configuration:
   ```nix
   {
     environment = "gnome";  # Change from plasma to gnome
     display = {
       manager = "gdm";      # Use GDM for GNOME
       server = "wayland";    # Use Wayland
     };
   }
   ```

2. Rebuild system:
   ```bash
   sudo nixos-rebuild switch
   ```

3. Log out and log back in to see the new desktop environment

### Theme Configuration

```nix
{
  theme = {
    dark = false;  # Use light theme
  };
}
```

## Integration with Other Modules

### Integration with Audio Module

The desktop module works with audio systems:
```nix
{
  enable = true;
  environment = "plasma";
}
```

## Troubleshooting

### Common Issues

**Issue**: Display issues after switching environments
**Symptoms**: Screen blank or display not working
**Solution**: 
1. Check display server compatibility with your hardware
2. Verify display manager is correctly configured
3. Try switching to X11 if Wayland doesn't work
**Prevention**: Test display server compatibility before switching

**Issue**: Login problems
**Symptoms**: Can't log in or display manager not starting
**Solution**: 
1. Verify display manager is correctly configured
2. Check display manager service: `systemctl status display-manager.service`
3. Verify user account is properly configured
**Prevention**: Ensure display manager matches desktop environment

**Issue**: Theme not applied
**Symptoms**: Theme changes not visible
**Solution**: 
1. Ensure theme configuration is correct
2. Restart desktop environment
3. Check theme files are accessible
**Prevention**: Use supported theme formats

### Debug Commands

```bash
# Check display server
echo $XDG_SESSION_TYPE

# Check desktop environment
echo $XDG_CURRENT_DESKTOP

# Check display manager
systemctl status display-manager.service
```

## Performance Tips

- Use Wayland for modern systems (better performance)
- Use X11 for legacy hardware or compatibility
- Use lightweight environments (XFCE) for older hardware
- Keep desktop environment updated for best performance

## See Also

- [Architecture](./ARCHITECTURE.md) - System architecture
- [README.md](../README.md) - Module overview
