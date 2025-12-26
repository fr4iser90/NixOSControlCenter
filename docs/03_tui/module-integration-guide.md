# Module Integration Guide - Bubble Tea TUI

## Overview

This guide explains how to integrate Bubble Tea TUI interfaces into existing NixOS Control Center modules. The process maintains backward compatibility while adding modern TUI capabilities.

## Integration Approaches

### 1. Side-by-Side Implementation

Keep existing CLI/bash interfaces and add TUI alongside:

```
modules/security/ssh-client-manager/
├── scripts/
│   └── ssh-client-manager.nix    ← Existing CLI interface
└── tui/
    └── menu.nix                  ← New TUI interface
```

### 2. TUI-First Implementation

Make TUI the primary interface with CLI fallback:

```
modules/core/management/module-manager/
└── tui/
    ├── menu.nix                  ← Primary TUI interface
    └── cli-fallback.nix          ← CLI fallback if needed
```

## Step-by-Step Integration

### Step 1: Create TUI Directory Structure

```bash
# Create TUI directory in your module
mkdir -p modules/your-module/tui/

# Required files
touch modules/your-module/tui/menu.nix
touch modules/your-module/tui/actions.nix
touch modules/your-module/tui/helpers.nix
```

### Step 2: Define TUI Menu Logic

```nix
# modules/your-module/tui/menu.nix
{ lib, cli-formatter }:

let
  baseTemplates = cli-formatter.interactive.tui.components;

  # Configure list template for your module's items
  itemListConfig = {
    title = "Your Module Items";
    multiSelect = true;
    keyBindings = {
      "a" = "add-item";
      "e" = "edit-item";
      "d" = "delete-item";
      "s" = "show-status";
    };
  };

  # Generate Go code for the menu
  menuCode = ''
    package main

    import (
    	"your-module/internal/api"
    	"${baseTemplates.list}"
    	"${baseTemplates.status}"
    )

    type MenuModel struct {
    	listTemplate   list.Template
    	statusTemplate status.Template
    	currentView    string
    	items          []Item
    }

    func (m MenuModel) Init() tea.Cmd {
    	return m.loadItems()
    }

    func (m MenuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    	switch msg := msg.(type) {
    	case itemsLoadedMsg:
    		m.items = msg.items
    		m.listTemplate.SetItems(m.items)
    		return m, nil
    	case tea.KeyMsg:
    		switch msg.String() {
    		case "tab":
    			m.toggleView()
    			return m, nil
    		}
    	}

    	// Delegate to current template
    	return m.updateCurrentTemplate(msg)
    }

    func (m MenuModel) View() string {
    	switch m.currentView {
    	case "list":
    		return m.listTemplate.View()
    	case "status":
    		return m.statusTemplate.View()
    	default:
    		return "Unknown view"
    	}
    }

    func (m MenuModel) toggleView() {
    	if m.currentView == "list" {
    		m.currentView = "status"
    	} else {
    		m.currentView = "list"
    	}
    }

    func (m MenuModel) updateCurrentTemplate(msg tea.Msg) (tea.Model, tea.Cmd) {
    	switch m.currentView {
    	case "list":
    		template, cmd := m.listTemplate.Update(msg)
    		m.listTemplate = template.(list.Template)
    		return m, cmd
    	case "status":
    		template, cmd := m.statusTemplate.Update(msg)
    		m.statusTemplate = template.(status.Template)
    		return m, cmd
    	}
    	return m, nil
    }
  '';
in
pkgs.writeText "menu.go" menuCode
```

### Step 3: Define Action Handlers

```nix
# modules/your-module/tui/actions.nix
{ lib }:

let
  actionsCode = ''
    package main

    import (
    	"your-module/internal/api"
    	"os/exec"
    )

    // Action handlers that call existing CLI commands
    func handleAddItem() tea.Cmd {
    	return tea.ExecProcess(
    		exec.Command("ncc", "your-module", "add"),
    		nil,
    	)
    }

    func handleEditItem(selected []Item) tea.Cmd {
    	if len(selected) == 0 {
    		return nil
    	}

    	item := selected[0]
    	return tea.ExecProcess(
    		exec.Command("ncc", "your-module", "edit", item.ID),
    		nil,
    	)
    }

    func handleDeleteItem(selected []Item) tea.Cmd {
    	cmds := make([]tea.Cmd, len(selected))
    	for i, item := range selected {
    		cmds[i] = tea.ExecProcess(
    			exec.Command("ncc", "your-module", "delete", item.ID),
    			nil,
    		)
    	}
    	return tea.Batch(cmds...)
    }

    func handleShowStatus() tea.Cmd {
    	return tea.ExecProcess(
    		exec.Command("ncc", "your-module", "status"),
    		func(err error) tea.Msg {
    			if err != nil {
    				return statusErrorMsg{err}
    			}
    			return statusUpdatedMsg{}
    		},
    	)
    }
  '';
in
pkgs.writeText "actions.go" actionsCode
```

### Step 4: Update Module Commands

```nix
# modules/your-module/commands.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.${moduleConfig.configPath};
  ui = getModuleApi "cli-formatter";

  # Existing CLI command (unchanged)
  cliCommand = pkgs.writeScriptBin "ncc-your-module" ''
    #!/usr/bin/env bash
    ${ui.scripts.runYourModule}
  '';

  # New TUI command
  tuiCommand = pkgs.writeScriptBin "ncc-your-module-tui" ''
    #!/usr/bin/env bash
    cd ${./tui}
    ${yourModuleTui}/bin/your-module-tui
  '';
in
{
  config = mkIf cfg.enable (lib.mkMerge [
    # Existing CLI commands
    (cliRegistry.registerCommandsFor "your-module" [{
      name = "your-module";
      description = "Manage your module items";
      script = "${cliCommand}/bin/ncc-your-module";
      category = "your-category";
    }])

    # New TUI commands
    (cliRegistry.registerCommandsFor "your-module-tui" [{
      name = "your-module-tui";
      description = "Manage your module items (TUI)";
      script = "${tuiCommand}/bin/ncc-your-module-tui";
      category = "your-category";
    }])
  ]);
}
```

