# TUI Engine Implementation Plan

## Overview

The TUI Engine is a generic Bubble Tea TUI builder for all NixOS Control Center modules. It provides templates and utilities to create consistent, professional TUIs across different managers.

## Architecture Decision: Template System

After analysis of three options, we chose **Template System** as the best long-term solution:

### Why Template System?

**Advantages:**
- **Flexibility**: Each module chooses optimal template
- **Consistency**: Standardized layouts ensure predictable UX
- **Maintainability**: Centralized template management
- **Scalability**: Easy to add new templates for future modules
- **Professional**: Balances implementation simplicity with UX quality

**Template Types:**
- **2-Panel**: Simple menu + content (basic modules)
- **3-Panel**: Menu + content + info (standard modules)
- **4-Panel**: Menu + content + sidebar + stats (complex modules)
- **5-Panel**: Menu + list + filter + info + actions (advanced modules)

## TUI Engine API

```nix
# Generic TUI builder
tuiEngine.buildTUI {
  name = "module-name";
  goCode = customBubbleTeaCode;
  discoveryScript = moduleDiscoveryScript;
  inherit pkgs;
}

# Template system (future extension)
tuiEngine.templates."4-panel" {
  menu = menuComponent;
  content = contentComponent;
  sidebar = sidebarComponent;
  stats = statsComponent;
}
```

## Module-Specific TUI Designs

### System Manager (4-Panel)

```
┌─────────────────────────────────────────────────┐
│ 🔧 System Manager | nixos@nixos-vm | Online     │
├─────────────┬─────────────────────┬─────────────┤
│ 📊 MENU    │ 📈 SYSTEM STATUS      │ 🔧 SERVICES │
│ • 📈 Status│ CPU: ████████░░ 75% │ • nginx    │
│ • 🔧 Services│ RAM: ████████░░ 68% │ • sshd     │
│ • 💾 Storage│ DISK: ████░░░░░░ 28% │ • systemd   │
│ • 🔒 Security│ TEMP: 45°C          │ • NetworkMgr│
│ • 📊 Monitor│ UPTIME: 2d 4h 12m  │ • docker    │
│ • ⚙️ Settings│ LOAD: 1.2 0.8 0.5   │ • bluetooth │
└─────────────┴─────────────────────┴─────────────┘
```

### Module Manager (5-Panel)

```
┌─────────────────────────────────────────────────┐
│ 📦 Module Manager | 18 modules | 15 enabled    │
├───────┬─────────────────────┬───────┬───────────┤
│ 📋   │ 📦 MODULE LIST        │ 🔍   │ 📊 STATS  │
│ MENU │ ✅ audio v1.0.0 core   │ FILTER│ 15/18    │
│ • 📋│ ✅ boot v1.0.0 core    │ [ ]   │ enabled   │
│ • ✅│ ✅ desktop v1.0.0 core │ core  │ 3/18      │
│ • ❌│ ✅ hardware v1.0.0 core│ [x]   │ disabled  │
│ • 🔄│ ✅ network v1.0.0 core │       │ 0/18      │
│ • ⚙️│ ✅ packages v1.0.0 core│       │ pending   │
└───────┴─────────────────────┴───────┴───────────┘
```

### Network Manager (4-Panel)

```
┌─────────────────────────────────────────────────┐
│ 🌐 Network Manager | eth0 | 192.168.122.100    │
├─────────────┬─────────────────────┬─────────────┤
│ 🔗 MENU    │ 🌐 INTERFACE STATUS   │ 📊 TRAFFIC │
│ • 🌐 Status│ eth0: UP 192.168.122.│ ↑ 2.3MB/s │
│ • ⚙️ Config│ wlan0: DOWN         │ ↓ 1.8MB/s │
│ • 🛡️ Firewall│ lo: UP 127.0.0.1   │            │
│ • 📊 Monitor│ Firewall: active     │ 🔥 RULES  │
└─────────────┴─────────────────────┴─────────────┘
```

### Package Manager (5-Panel)

```
┌─────────────────────────────────────────────────┐
│ 💾 Package Manager | 1245 packages | Updated    │
├───────┬─────────────────────┬───────┬───────────┤
│ 📦   │ 📦 INSTALLED PACKAGES │ 🔄   │ 📊 INFO   │
│ MENU │ nix-2.15.0           │ UPDATES│ nix 2.15.0│
│ • 📦│ glibc-2.37           │ [12]  │ glibc 2.37│
│ • 📥│ systemd-253.6        │       │ systemd 253│
│ • 🔄│ firefox-115.0.2      │       │ firefox 115│
└───────┴─────────────────────┴───────┴───────────┘
```

## Implementation Structure

```
nixos/core/management/tui-engine/
├── api.nix                 # Public API (buildTUI, templates)
├── components/
│   └── tui-engine/
│       └── default.nix     # Core build functions
├── options.nix            # Module configuration
├── config.nix             # API setup
└── default.nix            # Module metadata
```

## Module Usage Pattern

```nix
# In any module's TUI
{ lib, pkgs, getModuleApi, discoveryScript }:

let
  tuiEngine = getModuleApi "tui-engine";
  myGoCode = ''
    // Custom Bubble Tea code for this module
    package main
    // ... TUI implementation
  '';
in
  tuiEngine.buildTUI {
    name = "my-module";
    goCode = myGoCode;
    inherit discoveryScript pkgs;
  }
```

## Navigation Standards

**Global Shortcuts:**
- `q` / `Ctrl+C` = Quit
- `Tab` = Switch between panels
- `↑↓` / `jk` = Navigate within panel
- `Enter` = Select/Execute
- `Esc` = Back/Cancel
- `r` = Refresh
- `/` = Search

**Panel-Specific:**
- **Menu Panel**: `↑↓` navigation, `Enter` select
- **Content Panel**: `↑↓` scroll, `Enter` action
- **Filter Panel**: `↑↓` select filters, `Space` toggle

## Future Extensions

1. **Template System Implementation**
   - Add template definitions to TUI engine
   - Allow modules to choose templates
   - Standardized panel layouts

2. **Theme System**
   - Color schemes (dark/light/custom)
   - Icon sets
   - Responsive layouts

3. **Component Library**
   - Reusable UI components
   - Standard widgets (lists, tables, forms)
   - Consistent styling

4. **Accessibility**
   - Keyboard navigation
   - Screen reader support
   - High contrast modes

## Integration Points

- **Module Discovery**: Each module provides its own discovery script
- **CLI Registry**: TUIs registered as commands via cli-registry
- **API Access**: TUIs available via `getModuleApi "module-name"`
- **Configuration**: Module settings via standard options system

## Testing Strategy

1. **Unit Tests**: Template rendering, component behavior
2. **Integration Tests**: End-to-end TUI workflows
3. **Compatibility Tests**: Different terminal sizes, themes
4. **Performance Tests**: Large data sets, complex layouts

This implementation provides a solid foundation for consistent, professional TUIs across all NixOS Control Center modules while maintaining flexibility for future enhancements.
