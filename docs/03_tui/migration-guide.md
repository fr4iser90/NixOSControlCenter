# Migration Guide: fzf → Bubble Tea TUI

## Overview

This guide helps migrate existing fzf-based interfaces to modern Bubble Tea TUIs while maintaining feature parity and improving user experience.

## Assessment Phase

### 1. Analyze Current fzf Implementation

```bash
# Example current fzf command
ncc module-manager

# Maps to something like:
fzf --multi \
    --prompt="Select modules > " \
    --header="TAB: Multi-select | ENTER: Actions | ESC: Quit" \
    --preview="show_module_info {}" \
    --bind="enter:execute(module_actions {})"
```

### 2. Identify fzf Features Used

| fzf Feature | Current Usage | Bubble Tea Equivalent |
|-------------|---------------|----------------------|
| `--multi` | Multi-select modules | `ListTemplate{MultiSelect: true}` |
| `--preview` | Module details pane | `StatusTemplate` side-by-side |
| `--bind` | Custom key actions | `KeyBindings` in template |
| `--header` | Static header text | `Header` component in layout |
| `--query` | Initial search | `SearchField` component |
| `--ansi` | Colored output | `lipgloss` styling |
| `--border` | Bordered layout | `Border` style in layout |

### 3. Map User Workflows

**Current Workflow:**
1. User runs `ncc module-manager`
2. fzf shows list of modules
3. User navigates with arrow keys
4. User presses TAB to multi-select
5. User presses ENTER to execute action
6. fzf calls external script with selections

**New Workflow:**
1. User runs `ncc module-manager`
2. Bubble Tea shows module list
3. User navigates with arrow keys/j/k
4. User presses SPACE to multi-select
5. User presses 'e' to enable, 'd' to disable
6. Bubble Tea calls same external scripts

## Migration Steps

### Phase 1: Data Collection (No Changes)

Keep existing data collection unchanged:

```bash
# This stays the same
discover_modules() {
    find "$MODULES_BASE/modules" "$MODULES_BASE/core" \
        -name "default.nix" -type f | while read -r file; do
        # Parse module metadata
        # Output fzf lines
    done
}
```

### Phase 2: Create Bubble Tea Skeleton

```go
// New TUI structure
type ModuleManager struct {
    listTemplate   list.Template
    statusTemplate status.Template
    currentView    string
    modules        []Module
}

func (m ModuleManager) Init() tea.Cmd {
    return m.loadModules()
}

func (m ModuleManager) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // Handle module loading
    // Handle navigation
    // Handle selections
    // Handle actions
}

func (m ModuleManager) View() string {
    // Render current state
}
```

### Phase 3: Migrate Navigation

**fzf Navigation:**
```bash
# Arrow keys handled by fzf
fzf --bind="up:up" --bind="down:down"
```

**Bubble Tea Navigation:**
```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "up", "k":
            m.cursor = max(0, m.cursor-1)
        case "down", "j":
            m.cursor = min(len(m.items)-1, m.cursor+1)
        case " ":
            m.selected[m.cursor] = !m.selected[m.cursor]
        }
    }
    return m, nil
}
```

### Phase 4: Migrate Selection System

**fzf Multi-Select:**
```bash
# TAB toggles selection
fzf --multi --bind="tab:toggle"
```

**Bubble Tea Multi-Select:**
```go
// Space toggles selection
case " ":
    m.selected[m.cursor] = !m.selected[m.cursor]

// Visual feedback
checkbox := "[ ]"
if m.selected[m.cursor] {
    checkbox = "[✓]"
}
```

### Phase 5: Migrate Actions

**fzf Actions:**
```bash
# ENTER executes action
fzf --bind="enter:execute(echo {+} | module_actions.sh)"
```

**Bubble Tea Actions:**
```go
case "enter", "e":
    selected := m.getSelectedItems()
    return m, m.enableModulesCmd(selected)

case "d":
    selected := m.getSelectedItems()
    return m, m.disableModulesCmd(selected)
```

### Phase 6: Migrate Preview System

**fzf Preview:**
```bash
# Right pane shows details
fzf --preview="show_module_info {}" \
    --preview-window="right:40%"
```

**Bubble Tea Preview:**
```go
// Status template shows details
func (m Model) View() string {
    return lipgloss.JoinHorizontal(
        lipgloss.Left,
        m.renderList(),
        m.renderDetails(),
    )
}
```

## Code Migration Examples

### 1. Simple List Migration

**Before (fzf):**
```bash
show_modules() {
    discover_modules | fzf \
        --multi \
        --prompt="Select modules > " \
        --header="TAB: Multi-select | ENTER: Actions"
}
```

**After (Bubble Tea):**
```go
type ModuleModel struct {
    modules  []Module
    cursor   int
    selected map[int]bool
}

func (m ModuleModel) View() string {
    var output strings.Builder
    output.WriteString("Select modules:\n\n")

    for i, mod := range m.modules {
        cursor := "  "
        if i == m.cursor {
            cursor = "▶ "
        }

        checkbox := "[ ]"
        if m.selected[i] {
            checkbox = "[✓]"
        }

        output.WriteString(fmt.Sprintf("%s%s %s\n",
            cursor, checkbox, mod.Name))
    }

    output.WriteString("\n[e] Enable  [d] Disable  [q] Quit")
    return output.String()
}
```

