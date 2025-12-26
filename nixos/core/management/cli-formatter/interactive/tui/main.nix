{ lib, bubbletea-src ? "github.com/charmbracelet/bubbletea" }:

let
  mainCode = ''
    package main

    import (
    	"fmt"
    	"os"
    	tea "${bubbletea-src}"
    	"./components"
    )

    // MainModel is the root model for the TUI
    type MainModel struct {
    	currentView string
    	quit        bool
    }

    func (m MainModel) Init() tea.Cmd {
    	return nil
    }

    func (m MainModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    	switch msg := msg.(type) {
    	case tea.KeyMsg:
    		switch msg.String() {
    		case "q", "ctrl+c":
    			m.quit = true
    			return m, tea.Quit
    		case "?":
    			// Show help
    			return m, nil
    		}
    	}
    	return m, nil
    }

    func (m MainModel) View() string {
    	if m.quit {
    		return "Goodbye! 👋"
    	}

    	return fmt.Sprintf('''
    🔧 NixOS Control Center TUI

    Welcome to the modern terminal interface for managing your NixOS system.

    Available commands:
    • module-manager    - Manage NixOS modules
    • system-manager    - System operations
    • ssh-manager       - SSH client management

    Navigation:
    • Use arrow keys or vim keys (h/j/k/l) to navigate
    • Space to select/deselect items
    • Enter to execute actions
    • ? for help, q to quit

    Choose a manager to get started!

    [q] Quit
    	''')
    }

    func main() {
    	// Check command line arguments
    	if len(os.Args) > 1 {
    		switch os.Args[1] {
    		case "module-manager":
    			runModuleManager()
    		case "system-manager":
    			runSystemManager()
    		case "ssh-manager":
    			runSSHManager()
    		default:
    			fmt.Printf("Unknown command: %s\n", os.Args[1])
    			fmt.Println("Available: module-manager, system-manager, ssh-manager")
    			os.Exit(1)
    		}
    	} else {
    		// Run main menu
    		p := tea.NewProgram(MainModel{})
    		if _, err := p.Run(); err != nil {
    			fmt.Printf("Error: %v", err)
    			os.Exit(1)
    		}
    	}
    }

    func runModuleManager() {
    	// TODO: Implement module manager
    	fmt.Println("Module Manager - Coming Soon!")
    }

    func runSystemManager() {
    	// TODO: Implement system manager
    	fmt.Println("System Manager - Coming Soon!")
    }

    func runSSHManager() {
    	// TODO: Implement SSH manager
    	fmt.Println("SSH Manager - Coming Soon!")
    }
  '';
in
pkgs.writeText "main.go" mainCode
