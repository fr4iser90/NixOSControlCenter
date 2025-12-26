{ lib, bubbletea-src ? "github.com/charmbracelet/bubbletea" }:

let
  listCode = ''
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
    	Status      string
    	Category    string
    	Metadata    map[string]interface{}
    }

    // ListTemplate handles item selection lists
    type ListTemplate struct {
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

    	// Load config
    	if title, ok := config["title"].(string); ok {
    		lt.title = title
    	} else {
    		lt.title = "Items"
    	}

    	if multi, ok := config["multiSelect"].(bool); ok {
    		lt.multiSelect = multi
    	}

    	if search, ok := config["searchable"].(bool); ok {
    		lt.searchable = search
    	}

    	// Load items
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

    	return lt
    }

    func (lt *ListTemplate) Init() tea.Cmd {
    	lt.loading = true
    	return nil
    }

    func (lt *ListTemplate) Update(msg tea.Msg) (interface{}, tea.Cmd) {
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
    	filter := strings.ToLower(strings.TrimPrefix(lt.filter, "/"))
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

    func getStringValue(m map[string]interface{}, key, defaultValue string) string {
    	if val, ok := m[key]; ok {
    		if str, ok := val.(string); ok {
    			return str
    		}
    	}
    	return defaultValue
    }
  '';
in
pkgs.writeText "list.go" listCode