### 2. Preview Pane Migration

**Before (fzf):**
```bash
fzf --preview="show_module_info {}" \
    --preview-window="right:40%"
```

**After (Bubble Tea):**
```go
func (m Model) View() string {
    listView := m.renderModuleList()
    detailView := m.renderModuleDetails()

    return lipgloss.JoinHorizontal(
        lipgloss.Left,
        lipgloss.NewStyle().
            Width(m.listWidth).
            Render(listView),
        lipgloss.NewStyle().
            Width(m.detailWidth).
            Border(lipgloss.NormalBorder()).
            BorderLeft(true).
            Padding(1).
            Render(detailView),
    )
}
```

### 3. Action System Migration

**Before (fzf):**
```bash
fzf --bind="enter:execute(module_actions {})"
```

**After (Bubble Tea):**
```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "e":
            selected := m.getSelectedModules()
            return m, m.enableModulesCmd(selected)
        case "d":
            selected := m.getSelectedModules()
            return m, m.disableModulesCmd(selected)
        }
    }
    return m, nil
}

func (m Model) enableModulesCmd(modules []Module) tea.Cmd {
    return tea.ExecProcess(
        exec.Command("ncc", "module", "enable",
            // Convert modules to args
        ),
        nil,
    )
}
```

## Testing Migration

### 1. Feature Parity Testing

```go
// Test that all fzf features work in Bubble Tea
func TestFeatureParity(t *testing.T) {
    // Test navigation
    // Test multi-selection
    // Test actions execute same commands
    // Test preview/details show same info
}
```

### 2. User Workflow Testing

```go
func TestUserWorkflows(t *testing.T) {
    // Test: Select multiple modules → Enable
    // Test: Navigate with j/k keys
    // Test: Search/filter functionality
    // Test: Error handling
}
```

### 3. Performance Comparison

```bash
# Compare startup time
time ncc module-manager-fzf
time ncc module-manager-tui

# Compare memory usage
# Compare responsiveness
```

## Rollback Strategy

### Keep fzf as Fallback

```nix
# commands.nix
{
  # New TUI command
  tuiCommand = {
    name = "module-manager-tui";
    script = "${tuiScript}/bin/module-manager-tui";
  };

  # Keep old fzf command
  fzfCommand = {
    name = "module-manager";
    script = "${fzfScript}/bin/module-manager-fzf";
  };
}
```

### Gradual Migration

```bash
# Phase 1: Both available
ncc module-manager      # fzf
ncc module-manager-tui  # Bubble Tea

# Phase 2: Default to Bubble Tea
ncc module-manager      # Bubble Tea (with --fzf fallback)
ncc module-manager --fzf  # fzf

# Phase 3: Remove fzf
ncc module-manager      # Bubble Tea only
```

## Success Metrics

### 1. Feature Completeness
- [ ] All fzf features implemented in Bubble Tea
- [ ] Same keyboard shortcuts
- [ ] Same visual layout
- [ ] Same external command calls

### 2. Performance
- [ ] Startup time < 2x fzf time
- [ ] Memory usage reasonable
- [ ] Responsive UI (no lag)

### 3. User Experience
- [ ] Easier navigation
- [ ] Better visual feedback
- [ ] More intuitive interactions
- [ ] Better error messages

### 4. Maintainability
- [ ] Code is well-structured
- [ ] Easy to add new features
- [ ] Good test coverage
- [ ] Clear documentation

## Common Pitfalls

### 1. Async Operations
**fzf:** Synchronous - blocks until action completes
**Bubble Tea:** Asynchronous - need to handle completion messages

```go
// Wrong - blocks UI
case "e":
    runBlockingCommand()
    return m, nil

// Right - async with feedback
case "e":
    m.showProgress = true
    return m, m.enableModulesCmd(selected)
```

### 2. State Management
**fzf:** Stateless - each invocation fresh
**Bubble Tea:** Stateful - need to manage complex state

```go
type Model struct {
    // UI state
    cursor int
    selected map[int]bool

    // Data state
    modules []Module
    loading bool

    // Action state
    currentAction string
    progress float64
}
```

### 3. Error Handling
**fzf:** Simple - command fails, show error
**Bubble Tea:** Complex - need error states, recovery options

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case errorMsg:
        m.error = msg.err
        m.showErrorDialog = true
        return m, nil
    case tea.KeyMsg:
        if m.showErrorDialog {
            // Handle error recovery
        }
    }
}
```

## Timeline

### Week 1: Analysis & Planning
- Document all fzf features
- Design Bubble Tea architecture
- Create migration plan

### Week 2: Core Implementation
- Implement basic list navigation
- Add multi-selection
- Connect to existing data sources

### Week 3: Feature Completion
- Implement all actions
- Add preview/details pane
- Polish UI/UX

### Week 4: Testing & Migration
- Comprehensive testing
- Performance optimization
- User acceptance testing
- Go-live with fallback

This migration transforms a functional but basic fzf interface into a modern, maintainable Bubble Tea TUI while preserving all existing functionality.
