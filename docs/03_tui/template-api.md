# Template API Documentation - Bubble Tea TUI

## Overview

The Template API provides reusable UI components for building consistent TUI interfaces across all NixOS Control Center modules. Templates are configurable, composable, and follow the Bubble Tea pattern.

## Core Template Interface

```go
// All templates implement this interface
type Template interface {
    // Bubble Tea core methods
    Init() tea.Cmd
    Update(tea.Msg) (Template, tea.Cmd)
    View() string

    // Template-specific methods
    SetConfig(config TemplateConfig) error
    GetConfig() TemplateConfig
    Validate() error
}
```

## Available Templates

### 1. ListTemplate - Item Selection Lists

#### Configuration
```go
type ListConfig struct {
    // Basic settings
    Title       string
    Items       []ListItem
    MultiSelect bool

    // Interaction
    KeyBindings map[string]ActionFunc
    Searchable  bool

    // Styling
    Style       ListStyle

    // Callbacks
    OnSelect    func(item ListItem) tea.Cmd
    OnExecute   func(selected []ListItem) tea.Cmd
}

type ListItem struct {
    ID          string
    Title       string
    Description string
    Status      ItemStatus  // enabled, disabled, error, etc.
    Metadata    map[string]interface{}
}
```

#### Usage Example
```go
// Create module list
modules := []ListItem{
    {ID: "audio", Title: "Audio System", Status: Enabled},
    {ID: "network", Title: "Network Config", Status: Disabled},
}

config := ListConfig{
    Title: "Available Modules",
    Items: modules,
    MultiSelect: true,
    KeyBindings: map[string]ActionFunc{
        "e": func(selected []ListItem) tea.Cmd {
            return enableModulesCmd(selected)
        },
        "d": func(selected []ListItem) tea.Cmd {
            return disableModulesCmd(selected)
        },
    },
}

template := NewListTemplate(config)
```

#### Visual Output
```
┌─ Available Modules ──────────────────────────────┐
│                                                 │
│ ▶ [✓] ✅ audio - Audio system configuration     │
│   [ ] ❌ network - Network configuration        │
│   [✓] ✅ packages - Package management          │
│                                                 │
│ [e] Enable Selected  [d] Disable Selected      │
│ [s] Show Details     [q] Quit                   │
└─────────────────────────────────────────────────┘
```

### 2. FormTemplate - Data Input Forms

#### Configuration
```go
type FormConfig struct {
    Title  string
    Fields []FormField
    Style  FormStyle

    // Validation
    ValidateOnChange bool
    ValidateOnSubmit bool

    // Actions
    OnSubmit func(values map[string]interface{}) tea.Cmd
    OnCancel func() tea.Cmd
}

type FormField struct {
    ID          string
    Label       string
    Type        FieldType  // text, password, select, checkbox
    Required    bool
    Default     interface{}
    Validation  func(value interface{}) error
    Placeholder string
}
```

#### Usage Example
```go
config := FormConfig{
    Title: "Add SSH Client",
    Fields: []FormField{
        {
            ID: "hostname",
            Label: "Hostname",
            Type: TextField,
            Required: true,
            Validation: validateHostname,
        },
        {
            ID: "username",
            Label: "Username",
            Type: TextField,
            Required: true,
        },
        {
            ID: "port",
            Label: "Port",
            Type: TextField,
            Default: "22",
            Validation: validatePort,
        },
    },
    OnSubmit: func(values map[string]interface{}) tea.Cmd {
        return addSSHClientCmd(values)
    },
}
```

#### Visual Output
```
┌─ Add SSH Client ──────────────────────────────┐
│                                              │
│ Hostname: [server.example.com]█              │
│ Username: [____________________]             │
│ Port:     [22__________________]             │
│                                              │
│ [Submit]  [Cancel]  [Test Connection]        │
│                                              │
│ ✓ Valid hostname    ⚠️ Username required     │
└──────────────────────────────────────────────┘
```

### 3. StatusTemplate - Information Display

#### Configuration
```go
type StatusConfig struct {
    Title    string
    Sections []StatusSection
    Style    StatusStyle

    // Auto-refresh
    AutoRefresh bool
    RefreshInterval time.Duration

    // Actions
    Actions []StatusAction
}

type StatusSection struct {
    Title   string
    Items   []StatusItem
    Layout  SectionLayout  // horizontal, vertical, grid
}

type StatusItem struct {
    Label   string
    Value   string
    Status  ItemStatus
    Icon    string
}
```

#### Usage Example
```go
config := StatusConfig{
    Title: "System Overview",
    Sections: []StatusSection{
        {
            Title: "Health",
            Items: []StatusItem{
                {Label: "CPU", Value: "25%", Status: Ok, Icon: "✅"},
                {Label: "Memory", Value: "2.1/8GB", Status: Warning, Icon: "⚠️"},
            },
        },
        {
            Title: "Modules",
            Items: []StatusItem{
                {Label: "Enabled", Value: "12/15", Status: Ok, Icon: "✅"},
                {Label: "Updates", Value: "2 available", Status: Info, Icon: "🔄"},
            },
        },
    },
    AutoRefresh: true,
    RefreshInterval: 5 * time.Second,
}
```

#### Visual Output
```
┌─ System Overview ──────────────────────────────┐
│ ┌─ Health ──────┐ ┌─ Modules ──────┐           │
│ │ ✅ CPU: 25%   │ │ ✅ 12/15       │           │
│ │ ⚠️ RAM: 2.1/8 │ │ 🔄 2 available│           │
│ └───────────────┘ └───────────────┘           │
│                                               │
│ Last updated: 2025-01-15 14:30:22            │
│ [r] Refresh  [q] Quit                         │
└───────────────────────────────────────────────┘
```

