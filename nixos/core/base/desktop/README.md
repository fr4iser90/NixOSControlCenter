## Desktop Configuration

The desktop configuration module provides a declarative way to configure various desktop components in NixOS. It is conditionally enabled through `systemConfig.core.base.desktop.enable`.

### Components

When enabled, the following components are configured:

1. **Display Managers**
   - GDM
   - LightDM
   - SDDM

2. **Display Servers**
   - Wayland
   - X11
   - Hybrid

3. **Desktop Environments**
   - GNOME
   - Plasma (KDE)
   - XFCE

4. **Themes**
   - Color Schemes
   - Cursors
   - Fonts
   - Icons

### Configuration Options

The module provides the following configuration options through `systemConfig.desktop`:

- `enable`: Boolean to enable/disable desktop configuration
- `keyboardLayout`: Default keyboard layout (default: "us")
- `keyboardOptions`: Additional keyboard options
- `display.server`: Display server (wayland, x11, hybrid)
- `environment`: Desktop environment (plasma, gnome, xfce)
- `display.manager`: Display manager (sddm, gdm, lightdm)

### Keyboard Configuration

Global keyboard settings are configured through:
- `console.keyMap`
- Environment variables:
  - `XKB_DEFAULT_LAYOUT`
  - `XKB_DEFAULT_OPTIONS`
- X server keyboard settings

### Services

- D-Bus service enabled with broker implementation

### Validation

The configuration includes assertions to validate:
- Display server selection
- Desktop environment selection
- Display manager selection
