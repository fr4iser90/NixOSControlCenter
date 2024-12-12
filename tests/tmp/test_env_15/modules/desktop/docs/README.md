# Desktop Environment Module

## Overview
This module manages the complete desktop environment configuration for NixOS, including GPU drivers, display servers, and desktop environments.

## Configuration
Configure through `env.nix` with the following options:

### Required Settings
- `gpu`: GPU driver configuration
  - `"nvidia"`: NVIDIA proprietary drivers
  - `"nvidiaIntelPrime"`: NVIDIA+Intel hybrid graphics
  - `"intel"`: Intel integrated graphics
  - `"amdgpu"`: AMD graphics (default)

- `desktop`: Desktop environment
  - `"plasma"`: KDE Plasma
  - `"gnome"`: GNOME
  - `"xfce"`: XFCE

- `displayManager`: Login manager
  - `"sddm"`: Simple Desktop Display Manager
  - `"gdm"`: GNOME Display Manager
  - `"lightdm"`: Light Display Manager

### Optional Settings
- `session`: Desktop session type
  - `"plasma"`: KDE Plasma X11
  - `"plasmawayland"`: KDE Plasma Wayland
  - `"gnome"`: GNOME
  - `"xfce"`: XFCE
  - `"i3"`: i3 Window Manager

- `keyboardLayout`: Keyboard layout (e.g., "de", "us")
- `keyboardOptions`: Additional keyboard options

## Structure

desktop/
├── hardware/
│ └── gpu/ # GPU-specific configurations
├── display/
│ ├── x11/ # X11 display server
│ └── wayland/ # Wayland display server
├── managers/
│ ├── display/ # Display manager configurations
│ └── desktop/ # Desktop environment settings
└── themes/ # Theme and appearance settings