## Template Composition

### Combining Templates
```go
type ComplexMenu struct {
    listTemplate   ListTemplate
    formTemplate   FormTemplate
    statusTemplate StatusTemplate
    currentView    MenuView
}

func (m ComplexMenu) View() string {
    switch m.currentView {
    case ListView:
        return m.listTemplate.View()
    case FormView:
        return m.formTemplate.View()
    case StatusView:
        return m.statusTemplate.View()
    }
}
```

### Template Inheritance
```go
// Custom template extending base
type ModuleListTemplate struct {
    ListTemplate
    moduleSpecificConfig ModuleConfig
}

func (t ModuleListTemplate) View() string {
    // Custom rendering with module-specific features
    base := t.ListTemplate.View()
    return t.addModuleFeatures(base)
}
```

## Configuration System

### Template Registry
```go
// Global template registry
var TemplateRegistry = map[string]TemplateConstructor{
    "list": func(config interface{}) Template {
        return NewListTemplate(config.(ListConfig))
    },
    "form": func(config interface{}) Template {
        return NewFormTemplate(config.(FormConfig))
    },
    "status": func(config interface{}) Template {
        return NewStatusTemplate(config.(StatusConfig))
    },
}

// Usage from Nix
template := TemplateRegistry["list"](listConfig)
```

### Nix Integration
```nix
# Module defines template usage
{ lib, cli-formatter }:

let
  baseTemplates = cli-formatter.interactive.tui.components;

  # Configure list template for modules
  moduleListConfig = {
    title = "Available Modules";
    multiSelect = true;
    keyBindings = {
      e = "enable-modules";
      d = "disable-modules";
      s = "show-status";
    };
  };

  # Generate Go code using template
  menuCode = baseTemplates.list.generate moduleListConfig;
in
pkgs.writeText "menu.go" menuCode
```

## Styling System

### Style Configuration
```go
type TemplateStyle struct {
    Colors    ColorScheme
    Borders   BorderStyle
    Spacing   SpacingConfig
    Fonts     FontConfig
}

type ColorScheme struct {
    Primary     lipgloss.Color
    Secondary   lipgloss.Color
    Success     lipgloss.Color
    Warning     lipgloss.Color
    Error       lipgloss.Color
    Background  lipgloss.Color
    Foreground  lipgloss.Color
}
```

### Theme Support
```go
// Theme registry
var Themes = map[string]TemplateStyle{
    "default": DefaultTheme,
    "dark":    DarkTheme,
    "light":   LightTheme,
}

// Apply theme
template.SetStyle(Themes["dark"])
```

## Error Handling

### Template Errors
```go
type TemplateError struct {
    Type    ErrorType
    Field   string
    Message string
}

func (t ListTemplate) Validate() error {
    if len(t.items) == 0 {
        return TemplateError{
            Type:    ValidationError,
            Field:   "items",
            Message: "List must contain at least one item",
        }
    }
    return nil
}
```

### Recovery Patterns
```go
func (t ListTemplate) Update(msg tea.Msg) (Template, tea.Cmd) {
    switch msg := msg.(type) {
    case TemplateError:
        // Show error state
        t.showError(msg)
        return t, nil
    case RecoverMsg:
        // Attempt recovery
        return t, t.recoverCmd()
    }
}
```

## Testing Templates

### Unit Tests
```go
func TestListTemplateNavigation(t *testing.T) {
    template := NewListTemplate(ListConfig{Items: testItems})

    // Test initial state
    assert.Equal(t, 0, template.cursor)

    // Test navigation
    template, _ = template.Update(tea.KeyMsg{Type: tea.KeyDown})
    assert.Equal(t, 1, template.cursor)
}

func TestFormTemplateValidation(t *testing.T) {
    template := NewFormTemplate(FormConfig{Fields: testFields})

    // Test invalid input
    template, _ = template.Update(tea.KeyMsg{Runes: []rune("invalid")})
    assert.True(t, template.HasErrors())
}
```

### Integration Tests
```go
func TestCompleteWorkflow(t *testing.T) {
    // Test full user workflow
    template := NewListTemplate(config)

    // Navigate to item
    template, _ = template.Update(tea.KeyMsg{Type: tea.KeyDown})

    // Select item
    template, _ = template.Update(tea.KeyMsg{Type: tea.KeySpace})

    // Execute action
    template, cmd := template.Update(tea.KeyMsg{Runes: []rune("e")})

    // Verify command was created
    assert.NotNil(t, cmd)
}
```

## Performance Considerations

### Memory Management
- Templates should be lightweight
- Large datasets should be paginated
- Cleanup resources in Update loop

### Rendering Optimization
- Cache rendered strings when possible
- Use incremental updates for large lists
- Debounce rapid user input

## Migration Guide

### From fzf to Templates
1. **Identify fzf features** used in current interface
2. **Map to template types** (ListTemplate, FormTemplate, etc.)
3. **Configure template** with equivalent functionality
4. **Test user workflows** to ensure feature parity

### Common Mappings
| fzf Pattern | Template Equivalent |
|-------------|-------------------|
| `fzf --multi` | `ListTemplate{MultiSelect: true}` |
| `fzf --preview` | `StatusTemplate` in same view |
| `fzf --bind` | `KeyBindings` in template config |
| Form input | `FormTemplate` |
| Status display | `StatusTemplate` |

This Template API provides a solid foundation for building consistent, maintainable TUI interfaces across the entire NixOS Control Center.
