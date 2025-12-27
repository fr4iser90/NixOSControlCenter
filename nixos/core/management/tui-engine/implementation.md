# TUI Engine Implementation Plan - BUBBLE TEA BASED

## Overview

The TUI Engine is a Bubble Tea-based TUI builder for all NixOS Control Center modules. Based on OptiNix's successful implementation, we use Go with Bubble Tea for complex multi-panel TUIs instead of simple Gum-based interfaces.

## Architecture Analysis

Based on OptiNix's proven Bubble Tea implementation and existing module patterns (cli-registry, cli-formatter, system-manager), the TUI engine provides a Go-based TUI framework with proper multi-panel layouts.

### Module Structure Pattern
```nix
# default.nix (following OptiNix pattern)
{ config, lib, ... }:

let
  moduleName = baseNameOf ./. ;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Bubble Tea-based TUI utilities for NixOS Control Center";
    category = "management";
    subcategory = "tui-engine";
    stability = "stable";
    version = "1.0.0";
  };

  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
    ./config.nix
    ./builders.nix  # Go application builders
  ];
}
```

### API Pattern
- **Definition**: API functions defined in `config.nix`
- **Registration**: API exposed via `${configPath}.api = apiValue`
- **Access**: `getModuleApi "tui-engine"` returns the API

## Core Problem: Runtime Discovery Integration

**Current Issue:** Runtime discovery needs to be called at runtime, not build time.

**Solution:** Gum-based TUIs call runtime discovery directly in shell scripts.

## TUI Engine API Design

Based on OptiNix's Bubble Tea implementation, we provide Go-based TUI templates with proper Model-Update-View pattern.

```nix
# builders.nix - Go application builders (based on OptiNix)
{ lib, buildGoApplication, gomod2nix }:

let
  # Build function using gomod2nix (from OptiNix pattern)
  buildTUIApp = { pname, version, src, go ? null }:
    buildGoApplication {
      inherit pname version src go;
      modules = ./gomod2nix.toml;
      nativeBuildInputs = with pkgs; [ installShellFiles ];
      postInstall = ''
        installShellCompletion --cmd ${pname} \
          --bash <($out/bin/${pname} completion bash) \
          --fish <($out/bin/${pname} completion fish) \
          --zsh <($out/bin/${pname} completion zsh)
      '';
    };

in {
  inherit buildTUIApp;
}
```

```go
// Go TUI templates (inspired by OptiNix)
package tui

import (
    "github.com/charmbracelet/bubbles/list"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

type ModuleItem struct {
    Name        string
    Description string
    Status      string
    Category    string
}

func (i ModuleItem) Title() string       { return i.Name }
func (i ModuleItem) Description() string { return i.Description }
func (i ModuleItem) FilterValue() string { return i.Name }

type Model struct {
    list     list.Model
    panels   [5]string  // 5-panel layout
    selected int
}

func (m Model) View() string {
    // 5-panel layout inspired by design.md
    return lipgloss.JoinHorizontal(
        lipgloss.Top,
        m.panels[0], // Menu
        m.panels[1], // Content
        m.panels[2], // Filter
        m.panels[3], // Info
        m.panels[4], // Stats
    )
}
```

## Module Usage Pattern

```nix
# In any module's TUI (e.g., module-manager/tui/tui.nix)
{ lib, pkgs, getModuleApi, ... }:

let
  tuiEngine = getModuleApi "tui-engine";

  # Create Bubble Tea-based TUI application
  moduleManagerTui = tuiEngine.builders.buildTUIApp {
    pname = "module-manager-tui";
    version = "1.0.0";
    src = ./src;  # Go source code
    go = pkgs.go_1_25;
  };
in
  moduleManagerTui
```

```go
// src/main.go - Module Manager TUI (inspired by OptiNix)
package main

import (
    "encoding/json"
    "os/exec"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/hmajid2301/nixos-control-center/tui"
)

func main() {
    // Get modules from runtime discovery (like OptiNix gets options)
    modulesJSON, _ := exec.Command("runtime-discovery-script").Output()
    var modules []tui.ModuleItem
    json.Unmarshal(modulesJSON, &modules)

    // Create 5-panel TUI model
    model := tui.NewModuleManagerModel(modules)

    p := tea.NewProgram(model)
    if _, err := p.Run(); err != nil {
        panic(err)
    }
}
```

## Implementation Structure

Based on OptiNix's structure but adapted for module management:

