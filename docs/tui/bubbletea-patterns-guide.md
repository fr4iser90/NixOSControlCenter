# Bubble Tea Patterns Guide - NixOS Control Center

## Overview

This guide covers common patterns and best practices for building Bubble Tea TUIs in the NixOS Control Center. It focuses on maintainable, testable, and user-friendly interface code.

## Core Architecture Pattern

### The Bubble Tea Model

```go
// Every TUI component follows this pattern
type Model struct {
    // State
    cursor int
    items  []Item
    loading bool
    error   error

    // Configuration
    config Config
}

func (m Model) Init() tea.Cmd {
    // Initialize component
    return m.loadData()
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // Handle messages and update state
    switch msg := msg.(type) {
    case dataLoadedMsg:
        m.items = msg.items
        m.loading = false
        return m, nil
    case errorMsg:
        m.error = msg.err
        m.loading = false
        return m, nil
    }
    return m.handleInput(msg)
}

func (m Model) View() string {
    // Render current state
    if m.loading {
        return "Loading..."
    }
    if m.error != nil {
        return fmt.Sprintf("Error: %s", m.error)
    }
    return m.renderItems()
}
```

## Message Patterns

### 1. Command Results

```go
// Define message types for async operations
type dataLoadedMsg struct {
    items []Item
}

type itemUpdatedMsg struct {
    item Item
}

type errorMsg struct {
    err error
}

// Commands that produce these messages
func loadDataCmd() tea.Cmd {
    return tea.Cmd(func() tea.Msg {
        items, err := api.GetItems()
        if err != nil {
            return errorMsg{err}
        }
        return dataLoadedMsg{items}
    })
}

func updateItemCmd(item Item) tea.Cmd {
    return tea.Cmd(func() tea.Msg {
        updated, err := api.UpdateItem(item)
        if err != nil {
            return errorMsg{err}
        }
        return itemUpdatedMsg{updated}
    })
}
```

### 2. User Input Messages

```go
// Custom messages for complex input
type searchInputMsg struct {
    query string
}

type selectionChangedMsg struct {
    selected []int
}

// Input handling
func (m Model) handleSearchInput(r rune) (Model, tea.Cmd) {
    m.searchQuery += string(r)
    return m, tea.Cmd(func() tea.Msg {
        filtered := m.filterItems(m.searchQuery)
        return searchInputMsg{m.searchQuery}
    })
}
```

### 3. Lifecycle Messages

```go
type initCompleteMsg struct{}
type cleanupCompleteMsg struct{}

func (m Model) Init() tea.Cmd {
    return tea.Batch(
        m.loadInitialData(),
        tea.Cmd(func() tea.Msg {
            // Perform initialization
            return initCompleteMsg{}
        }),
    )
}
```

## State Management Patterns

### 1. Immutable Updates

```go
// Always return new model instances
func (m Model) updateCursor(newCursor int) Model {
    updated := m  // Copy
    updated.cursor = clamp(newCursor, 0, len(m.items)-1)
    return updated
}

// Usage in Update
case tea.KeyDown:
    return m.updateCursor(m.cursor + 1), nil
```

### 2. State Machines

```go
type ViewState int

const (
    ListView ViewState = iota
    FormView
    ConfirmView
    LoadingView
)

type Model struct {
    state ViewState
    // ... other fields
}

func (m Model) nextState() Model {
    updated := m
    switch m.state {
    case ListView:
        updated.state = FormView
    case FormView:
        updated.state = ConfirmView
    case ConfirmView:
        updated.state = LoadingView
    }
    return updated
}
```

### 3. Sub-Model Composition

```go
type MainModel struct {
    listModel   ListModel
    formModel   FormModel
    statusModel StatusModel
    currentView ViewType
}

func (m MainModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    // Route messages to appropriate sub-model
    switch m.currentView {
    case ListView:
        updated, cmd := m.listModel.Update(msg)
        m.listModel = updated.(ListModel)
        return m, cmd
    case FormView:
        updated, cmd := m.formModel.Update(msg)
        m.formModel = updated.(FormModel)
        return m, cmd
    }
    return m, nil
}
```

