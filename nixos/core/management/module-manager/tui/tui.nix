# Module Manager Bubble Tea TUI
# Generates the complete Go code for the interactive module management interface

{ lib, pkgs, getModuleApi, discoveryScript, ... }:

let
  # API pattern like other modules use
  ui = getModuleApi "cli-formatter";
  tuiHelpers = ui.tui.helpers;

  # Module Manager TUI Code
  moduleManagerCode = ''
    package main

    import (
	"fmt"
	"log"
	"regexp"
	"strings"
	tea "github.com/charmbracelet/bubbletea"
)

    // Module represents a NixOS module
    type Module struct {
    	ID          string
    	Name        string
    	Description string
    	Category    string
    	Status      string // "enabled", "disabled", "error"
    	Path        string
    }

// ModuleManagerModel is the main model for module management
type ModuleManagerModel struct {
	modules         []Module
	cursor          int
	selected        map[int]bool
	loading         bool
	lastAction      string
	error           error
}

// Messages
type modulesLoadedMsg struct {
	modules []Module
}

type actionCompleteMsg struct {
	action string
	result string
}

type errorMsg struct {
	err error
}

func (m ModuleManagerModel) Init() tea.Cmd {
	m.loading = true
	m.selected = make(map[int]bool)
	return m.loadModules()
}

    func (m ModuleManagerModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    	switch msg := msg.(type) {
    	case modulesLoadedMsg:
    		m.modules = msg.modules
    		m.loading = false

    		// Convert modules to list items
    		listItems := make([]map[string]interface{}, len(m.modules))
    		for i, mod := range m.modules {
    			listItems[i] = map[string]interface{}{
    				"id":          mod.ID,
    				"title":       mod.Name,
    				"description": mod.Description,
    				"status":      mod.Status,
    				"category":    mod.Category,
    			}
    		}

    		// Configure list template
    		config := map[string]interface{}{
    			"title":       "Available Modules",
    			"items":       listItems,
    			"multiSelect": true,
    			"searchable":  true,
    		}
    		m.listTemplate = components.NewListTemplate(config)

    		return m, nil

    	case actionCompleteMsg:
    		m.lastAction = msg.action
    		// Refresh modules after action
    		return m, m.loadModules()

    	case errorMsg:
    		m.error = msg.err
    		m.loading = false
    		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit

		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}

		case "down", "j":
			if m.cursor < len(m.modules)-1 {
				m.cursor++
			}

		case " ":
			if m.selected == nil {
				m.selected = make(map[int]bool)
			}
			m.selected[m.cursor] = !m.selected[m.cursor]

		case "e":
			selectedModules := m.getSelectedModules()
			if len(selectedModules) > 0 {
				return m, m.enableModulesCmd(selectedModules)
			}

		case "d":
			selectedModules := m.getSelectedModules()
			if len(selectedModules) > 0 {
				return m, m.disableModulesCmd(selectedModules)
			}

		case "r":
			m.loading = true
			return m, m.loadModules()
		}
	}
	return m, nil
    }

func (m ModuleManagerModel) View() string {
	if m.loading {
		return "🔄 Loading modules..."
	}

	if m.error != nil {
		return fmt.Sprintf("❌ Error: %s\n\n[r] Retry  [q] Quit", m.error)
	}

	var output strings.Builder

	// Header
	output.WriteString("🔧 Module Manager - Interactive Module Management\n\n")

	// Module list
	for i, mod := range m.modules {
		cursor := "  "
		if i == m.cursor {
			cursor = "▶ "
		}

		checkbox := "[ ]"
		if m.selected[i] {
			checkbox = "[✓]"
		}

		statusIcon := "⚪"
		if mod.Status == "enabled" {
			statusIcon = "✅"
		} else if mod.Status == "disabled" {
			statusIcon = "❌"
		}

		output.WriteString(fmt.Sprintf("%s %s %s %s (%s)\n",
			cursor, checkbox, statusIcon, mod.Name, mod.Category))
	}

	// Footer
	output.WriteString("\n")
	if m.lastAction != "" {
		output.WriteString(fmt.Sprintf("Last action: %s\n", m.lastAction))
	}

	output.WriteString("[e] Enable  [d] Disable  [r] Refresh  [q] Quit")

	return output.String()
}

    func (m ModuleManagerModel) loadModules() tea.Cmd {
    	return tea.Cmd(func() tea.Msg {
    		// Execute discovery script directly
    		cmd := exec.Command("ncc", "module-manager", "get-module-data")
    		output, err := cmd.Output()
    		if err != nil {
    			return errorMsg{fmt.Errorf("Failed to load modules: %v\nOutput: %s", err, string(output))}
    		}

    		// Parse JSON output into modules
    		modules, err := parseModulesJSON(string(output))
    		if err != nil {
    			return errorMsg{err}
    		}

    		return modulesLoadedMsg{modules}
    	})
    }

    func (m ModuleManagerModel) enableModulesCmd(modules []Module) tea.Cmd {
    	return tea.Cmd(func() tea.Msg {
    		args := []string{"module-manager", "enable"}
    		for _, mod := range modules {
    			args = append(args, mod.ID)
    		}

    		cmd := exec.Command("ncc", args...)
    		output, err := cmd.Output()
    		if err != nil {
    			return errorMsg{err}
    		}

    		return actionCompleteMsg{
    			action: fmt.Sprintf("Enabled %d modules", len(modules)),
    			result: string(output),
    		}
    	})
    }

    func (m ModuleManagerModel) disableModulesCmd(modules []Module) tea.Cmd {
    	return tea.Cmd(func() tea.Msg {
    		args := []string{"module-manager", "disable"}
    		for _, mod := range modules {
    			args = append(args, mod.ID)
    		}

    		cmd := exec.Command("ncc", args...)
    		output, err := cmd.Output()
    		if err != nil {
    			return errorMsg{err}
    		}

    		return actionCompleteMsg{
    			action: fmt.Sprintf("Disabled %d modules", len(modules)),
    			result: string(output),
    		}
    	})
    }

    func (m ModuleManagerModel) getSelectedModules() []Module {
    	var selected []Module
    	for i, mod := range m.modules {
    		if m.selected[i] {
    			selected = append(selected, mod)
    		}
    	}
    	return selected
    }

