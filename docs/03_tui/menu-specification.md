# Menu Specification Document - Bubble Tea TUI

## Overview

This document defines the specification for all TUI menus in the NixOS Control Center. All menus follow consistent patterns for navigation, interaction, and visual design.

## Core Principles

### 1. State-Based Architecture
- **Model**: Application state (data, cursor position, selections)
- **Update**: Handle user input and update state
- **View**: Render current state to terminal

### 2. Consistent Navigation
- **↑/↓ or j/k**: Navigate through lists
- **Space**: Toggle selection in multi-select lists
- **Enter**: Execute primary action
- **Esc or q**: Exit/quit
- **?/h**: Show help

### 3. Visual Consistency
- **Headers**: Bold, centered with emojis
- **Lists**: Cursor indicator (▶) + selection indicators ([✓])
- **Footers**: Action hints and status information
- **Colors**: Consistent color scheme throughout

## Menu Types

### 1. ListMenu - For Item Selection

#### States
- **Loading**: "Loading modules..." with spinner
- **Ready**: Item list with cursor and selections
- **Processing**: "Enabling modules..." with progress
- **Error**: Error message with recovery options

#### Interactions
```go
// Key bindings for ListMenu
case "up", "k":
    cursor = max(0, cursor-1)
case "down", "j":
    cursor = min(len(items)-1, cursor+1)
case " ":
    selected[cursor] = !selected[cursor]
case "enter":
    executeAction(selectedItems)
```

#### Visual Layout
```
┌─ Module Manager ──────────────────────────────┐
│                                              │
│ ▶ [✓] ✅ audio (core.base) - Audio system     │
│   [ ] ❌ boot (core.base) - Boot management   │
│   [✓] ✅ network (core.base) - Network config │
│                                              │
│ [e] Enable Selected  [d] Disable Selected    │
│ [s] Show Status      [q] Quit                │
└──────────────────────────────────────────────┘
```

### 2. FormMenu - For Data Input

#### States
- **Input**: Active input field with cursor
- **Validation**: Input validation with error display
- **Submitting**: Processing form submission
- **Success**: Confirmation with next steps

#### Interactions
```go
case "tab":
    focusNextField()
case "enter":
    if currentField == lastField {
        submitForm()
    } else {
        focusNextField()
    }
```

#### Visual Layout
```
┌─ Add SSH Client ──────────────────────────────┐
│                                              │
│ Hostname: [server.example.com]█              │
│ Username: [user_________________]            │
│ Port:     [22___________________]            │
│                                              │
│ [Submit]  [Cancel]  [Test Connection]        │
│                                              │
│ ✓ Valid hostname                             │
└──────────────────────────────────────────────┘
```

### 3. StatusMenu - For Information Display

#### States
- **Loading**: Gathering status information
- **Display**: Formatted status with sections
- **Refresh**: Updating information

#### Visual Layout
```
┌─ System Status ───────────────────────────────┐
│ ┌─ Health ──────────────┐ ┌─ Resources ──────┐ │
│ │ ✅ CPU: 25%          │ │ 💾 RAM: 2.1/8GB   │ │
│ │ ✅ Disk: 45%         │ │ 🔄 Load: 1.2      │ │
│ │ ✅ Network: OK       │ │ 📊 Uptime: 2d 4h │ │
│ └───────────────────────┘ └───────────────────┘ │
│ ┌─ Modules ──────────────────────────────┐     │
│ │ ✅ 12/15 enabled                     │     │
│ │ ⚠️  2 updates available              │     │
│ └─────────────────────────────────────────┘     │
│                                                │
│ [r] Refresh  [q] Quit                          │
└────────────────────────────────────────────────┘
```

## Error Handling

### 1. Graceful Degradation
- Network errors → Offline mode with cached data
- Permission errors → Clear error message with solution
- Validation errors → Inline validation feedback

### 2. Recovery Options
```go
case "error":
    return ErrorView{
        Message: err.Error(),
        Actions: []Action{
            {Key: "r", Label: "Retry", Action: retryLastAction},
            {Key: "b", Label: "Back", Action: goBack},
            {Key: "q", Label: "Quit", Action: quit},
        },
    }
```

## Animation & Transitions

### 1. State Transitions
- Loading → Ready: Fade in content
- Processing → Success: Checkmark animation
- Error → Recovery: Shake animation

### 2. Cursor Movement
- Smooth cursor transitions between items
- Highlight animations for selections

## Accessibility

### 1. Keyboard Navigation
- Full keyboard-only operation
- Logical tab order in forms
- Clear focus indicators

### 2. Screen Reader Support
- Descriptive labels for all interactive elements
- Status announcements for state changes
- Semantic structure in rendered output

## Testing Requirements

### 1. Unit Tests
```go
func TestListMenuNavigation(t *testing.T) {
    model := NewListMenu(items)
    // Test cursor movement
    // Test selection toggling
    // Test action execution
}
```

### 2. Integration Tests
- Full user workflows from start to finish
- Error scenarios and recovery
- Performance testing with large datasets

### 3. Visual Regression Tests
- Screenshot comparison for UI changes
- Terminal output validation
- Color scheme consistency

## Implementation Checklist

### Core Components ✅
- [x] Base Model/Update/View pattern
- [x] Consistent key bindings
- [x] Error handling framework

### Menu Types ✅
- [x] ListMenu for selections
- [x] FormMenu for input
- [x] StatusMenu for information

### Advanced Features 🔄
- [ ] Animation system
- [ ] Accessibility features
- [ ] Comprehensive testing

## Migration from fzf

### Feature Mapping
| fzf Feature | Bubble Tea Equivalent |
|-------------|----------------------|
| Fuzzy search | Integrated search field |
| Multi-select | Checkbox UI with space key |
| Preview pane | Integrated detail views |
| Custom actions | Key binding system |

### UX Improvements
- Persistent state between actions
- Better error handling and feedback
- Rich formatting and colors
- Mouse support
- Animations and transitions