## Component Patterns

### 1. Reusable List Component

```go
type ListComponent struct {
    items       []ListItem
    cursor      int
    multiSelect bool
    selected    map[int]bool
    style       ListStyle
}

func (l ListComponent) View() string {
    var output strings.Builder

    for i, item := range l.items {
        cursor := "  "
        if i == l.cursor {
            cursor = l.style.Cursor
        }

        checkbox := "[ ]"
        if l.selected[i] {
            checkbox = "[✓]"
        }

        output.WriteString(fmt.Sprintf("%s %s %s %s\n",
            cursor, checkbox,
            item.StatusIcon(), item.Title))
    }

    return output.String()
}

func (l ListComponent) Update(msg tea.Msg) (interface{}, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "up", "k":
            l.cursor = max(0, l.cursor-1)
        case "down", "j":
            l.cursor = min(len(l.items)-1, l.cursor+1)
        case " ":
            if l.multiSelect {
                l.selected[l.cursor] = !l.selected[l.cursor]
            }
        }
    }
    return l, nil
}
```

### 2. Form Component

```go
type FormComponent struct {
    fields []FormField
    focus  int
    values map[string]string
}

type FormField struct {
    key         string
    label       string
    placeholder string
    validate    func(string) error
}

func (f FormComponent) View() string {
    var output strings.Builder

    for i, field := range f.fields {
        cursor := ""
        if i == f.focus {
            cursor = "▶ "
        }

        value := f.values[field.key]
        if value == "" && i != f.focus {
            value = fmt.Sprintf("\x1b[2m%s\x1b[0m", field.placeholder)
        }

        output.WriteString(fmt.Sprintf("%s%s: [%s]\n",
            cursor, field.label, value))
    }

    return output.String()
}
```

### 3. Status Component

```go
type StatusComponent struct {
    sections []StatusSection
    lastUpdate time.Time
}

type StatusSection struct {
    title string
    items []StatusItem
}

func (s StatusComponent) View() string {
    var output strings.Builder

    for _, section := range s.sections {
        output.WriteString(fmt.Sprintf("┌─ %s ─┐\n", section.title))
        for _, item := range section.items {
            output.WriteString(fmt.Sprintf("│ %s %s │\n",
                item.icon, item.text))
        }
        output.WriteString("└─────────┘\n")
    }

    output.WriteString(fmt.Sprintf("\nLast updated: %s",
        s.lastUpdate.Format("15:04:05")))

    return output.String()
}
```

## Error Handling Patterns

### 1. Graceful Error States

```go
func (m Model) View() string {
    if m.error != nil {
        return m.renderError()
    }
    if m.loading {
        return m.renderLoading()
    }
    return m.renderNormal()
}

func (m Model) renderError() string {
    return fmt.Sprintf(`❌ Error: %s

[r] Retry  [b] Back  [q] Quit`, m.error.Error())
}
```

### 2. Error Recovery

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    if m.error != nil {
        return m.handleErrorState(msg)
    }
    return m.handleNormalState(msg)
}

func (m Model) handleErrorState(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "r":
            m.error = nil
            return m, m.retryCmd()
        case "b":
            m.error = nil
            return m, m.goBackCmd()
        case "q":
            return m, tea.Quit
        }
    }
    return m, nil
}
```

## Animation Patterns

### 1. Loading States

```go
type LoadingModel struct {
    spinner spinner.Model
    message string
}

func (m LoadingModel) Init() tea.Cmd {
    return m.spinner.Tick
}

func (m LoadingModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.spinner, cmd = m.spinner.Update(msg)
    return m, cmd
}

func (m LoadingModel) View() string {
    return fmt.Sprintf("%s %s", m.spinner.View(), m.message)
}
```

### 2. Transition Effects

```go
type TransitionModel struct {
    fromView, toView string
    progress float64
    duration time.Duration
}

