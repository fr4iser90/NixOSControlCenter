{ lib, bubbletea-src ? "github.com/charmbracelet/bubbletea" }:

let
  # Base Template Interface
  templateInterface = ''
    // Template interface that all templates implement
    type Template interface {
        Init() tea.Cmd
        Update(tea.Msg) (Template, tea.Cmd)
        View() string
        SetConfig(config map[string]interface{}) error
        Validate() error
    }

    // Base template with common functionality
    type BaseTemplate struct {
        styles map[string]string
        config map[string]interface{}
    }

    func (b *BaseTemplate) SetConfig(config map[string]interface{}) error {
        b.config = config
        return b.Validate()
    }

    func (b *BaseTemplate) Validate() error {
        return nil // Override in subclasses
    }

    func (b *BaseTemplate) getString(key, defaultValue string) string {
        if val, ok := b.config[key]; ok {
            if str, ok := val.(string); ok {
                return str
            }
        }
        return defaultValue
    }

    func (b *BaseTemplate) getBool(key string, defaultValue bool) bool {
        if val, ok := b.config[key]; ok {
            if bl, ok := val.(bool); ok {
                return bl
            }
        }
        return defaultValue
    }

    func (b *BaseTemplate) getInt(key string, defaultValue int) int {
        if val, ok := b.config[key]; ok {
            if i, ok := val.(int); ok {
                return i
            }
        }
        return defaultValue
    }
  '';

  # List Template - For item selection lists
  listTemplate = ''
    package components

    import (
    	tea "${bubbletea-src}"
    	"github.com/charmbracelet/lipgloss"
    	"strings"
    	"fmt"
    )

    // ListItem represents an item in the list
    type ListItem struct {
    	ID          string
    	Title       string
    	Description string
    	Status      string  // "enabled", "disabled", "error", etc.
    	Category    string
    	Metadata    map[string]interface{}
    }

    // ListTemplate handles item selection lists
    type ListTemplate struct {
    	BaseTemplate
    	items       []ListItem
    	cursor      int
    	selected    map[int]bool
    	filter      string
    	multiSelect bool
    	searchable  bool
    	title       string
    	loading     bool
    	error       error
    }

    func NewListTemplate(config map[string]interface{}) *ListTemplate {
    	lt := &ListTemplate{
    		selected: make(map[int]bool),
    	}
    	lt.SetConfig(config)
    	return lt
    }

    func (lt *ListTemplate) SetConfig(config map[string]interface{}) error {
    	lt.BaseTemplate.SetConfig(config)

    	lt.title = lt.getString("title", "Items")
    	lt.multiSelect = lt.getBool("multiSelect", false)
    	lt.searchable = lt.getBool("searchable", false)

    	// Load items if provided
    	if items, ok := config["items"]; ok {
    		if itemSlice, ok := items.([]interface{}); ok {
    			lt.items = make([]ListItem, len(itemSlice))
    			for i, item := range itemSlice {
    				if itemMap, ok := item.(map[string]interface{}); ok {
    					lt.items[i] = ListItem{
    						ID:          getStringValue(itemMap, "id", ""),
    						Title:       getStringValue(itemMap, "title", ""),
    						Description: getStringValue(itemMap, "description", ""),
    						Status:      getStringValue(itemMap, "status", ""),
    						Category:    getStringValue(itemMap, "category", ""),
    						Metadata:    itemMap,
    					}
    				}
    			}
    		}
    	}

    	return lt.Validate()
    }

    func (lt *ListTemplate) Validate() error {
    	if lt.title == "" {
    		return fmt.Errorf("title is required")
    	}
    	return nil
    }

    func (lt *ListTemplate) Init() tea.Cmd {
    	lt.loading = true
    	return nil // Would load data here
    }

    func (lt *ListTemplate) Update(msg tea.Msg) (Template, tea.Cmd) {
    	switch msg := msg.(type) {
    	case tea.KeyMsg:
    		switch msg.String() {
    		case "up", "k":
    			if lt.cursor > 0 {
    				lt.cursor--
    			}
    		case "down", "j":
    			if lt.cursor < len(lt.filteredItems())-1 {
    				lt.cursor++
    			}
    		case " ":
    			if lt.multiSelect {
    				lt.selected[lt.cursor] = !lt.selected[lt.cursor]
    			}
    		case "/":
    			if lt.searchable {
    				lt.filter += "/"
    				// Would enter search mode
    			}
    		case "esc":
    			lt.filter = ""
    			lt.cursor = 0
    		}
    	}
    	return lt, nil
    }

    func (lt *ListTemplate) View() string {
    	if lt.loading {
    		return "Loading..."
    	}

    	if lt.error != nil {
    		return fmt.Sprintf("Error: %s", lt.error)
    	}

    	var output strings.Builder

    	// Title
    	output.WriteString(fmt.Sprintf("🔧 %s\n\n", lt.title))

    	// Filter
    	if lt.searchable && lt.filter != "" {
    		output.WriteString(fmt.Sprintf("Filter: %s\n\n", lt.filter))
    	}

    	// Items
    	filteredItems := lt.filteredItems()
    	for i, item := range filteredItems {
    		cursor := "  "
    		if i == lt.cursor {
    			cursor = "▶ "
    		}

    		checkbox := "  "
    		if lt.multiSelect {
    			if lt.selected[i] {
    				checkbox = "[✓]"
    			} else {
    				checkbox = "[ ]"
    			}
    		}

    		statusIcon := lt.getStatusIcon(item.Status)
    		category := ""
    		if item.Category != "" {
    			category = fmt.Sprintf(" (%s)", item.Category)
    		}

    		output.WriteString(fmt.Sprintf("%s %s %s %s%s\n",
    			cursor, checkbox, statusIcon, item.Title, category))

    		if item.Description != "" && i == lt.cursor {
    			output.WriteString(fmt.Sprintf("    %s\n", item.Description))
    		}
    	}

    	// Footer
    	output.WriteString("\n")
    	if lt.multiSelect {
    		selectedCount := 0
    		for _, selected := range lt.selected {
    			if selected {
    				selectedCount++
    			}
    		}
    		output.WriteString(fmt.Sprintf("[%d/%d selected] ", selectedCount, len(filteredItems)))
    	}

    	if lt.searchable {
    		output.WriteString("[/] Search ")
    	}

    	output.WriteString("[q] Quit")

    	return output.String()
    }

    func (lt *ListTemplate) filteredItems() []ListItem {
    	if lt.filter == "" {
    		return lt.items
    	}

    	var filtered []ListItem
    	filter := strings.ToLower(lt.filter)
    	for _, item := range lt.items {
    		if strings.Contains(strings.ToLower(item.Title), filter) ||
    		   strings.Contains(strings.ToLower(item.Description), filter) {
    			filtered = append(filtered, item)
    		}
    	}
    	return filtered
    }

    func (lt *ListTemplate) getStatusIcon(status string) string {
    	switch status {
    	case "enabled", "active":
    		return "✅"
    	case "disabled", "inactive":
    		return "❌"
    	case "error", "failed":
    		return "❌"
    	case "warning":
    		return "⚠️"
    	default:
    		return "⚪"
    	}
    }

    // Helper function
    func getStringValue(m map[string]interface{}, key, defaultValue string) string {
    	if val, ok := m[key]; ok {
    		if str, ok := val.(string); ok {
    			return str
    		}
    	}
    	return defaultValue
    }
  '';

  # Form Template - For data input
  formTemplate = ''
    package components

    import (
    	tea "${bubbletea-src}"
    	"github.com/charmbracelet/lipgloss"
    	"strings"
    	"fmt"
    )

    // FormField represents a form input field
    type FormField struct {
    	ID          string
    	Label       string
    	Type        string // "text", "password", "select"
    	Value       string
    	Placeholder string
    	Required    bool
    	Validation  func(string) error
    	Options     []string // For select fields
    }

    // FormTemplate handles form input
    type FormTemplate struct {
    	BaseTemplate
    	fields      []FormField
    	focus       int
    	submitting  bool
    	error       error
    	title       string
    	onSubmit    func(map[string]string) tea.Cmd
    	onCancel    func() tea.Cmd
    }

    func NewFormTemplate(config map[string]interface{}) *FormTemplate {
    	ft := &FormTemplate{}
    	ft.SetConfig(config)
    	return ft
    }

    func (ft *FormTemplate) SetConfig(config map[string]interface{}) error {
    	ft.BaseTemplate.SetConfig(config)

    	ft.title = ft.getString("title", "Form")

    	// Load fields
    	if fields, ok := config["fields"]; ok {
    		if fieldSlice, ok := fields.([]interface{}); ok {
    			ft.fields = make([]FormField, len(fieldSlice))
    			for i, field := range fieldSlice {
    				if fieldMap, ok := field.(map[string]interface{}); ok {
    					ft.fields[i] = FormField{
    						ID:          getStringValue(fieldMap, "id", ""),
    						Label:       getStringValue(fieldMap, "label", ""),
    						Type:        getStringValue(fieldMap, "type", "text"),
    						Value:       getStringValue(fieldMap, "value", ""),
    						Placeholder: getStringValue(fieldMap, "placeholder", ""),
    						Required:    getBoolValue(fieldMap, "required", false),
    					}

    					// Load options for select fields
    					if options, ok := fieldMap["options"]; ok {
    						if optSlice, ok := options.([]interface{}); ok {
    							ft.fields[i].Options = make([]string, len(optSlice))
    							for j, opt := range optSlice {
    								ft.fields[i].Options[j] = fmt.Sprintf("%v", opt)
    							}
    						}
    					}
    				}
    			}
    		}
    	}

    	return ft.Validate()
    }

    func (ft *FormTemplate) Validate() error {
    	if ft.title == "" {
    		return fmt.Errorf("title is required")
    	}
    	if len(ft.fields) == 0 {
    		return fmt.Errorf("at least one field is required")
    	}
    	return nil
    }

    func (ft *FormTemplate) Init() tea.Cmd {
    	return nil
    }

    func (ft *FormTemplate) Update(msg tea.Msg) (Template, tea.Cmd) {
    	switch msg := msg.(type) {
    	case tea.KeyMsg:
    		switch msg.String() {
    		case "up", "k":
    			if ft.focus > 0 {
    				ft.focus--
    			}
    		case "down", "j":
    			if ft.focus < len(ft.fields)-1 {
    				ft.focus++
    			}
    		case "enter":
    			if ft.focus == len(ft.fields)-1 {
    				// Submit form
    				if ft.validateForm() {
    					ft.submitting = true
    					values := ft.getFormValues()
    					if ft.onSubmit != nil {
    						return ft, ft.onSubmit(values)
    					}
    				}
    			} else {
    				ft.focusNext()
    			}
    		case "esc":
    			if ft.onCancel != nil {
    				return ft, ft.onCancel()
    			}
    		default:
    			// Handle text input
    			if len(msg.Runes) > 0 {
    				ft.fields[ft.focus].Value += string(msg.Runes)
    			} else if msg.Type == tea.KeyBackspace {
    				if len(ft.fields[ft.focus].Value) > 0 {
    					ft.fields[ft.focus].Value =
    						ft.fields[ft.focus].Value[:len(ft.fields[ft.focus].Value)-1]
    				}
    			}
    		}
    	}
    	return ft, nil
    }

    func (ft *FormTemplate) View() string {
    	if ft.submitting {
    		return "Submitting..."
    	}

    	var output strings.Builder

    	// Title
    	output.WriteString(fmt.Sprintf("📝 %s\n\n", ft.title))

    	// Fields
    	for i, field := range ft.fields {
    		cursor := "  "
    		if i == ft.focus {
    			cursor = "▶ "
    		}

    		value := field.Value
    		if value == "" && i != ft.focus {
    			value = fmt.Sprintf("\x1b[2m%s\x1b[0m", field.Placeholder)
    		}

    		output.WriteString(fmt.Sprintf("%s%s: [%s]\n",
    			cursor, field.Label, value))
    	}

    	// Actions
    	output.WriteString("\n[Enter] Submit  [Esc] Cancel")

    	// Error
    	if ft.error != nil {
    		output.WriteString(fmt.Sprintf("\n\n❌ %s", ft.error))
    	}

    	return output.String()
    }

    func (ft *FormTemplate) validateForm() bool {
    	for _, field := range ft.fields {
    		if field.Required && field.Value == "" {
    			ft.error = fmt.Errorf("%s is required", field.Label)
    			return false
    		}
    		if field.Validation != nil {
    			if err := field.Validation(field.Value); err != nil {
    				ft.error = err
    				return false
    			}
    		}
    	}
    	ft.error = nil
    	return true
    }

    func (ft *FormTemplate) getFormValues() map[string]string {
    	values := make(map[string]string)
    	for _, field := range ft.fields {
    		values[field.ID] = field.Value
    	}
    	return values
    }

    func (ft *FormTemplate) focusNext() {
    	ft.focus = (ft.focus + 1) % len(ft.fields)
    }

    // Helper function
    func getBoolValue(m map[string]interface{}, key string, defaultValue bool) bool {
    	if val, ok := m[key]; ok {
    		if bl, ok := val.(bool); ok {
    			return bl
    		}
    	}
    	return defaultValue
    }
  '';

  # Status Template - For information display
  statusTemplate = ''
    package components

    import (
    	tea "${bubbletea-src}"
    	"github.com/charmbracelet/lipgloss"
    	"strings"
    	"fmt"
    	"time"
    )

    // StatusItem represents a status entry
    type StatusItem struct {
    	Label   string
    	Value   string
    	Status  string // "ok", "warning", "error"
    	Icon    string
    }

    // StatusSection groups related status items
    type StatusSection struct {
    	Title   string
    	Items   []StatusItem
    	Layout  string // "horizontal", "vertical", "grid"
    }

    // StatusTemplate displays status information
    type StatusTemplate struct {
    	BaseTemplate
    	sections    []StatusSection
    	title       string
    	lastUpdate  time.Time
    	autoRefresh bool
    	refreshInterval time.Duration
    	loading     bool
    	error       error
    }

    func NewStatusTemplate(config map[string]interface{}) *StatusTemplate {
    	st := &StatusTemplate{
    		lastUpdate: time.Now(),
    	}
    	st.SetConfig(config)
    	return st
    }

    func (st *StatusTemplate) SetConfig(config map[string]interface{}) error {
    	st.BaseTemplate.SetConfig(config)

    	st.title = st.getString("title", "Status")
    	st.autoRefresh = st.getBool("autoRefresh", false)

    	if interval, ok := config["refreshInterval"]; ok {
    		if dur, ok := interval.(time.Duration); ok {
    			st.refreshInterval = dur
    		}
    	}

    	// Load sections
    	if sections, ok := config["sections"]; ok {
    		if sectSlice, ok := sections.([]interface{}); ok {
    			st.sections = make([]StatusSection, len(sectSlice))
    			for i, sect := range sectSlice {
    				if sectMap, ok := sect.(map[string]interface{}); ok {
    					st.sections[i] = StatusSection{
    						Title:  getStringValue(sectMap, "title", ""),
    						Layout: getStringValue(sectMap, "layout", "vertical"),
    					}

    					// Load items
    					if items, ok := sectMap["items"]; ok {
    						if itemSlice, ok := items.([]interface{}); ok {
    							st.sections[i].Items = make([]StatusItem, len(itemSlice))
    							for j, item := range itemSlice {
    								if itemMap, ok := item.(map[string]interface{}); ok {
    									st.sections[i].Items[j] = StatusItem{
    										Label:  getStringValue(itemMap, "label", ""),
    										Value:  getStringValue(itemMap, "value", ""),
    										Status: getStringValue(itemMap, "status", "ok"),
    										Icon:   getStringValue(itemMap, "icon", "•"),
    									}
    								}
    							}
    						}
    					}
    				}
    			}
    		}
    	}

    	return st.Validate()
    }

    func (st *StatusTemplate) Validate() error {
    	if st.title == "" {
    		return fmt.Errorf("title is required")
    	}
    	return nil
    }

    func (st *StatusTemplate) Init() tea.Cmd {
    	st.loading = true
    	return nil // Would trigger initial data load
    }

    func (st *StatusTemplate) Update(msg tea.Msg) (Template, tea.Cmd) {
    	switch msg := msg.(type) {
    	case tea.KeyMsg:
    		switch msg.String() {
    		case "r":
    			st.loading = true
    			st.lastUpdate = time.Now()
    			return st, st.refreshCmd()
    		}
    	}
    	return st, nil
    }

    func (st *StatusTemplate) View() string {
    	if st.loading {
    		return "Loading status..."
    	}

    	if st.error != nil {
    		return fmt.Sprintf("❌ Error: %s\n\n[r] Retry", st.error)
    	}

    	var output strings.Builder

    	// Title
    	output.WriteString(fmt.Sprintf("📊 %s\n\n", st.title))

    	// Sections
    	for i, section := range st.sections {
    		if section.Title != "" {
    			output.WriteString(fmt.Sprintf("┌─ %s ─┐\n", section.Title))
    		}

    		switch section.Layout {
    		case "horizontal":
    			st.renderHorizontal(&output, section.Items)
    		case "grid":
    			st.renderGrid(&output, section.Items)
    		default: // vertical
    			st.renderVertical(&output, section.Items)
    		}

    		if section.Title != "" {
    			output.WriteString("└─────────────┘\n")
    		}

    		if i < len(st.sections)-1 {
    			output.WriteString("\n")
    		}
    	}

    	// Footer
    	output.WriteString(fmt.Sprintf("\nLast updated: %s",
    		st.lastUpdate.Format("15:04:05")))

    	if st.autoRefresh {
    		output.WriteString(" (auto-refresh enabled)")
    	} else {
    		output.WriteString(" [r] Refresh")
    	}

    	return output.String()
    }

    func (st *StatusTemplate) renderVertical(output *strings.Builder, items []StatusItem) {
    	for _, item := range items {
    		statusColor := st.getStatusColor(item.Status)
    		output.WriteString(fmt.Sprintf("│ %s %s: %s │\n",
    			item.Icon, item.Label, statusColor(item.Value)))
    	}
    }

    func (st *StatusTemplate) renderHorizontal(output *strings.Builder, items []StatusItem) {
    	var parts []string
    	for _, item := range items {
    		statusColor := st.getStatusColor(item.Status)
    		parts = append(parts, fmt.Sprintf("%s %s",
    			item.Icon, statusColor(item.Value)))
    	}
    	output.WriteString(fmt.Sprintf("│ %s │\n", strings.Join(parts, " │ ")))
    }

    func (st *StatusTemplate) renderGrid(output *strings.Builder, items []StatusItem) {
    	// Simple 2-column grid
    	for i := 0; i < len(items); i += 2 {
    		line := "│ "
    		statusColor1 := st.getStatusColor(items[i].Status)
    		line += fmt.Sprintf("%s %s: %s",
    			items[i].Icon, items[i].Label, statusColor1(items[i].Value))

    		if i+1 < len(items) {
    			statusColor2 := st.getStatusColor(items[i+1].Status)
    			line += fmt.Sprintf(" │ %s %s: %s",
    				items[i+1].Icon, items[i+1].Label, statusColor2(items[i+1].Value))
    		}
    		line += " │\n"
    		output.WriteString(line)
    	}
    }

    func (st *StatusTemplate) getStatusColor(status string) func(string) string {
    	switch status {
    	case "error":
    		return func(s string) string { return fmt.Sprintf("\x1b[31m%s\x1b[0m", s) }
    	case "warning":
    		return func(s string) string { return fmt.Sprintf("\x1b[33m%s\x1b[0m", s) }
    	case "ok", "success":
    		return func(s string) string { return fmt.Sprintf("\x1b[32m%s\x1b[0m", s) }
    	default:
    		return func(s string) string { return s }
    	}
    }

    func (st *StatusTemplate) refreshCmd() tea.Cmd {
    	return tea.Cmd(func() tea.Msg {
    		// Simulate refresh
    		time.Sleep(100 * time.Millisecond)
    		return refreshCompleteMsg{}
    	})
    }
  '';

in {
  # Export all templates
  inherit templateInterface listTemplate formTemplate statusTemplate;

  # Combined templates.go file
  templatesGo = pkgs.writeText "templates.go" ''
    package components

    import (
    	tea "${bubbletea-src}"
    )

    ${templateInterface}

    ${listTemplate}

    ${formTemplate}

    ${statusTemplate}

    // Message types
    type refreshCompleteMsg struct{}
  '';
}
