{ lib, bubbletea-src ? "github.com/charmbracelet/bubbletea" }:

let
  statusCode = ''
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
    	Status  string
    	Icon    string
    }

    // StatusSection groups related status items
    type StatusSection struct {
    	Title   string
    	Items   []StatusItem
    	Layout  string
    }

    // StatusTemplate displays status information
    type StatusTemplate struct {
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

    	// Load config
    	if title, ok := config["title"].(string); ok {
    		st.title = title
    	} else {
    		st.title = "Status"
    	}

    	if autoRefresh, ok := config["autoRefresh"].(bool); ok {
    		st.autoRefresh = autoRefresh
    	}

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

    	return st
    }

    func (st *StatusTemplate) Init() tea.Cmd {
    	st.loading = true
    	return nil
    }

    func (st *StatusTemplate) Update(msg tea.Msg) (interface{}, tea.Cmd) {
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
    		st.loading = false
    		return refreshCompleteMsg{}
    	})
    }
  '';
in
pkgs.writeText "status.go" statusCode