func (m ModuleManagerModel) getSelectedModules() []Module {
	var selected []Module
	for i, mod := range m.modules {
		if m.selected[i] {
			selected = append(selected, mod)
		}
	}
	return selected
}

    // Helper functions
    func parseModulesJSON(jsonStr string) ([]Module, error) {
    	// Parse JSON array of modules
    	var modules []Module

    	// Simple JSON parsing (in a real implementation, use encoding/json)
    	// For now, parse the basic structure
    	lines := strings.Split(strings.TrimSpace(jsonStr), "\n")

    	for _, line := range lines {
    		line = strings.TrimSpace(line)
    		if line == "[" || line == "]" || line == "" {
    			continue
    		}
    		if strings.HasSuffix(line, ",") {
    			line = line[:len(line)-1]
    		}

    		// Simple field extraction (this is a basic implementation)
    		if strings.Contains(line, `"id"`) {
    			var module Module

    			// Extract id
    			if idMatch := regexp.MustCompile(`"id":\s*"([^"]*)"`).FindStringSubmatch(line); len(idMatch) > 1 {
    				module.ID = idMatch[1]
    				module.Name = idMatch[1]
    			}

    			// Extract description
    			if descMatch := regexp.MustCompile(`"description":\s*"([^"]*)"`).FindStringSubmatch(line); len(descMatch) > 1 {
    				module.Description = descMatch[1]
    			}

    			// Extract category
    			if catMatch := regexp.MustCompile(`"category":\s*"([^"]*)"`).FindStringSubmatch(line); len(catMatch) > 1 {
    				module.Category = catMatch[1]
    			}

    			// Extract status
    			if statusMatch := regexp.MustCompile(`"status":\s*"([^"]*)"`).FindStringSubmatch(line); len(statusMatch) > 1 {
    				module.Status = statusMatch[1]
    			}

    			// Extract path
    			if pathMatch := regexp.MustCompile(`"path":\s*"([^"]*)"`).FindStringSubmatch(line); len(pathMatch) > 1 {
    				module.Path = pathMatch[1]
    			}

    			if module.ID != "" {
    				modules = append(modules, module)
    			}
    		}
    	}

    	return modules, nil
    }

    func main() {
    	p := tea.NewProgram(ModuleManagerModel{
    		selected: make(map[int]bool),
    	})

    	if _, err := p.Run(); err != nil {
    		fmt.Printf("Error: %v", err)
    		os.Exit(1)
    	}
    }
  '';

in
  # SCHRITT 1: Einfache funktionierende Version OHNE Bubble Tea
  # Das kompiliert garantiert!
  let
    workingCode = ''
      package main

      import (
        "fmt"
        "log"
        "os/exec"
        "strings"
      )

      var discoveryScriptFile = "discoveryScriptFile"

      func main() {
        log.Println("🔧 Module Manager TUI")
        log.Println("✅ Build funktioniert!")
        log.Println("🚀 Bubble Tea Features kommen als nächstes")
        log.Println("")

        // Test runtime discovery
        log.Println("📦 Lade Module...")
        cmd := exec.Command("bash", discoveryScriptFile)
        output, err := cmd.Output()
        if err != nil {
          log.Printf("❌ Fehler beim Laden: %v\n", err)
        } else {
          lines := strings.Split(strings.TrimSpace(string(output)), "\n")
          log.Printf("✅ %d Module gefunden\n", len(lines))
          for i, line := range lines[:min(5, len(lines))] {
            log.Printf("  %d. %s\n", i+1, line)
          }
          if len(lines) > 5 {
            log.Printf("  ... und %d weitere\n", len(lines)-5)
          }
        }

        log.Println("")
        log.Println("[Drücke Enter zum Beenden]")
        fmt.Scanln()
      }

      func min(a, b int) int {
        if a < b {
          return a
        }
        return b
      }
    '';
  in
  let
    # Create discovery script file
    discoveryScriptFile = pkgs.writeScript "module-discovery.sh" discoveryScript;
  in
  # Fix Go build cache permissions
  pkgs.runCommand "module-manager-tui" {
    buildInputs = [ pkgs.go ];
    inherit discoveryScriptFile;
  } ''
    mkdir -p $out/bin

    # Set up Go build environment
    export GOPATH=$TMPDIR/go
    export GOCACHE=$TMPDIR/go-cache
    mkdir -p $GOPATH $GOCACHE

    cat > temp.go << 'EOF'
  ${workingCode}
  EOF

    # Replace the discovery script placeholder with the actual script
    sed -i "s|\"discoveryScriptFile\"|\"$discoveryScriptFile\"|g" temp.go

    # Build with proper Go environment
    go build -o $out/bin/module-manager-tui temp.go
  ''
