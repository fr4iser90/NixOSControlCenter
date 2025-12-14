# CLI Formatter Module

This module provides comprehensive CLI formatting and user interface utilities for NixOS Control Center infrastructure.

## Overview

The CLI formatter serves as a shared infrastructure service providing standardized text formatting, colors, tables, progress bars, and UI components that other modules can use for consistent output across the entire system.

## Features

- **Text Formatting**: Colors, styles, and layout utilities
- **UI Components**: Boxes, tables, lists, progress bars, spinners
- **Interactive Elements**: Prompts, status messages, badges
- **Infrastructure Service**: Always available, no enable/disable requirement
- **Theme Support**: Configurable colors and styles

## Architecture

### File Structure
```
cli-formatter/
├── README.md                 # This documentation
├── default.nix               # Module imports (ONLY)
├── options.nix               # Configuration options
├── config.nix                # Implementation & API definition
├── colors.nix                # Color definitions
├── components/               # UI components
├── core/                     # Core formatting functions
├── interactive/              # Interactive elements
├── status/                   # Status indicators
└── cli-formatter-config.nix  # User configuration
    
```

### Module Structure Alignment
Following the standard NixOS Control Center module template:
- **default.nix**: Pure imports only
- **options.nix**: Option definitions with versioning
- **config.nix**: All implementation logic and API exposure

## Usage

### For Other Modules
```nix
# In any module that needs formatting
{ config, ... }:
let
  ui = config.core.management.system-manager.submodules.cli-formatter.api;
in {
  # Use the formatting API
  messages = ui.messages.success "Operation completed";

  # Use tables
  table = ui.tables.basic {
    headers = [ "Name" "Status" ];
    rows = [ [ "Service A" "Running" ] [ "Service C" "Stopped" ] ];
  };
}
```

### Available API Components

#### Colors & Styling
```nix
ui.colors.green "Success text"
ui.colors.red "Error text"
ui.colors.bold "Emphasized text"
```

#### Text & Layout
```nix
ui.text.center "Centered text"
ui.layout.pad { left = 2; right = 4; text = "Padded content"; }
```

#### UI Components
```nix
# Boxes
ui.boxes.primary {
  title = "System Status";
  content = "All systems operational";
}

# Tables
ui.tables.basic {
  headers = [ "Component" "Status" ];
  rows = [ [ "Web server" "Running" ] [ "Database" "Running" ] ];
}

# Progress bars
ui.progress.bar { current = 75; total = 100; }

# Spinners (interactive)
ui.spinners.dots "Loading..."

# Status messages
ui.messages.success "Backup completed"
ui.messages.error "Failed to save config"
ui.messages.warning "Low disk space"
ui.messages.info "Processing data..."
```

#### Interactive Elements
```nix
# Prompts (when interactive mode available)
ui.prompts.confirm "Continue with operation?"
ui.prompts.select {
  message = "Choose option";
  options = [ "Option A" "Option B" ];
}
```

## Configuration

### System Configuration
The CLI formatter is configured via `/etc/nixos/configs/cli-formatter-config.nix`:

```nix
{
  core = {
    cli-formatter = {
      enable = true;  # Always true for infrastructure

      # Theme configuration
      config = {
        # Color theme
        # theme = "dark";  # Options: "light", "dark" (future)

        # Format options
        # enableUnicode = true;  # Use Unicode symbols
        # tableStyle = "unicode";  # "ascii", "unicode", "markdown"
      };

      # Custom components
      components = {
        # Example custom status box
        buildStatus = {
          enable = true;
          refreshInterval = 5;
          template = ''
            ${ui.boxes.info {
              title = "Build Status";
              content = "NixOS rebuild in progress...";
            }}
          '';
        };
      };
    };
  };
}
```

## Dependencies & Relationships

- **Infrastructure Level**: Level 1 core service
- **Always Available**: No enable/disable - provides shared functionality
- **No External Dependencies**: Self-contained formatting utilities
- **Used By**: All modules requiring CLI output (logging, management, features)

## Version History

- **v1.0**: Initial infrastructure service implementation
  - Core formatting API
  - Colors, tables, boxes, spinners
  - Status messages and badges
  - User configuration support

## Integration Notes

- API is always available at `config.core.management.system-manager.submodules.cli-formatter.api`
- Symlinks created automatically to `/etc/nixos/configs/cli-formatter-config.nix`
- Component system allows extensibility without core changes
- Theme support planned for future versions