func (t TransitionModel) View() string {
    // Interpolate between views based on progress
    fromRendered := t.renderView(t.fromView)
    toRendered := t.renderView(t.toView)

    return interpolateViews(fromRendered, toRendered, t.progress)
}
```

## Testing Patterns

### 1. Model Testing

```go
func TestModelNavigation(t *testing.T) {
    model := initialModel()

    // Test down navigation
    updated, _ := model.Update(tea.KeyMsg{Type: tea.KeyDown})
    assert.Equal(t, 1, updated.(Model).cursor)

    // Test up navigation with boundary
    updated, _ = updated.Update(tea.KeyMsg{Type: tea.KeyUp})
    assert.Equal(t, 0, updated.(Model).cursor)
}
```

### 2. Message Testing

```go
func TestAsyncOperations(t *testing.T) {
    model := initialModel()

    // Simulate data loading
    updated, _ := model.Update(dataLoadedMsg{items: testItems})
    assert.False(t, updated.(Model).loading)
    assert.Len(t, updated.(Model).items, len(testItems))
}
```

### 3. View Testing

```go
func TestViewRendering(t *testing.T) {
    model := Model{
        items: []Item{{Title: "Test Item"}},
        cursor: 0,
    }

    view := model.View()
    assert.Contains(t, view, "▶")
    assert.Contains(t, view, "Test Item")
}
```

## Performance Patterns

### 1. Efficient Rendering

```go
type CachedModel struct {
    data        []Item
    cache       map[string]string
    lastRender  time.Time
}

func (m *CachedModel) View() string {
    cacheKey := m.computeCacheKey()

    if cached, exists := m.cache[cacheKey]; exists &&
        time.Since(m.lastRender) < time.Second {
        return cached
    }

    rendered := m.renderExpensiveView()
    m.cache[cacheKey] = rendered
    m.lastRender = time.Now()

    return rendered
}
```

### 2. Debounced Input

```go
type DebouncedModel struct {
    input       string
    lastInput   time.Time
    debounceDur time.Duration
}

func (m *DebouncedModel) handleInput(r rune) (Model, tea.Cmd) {
    m.input += string(r)
    m.lastInput = time.Now()

    return m, tea.Tick(m.debounceDur, func(t time.Time) tea.Msg {
        if time.Since(m.lastInput) >= m.debounceDur {
            return searchMsg{m.input}
        }
        return nil
    })
}
```

## Accessibility Patterns

### 1. Keyboard Navigation

```go
func (m Model) handleKey(msg tea.KeyMsg) (Model, tea.Cmd) {
    // Always support basic navigation
    switch msg.String() {
    case "ctrl+c", "q":
        return m, tea.Quit
    case "tab":
        return m.focusNext()
    case "shift+tab":
        return m.focusPrevious()
    }

    // Component-specific keys
    return m.handleComponentKeys(msg)
}
```

### 2. Screen Reader Support

```go
func (m Model) View() string {
    // Include semantic information for screen readers
    return fmt.Sprintf(`%s
Current selection: %d of %d
Status: %s`,
        m.visualView(),
        m.cursor+1,
        len(m.items),
        m.statusMessage())
}
```

## Integration Patterns

### 1. API Bridge

```go
type APIBridge struct {
    execFunc func(cmd string, args ...string) (string, error)
}

func (a *APIBridge) CallNixCommand(cmd string, args ...string) (string, error) {
    return a.execFunc("ncc", append([]string{cmd}, args...)...)
}
```

### 2. Configuration Loading

```go
type ConfigLoader struct {
    configPath string
}

func (c *ConfigLoader) Load() (Config, error) {
    // Read from Nix-generated config files
    data, err := ioutil.ReadFile(c.configPath)
    if err != nil {
        return Config{}, err
    }

    var config Config
    return config, json.Unmarshal(data, &config)
}
```

These patterns provide a solid foundation for building maintainable, testable, and user-friendly Bubble Tea TUIs in the NixOS Control Center.