```
nixos/core/management/tui-engine/
├── default.nix            # Module metadata
├── options.nix            # Module options (enable, goVersion)
├── config.nix             # API definition and registration
├── builders.nix           # Go application builders (gomod2nix)
├── gomod2nix.toml         # Go dependencies (from OptiNix)
├── go.mod                 # Go module definition
├── go.sum                 # Go dependencies
├── src/                   # Go source code
│   ├── main.go           # TUI application entry
│   ├── tui/              # TUI components
│   │   ├── model.go      # Bubble Tea model
│   │   ├── update.go     # Update logic
│   │   ├── view.go       # View rendering
│   │   ├── keymaps.go    # Key bindings
│   │   └── styles.go     # Lipgloss styles
│   └── lib/              # Utility functions
└── implementation.md     # This documentation
```

**Kopierbar von OptiNix:**
- `gomod2nix.toml` (Bubble Tea + Charm dependencies)
- Go project structure (`src/tui/` with model/update/view)
- Keymaps and styles pattern
- Nix build setup (`flake.nix`, `default.nix`)

**Nicht kopierbar:**
- Nix options domain logic
- Database/SQL code
- CLI command structure

## Runtime Discovery Integration

Bubble Tea TUIs integrate with runtime discovery via JSON (like OptiNix integrates with Nix options):

```bash
# Runtime discovery outputs JSON (like OptiNix's option fetching)
runtime-discovery-script | jq '.[] | {name, description, status, category}'
```

```go
// Go code calls runtime discovery at startup (like OptiNix)
func getModules() []ModuleItem {
    cmd := exec.Command("runtime-discovery-script")
    output, _ := cmd.Output()

    var modules []ModuleItem
    json.Unmarshal(output, &modules)
    return modules
}

// Module enable/disable via shell commands (like OptiNix's nix commands)
func toggleModule(name, action string) error {
    return exec.Command("module-toggle-script", name, action).Run()
}
```

## Navigation Standards

Based on OptiNix's keymaps (j/k navigation, t for toggle, g/G for top/end):

**Global Shortcuts:**
- `q` / `Ctrl+C` = Quit
- `↑↓` / `jk` = Navigate list
- `Enter` = Select module
- `t` = Toggle details view
- `g` = Top of list
- `G` = End of list
- `e` = Enable selected module
- `d` = Disable selected module
- `r` = Refresh modules
- `/` = Search/Filter

**Bubble Tea Specific:**
- **List**: Fuzzy search with live filtering
- **Spinner**: Loading indicators during discovery
- **Help**: Context-sensitive help display
- **Multi-panel**: Synchronized panel updates

## Integration Points

- **CLI Registry**: TUIs registered as commands via cli-registry
- **API Access**: TUI engine available via `getModuleApi "tui-engine"`
- **Runtime Discovery**: Called at TUI execution time
- **Configuration**: Module settings via standard options system

## Testing Strategy

1. **Unit Tests**: API function correctness
2. **Integration Tests**: End-to-end Gum TUI workflows
3. **Compatibility Tests**: Different terminal sizes
4. **Performance Tests**: Large option lists

## TODO: Complete Bubble Tea Implementation

### Phase 1: Infrastructure Setup
- [ ] Copy `gomod2nix.toml` from OptiNix and adapt dependencies
- [ ] Create Go project structure (`src/tui/model.go`, etc.)
- [ ] Set up `builders.nix` with `buildGoApplication`
- [ ] Configure `flake.nix` with gomod2nix input

### Phase 2: Core TUI Components
- [ ] Implement `model.go` with 5-panel layout structure
- [ ] Create `update.go` with navigation and action handling
- [ ] Build `view.go` with lipgloss styling for panels
- [ ] Add `keymaps.go` based on OptiNix patterns

### Phase 3: Module Manager Integration
- [ ] Integrate runtime discovery JSON parsing
- [ ] Implement module enable/disable via shell commands
- [ ] Add 5-panel layout: Menu|Content|Filter|Info|Stats
- [ ] Connect with cli-registry for command registration

### Phase 4: Testing & Polish
- [ ] Test multi-panel navigation
- [ ] Add help system and keymap display
- [ ] Performance optimization for large module lists
- [ ] Error handling for discovery failures

## Kopierbare Assets von OptiNix

**Voll kopierbar:**
- `gomod2nix.toml` (Bubble Tea + Charm libraries)
- Go project structure pattern
- Keymap implementation (`keymaps.go`)
- Model-Update-View architecture
- Lipgloss styling patterns
- Nix build configuration

**Adaptiervar:**
- Domain logic (Nix options → NixOS modules)
- Data fetching (Nix options API → runtime discovery)
- Database → JSON parsing
- CLI commands → Module management actions

This corrected implementation provides a proper Bubble Tea-based TUI foundation for complex multi-panel interfaces, following OptiNix's proven patterns.




