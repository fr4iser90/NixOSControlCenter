package main

import (
	"log"
	"os"
	"os/exec"
	"encoding/json"

	tea "github.com/charmbracelet/bubbletea"
	"tui-engine/src/tui"
)

func main() {
	// log.Println("🐛 DEBUG: Go binary started!")

	// Parse command line arguments from Nix template
	// Args: [program] [getListCmd] [getFilterCmd] [getDetailsCmd] [getActionsCmd]
	args := os.Args
	// log.Println("🐛 DEBUG: Received %d command line args: %v", len(args), args)

	if len(args) < 5 {
		log.Fatal("Usage: program getListCmd getFilterCmd getDetailsCmd getActionsCmd")
	}

	getListCmd := args[1]
	getFilterCmd := args[2]
	getDetailsCmd := args[3]
	getActionsCmd := args[4]

	// log.Println("🐛 DEBUG: getListCmd: %s", getListCmd)
	// log.Println("🐛 DEBUG: getFilterCmd: %s", getFilterCmd)
	// log.Println("🐛 DEBUG: getDetailsCmd: %s", getDetailsCmd)
	// log.Println("🐛 DEBUG: getActionsCmd: %s", getActionsCmd)

	// Get initial modules from runtime discovery via getListCmd
	// log.Println("🐛 DEBUG: Getting modules from Nix function...")
	modules, err := getModulesFromNixFunction(getListCmd)
	if err != nil {
		// log.Println("🐛 DEBUG: Failed to get modules: %v", err)
		log.Fatal("Failed to get modules:", err)
	}
	// log.Println("🐛 DEBUG: Got %d modules", len(modules))

	// Create TUI model with Nix function commands
	// log.Println("🐛 DEBUG: Creating TUI model...")
	model := tui.NewModel(modules, getListCmd, getFilterCmd, getDetailsCmd, getActionsCmd)

	// Start Bubble Tea program
	// log.Println("🐛 DEBUG: Starting Bubble Tea program...")
	p := tea.NewProgram(model, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		// log.Println("🐛 DEBUG: TUI error: %v", err)
		log.Fatal("TUI error:", err)
	}

	// log.Println("🐛 DEBUG: Bubble Tea program finished")
}

func getModulesFromNixFunction(nixCmd string) ([]tui.ModuleItem, error) {
	// log.Println("🐛 DEBUG: Executing Nix command: %s", nixCmd)

	// Execute the Nix function to get module list
	cmd := exec.Command("bash", "-c", nixCmd)
	output, err := cmd.Output()
	if err != nil {
		// log.Println("🐛 DEBUG: Command failed: %v", err)
		return nil, err
	}

	// log.Println("🐛 DEBUG: Command output: %s", string(output))

	// Parse output as JSON array directly
	var modules []tui.ModuleItem
	err = json.Unmarshal(output, &modules)
	if err != nil {
		// log.Println("🐛 DEBUG: JSON parse error: %v", err)
		return nil, err
	}

	// log.Println("🐛 DEBUG: Parsed %d modules from JSON", len(modules))
	return modules, nil
}