### Step 5: Build Integration

```nix
# In your flake.nix
{
  packages = {
    # Existing CLI package
    your-module-cli = yourModulePackage;

    # New TUI package
    your-module-tui = pkgs.buildGoModule {
      pname = "your-module-tui";
      version = "0.1.0";

      # Source includes generated Go files
      src = pkgs.runCommand "your-module-tui-src" {} ''
        mkdir -p $out
        cp ${./tui/menu.nix} $out/menu.go
        cp ${./tui/actions.nix} $out/actions.go
        cp ${./tui/go.mod} $out/
        cp ${./tui/go.sum} $out/
      '';

      vendorSha256 = null;
    };
  };
}
```

## File Structure Template

```
modules/your-category/your-module/
├── default.nix              # Module definition + TUI imports
├── options.nix              # Configuration options
├── config.nix               # Implementation logic
├── commands.nix             # CLI & TUI command registration
├── scripts/                 # Existing CLI scripts
│   └── your-module.nix
├── handlers/                # Business logic (reusable)
│   ├── add-item.nix
│   ├── edit-item.nix
│   └── delete-item.nix
├── tui/                     # New TUI layer
│   ├── menu.nix             # Main TUI menu (generates menu.go)
│   ├── actions.nix          # Action handlers (generates actions.go)
│   ├── helpers.nix          # TUI utilities (generates helpers.go)
│   ├── go.mod               # Go module definition
│   └── go.sum               # Go dependencies
└── README.md                # Documentation
```

## Integration Patterns

### 1. API Bridge Pattern

Connect TUI to existing business logic:

```go
// tui/api/bridge.go
type APIBridge struct {
    execCmd func(name string, args ...string) (string, error)
}

func (api *APIBridge) GetItems() ([]Item, error) {
    output, err := api.execCmd("ncc", "your-module", "list", "--json")
    if err != nil {
        return nil, err
    }
    return parseJSON(output)
}

func (api *APIBridge) AddItem(item Item) error {
    _, err := api.execCmd("ncc", "your-module", "add",
        "--name", item.Name,
        "--value", item.Value)
    return err
}
```

### 2. State Synchronization

Keep TUI state in sync with system state:

```go
func (m *MenuModel) refreshData() tea.Cmd {
    return tea.Cmd(func() tea.Msg {
        // Call API to get fresh data
        items, err := m.api.GetItems()
        if err != nil {
            return errorMsg{err}
        }
        return itemsLoadedMsg{items}
    })
}

// Auto-refresh every 30 seconds
func (m *MenuModel) Init() tea.Cmd {
    return tea.Batch(
        m.refreshData(),
        m.autoRefreshCmd(),
    )
}
```

### 3. Error Handling

Graceful error handling with recovery options:

```go
func (m *MenuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case errorMsg:
        m.error = msg.err
        m.showError = true
        return m, nil
    case tea.KeyMsg:
        if m.showError {
            switch msg.String() {
            case "r":
                m.showError = false
                return m, m.refreshData()
            case "q":
                return m, tea.Quit
            }
        }
    }
    return m.updateNormal(msg)
}
```

## Testing Integration

### 1. Unit Tests

```go
func TestTUIMenu(t *testing.T) {
    model := NewMenuModel()

    // Test initial state
    assert.Equal(t, "list", model.currentView)
    assert.Equal(t, 0, model.cursor)

    // Test navigation
    model, _ = model.Update(tea.KeyMsg{Type: tea.KeyDown})
    assert.Equal(t, 1, model.cursor)

    // Test view switching
    model, _ = model.Update(tea.KeyMsg{Type: tea.KeyTab})
    assert.Equal(t, "status", model.currentView)
}
```

### 2. Integration Tests

```go
func TestTUIWorkflow(t *testing.T) {
    // Start TUI with test data
    model := NewMenuModel()

    // Navigate to item
    model, _ = model.Update(tea.KeyMsg{Type: tea.KeyDown})

    // Select item
    model, _ = model.Update(tea.KeyMsg{Type: tea.KeySpace})

    // Execute action
    model, cmd := model.Update(tea.KeyMsg{Runes: []rune("e")})

    // Verify API call was made
    assert.Contains(t, executedCommands, "ncc your-module enable")
}
```

## Migration Checklist

### Pre-Migration
- [ ] Analyze existing CLI interface
- [ ] Identify reusable business logic
- [ ] Design TUI information architecture
- [ ] Plan state management

### During Migration
- [ ] Create TUI directory structure
- [ ] Implement menu templates
- [ ] Add action handlers
- [ ] Integrate with existing APIs
- [ ] Add error handling

### Post-Migration
- [ ] Test all user workflows
- [ ] Compare feature parity with CLI
- [ ] Optimize performance
- [ ] Update documentation

## Best Practices

### 1. Keep Business Logic Separate
- TUI should only handle presentation
- Business logic stays in handlers/
- TUI calls existing CLI commands

### 2. Progressive Enhancement
- CLI interface remains functional
- TUI adds better UX
- Users can choose interface

### 3. Consistent Patterns
- Use same templates across modules
- Follow established key bindings
- Maintain consistent styling

### 4. Error Recovery
- Always provide way to recover from errors
- Show clear error messages
- Offer alternative actions

This integration approach ensures that adding TUI interfaces enhances existing modules without breaking functionality or requiring major refactoring.
