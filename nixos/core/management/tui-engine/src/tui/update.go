package tui

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
)

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch {
	case key.Matches(msg, m.keys.runAction):
			if m.list.SelectedItem() != nil {
				selected := m.list.SelectedItem().(ModuleItem)
				return m, m.runSelectedActionCmd(selected)
			}

		case key.Matches(msg, m.keys.toggle):
			// Toggle details view
			m.showDetails = !m.showDetails
			return m, nil

		case key.Matches(msg, m.keys.enable):
			// Enable selected module
			if m.list.SelectedItem() != nil {
				selected := m.list.SelectedItem().(ModuleItem)
				return m, m.enableModuleCmd(selected.Name)
			}

		case key.Matches(msg, m.keys.disable):
			// Disable selected module
			if m.list.SelectedItem() != nil {
				selected := m.list.SelectedItem().(ModuleItem)
				return m, m.disableModuleCmd(selected.Name)
			}

		case key.Matches(msg, m.keys.refresh):
			// Refresh modules
			return m, refreshModulesCmd()
		}

	case tea.WindowSizeMsg:
		// Handle window resize - update dimensions and recalculate layout
		m.width = msg.Width
		m.height = msg.Height

		// Allow small terminals; emergency layout will handle sizing

		// Update list size based on available space
		h, v := m.docStyle.GetFrameSize()
		m.list.SetSize(msg.Width-h, msg.Height-v)

		// Update viewport sizes dynamically
		headerHeight := 4 // Account for borders and padding
		viewportHeight := max(10, msg.Height-headerHeight)

		// Calculate panel widths based on available space
		menuWidth := max(20, msg.Width/6)
		contentWidth := max(25, msg.Width/4)
		filterWidth := max(15, msg.Width/8)
		infoWidth := max(20, msg.Width/6)
		statsWidth := max(15, msg.Width/8)

		// Update all viewport dimensions
		m.menuViewport.Width = menuWidth
		m.menuViewport.Height = viewportHeight

		m.contentViewport.Width = contentWidth
		m.contentViewport.Height = viewportHeight

		m.filterViewport.Width = filterWidth
		m.filterViewport.Height = viewportHeight

		m.infoViewport.Width = infoWidth
		m.infoViewport.Height = viewportHeight

		m.statsViewport.Width = statsWidth
		m.statsViewport.Height = viewportHeight

		// Force panel recalculation with new dimensions
		m.updatePanels()

	case spinner.TickMsg:
		// Update spinner
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case ModuleEnabledMsg:
		// Handle module enabled
		// TODO: Update module status and refresh list
		return m, nil

	case ModuleDisabledMsg:
		// Handle module disabled
		// TODO: Update module status and refresh list
		return m, nil

	case ActionExecutedMsg:
		// Action executed - no state change yet
		return m, nil

	case ModulesRefreshedMsg:
		// Handle modules refreshed
		// TODO: Update modules list
		return m, nil
	}

	// Update list
	var cmd tea.Cmd
	m.list, cmd = m.list.Update(msg)

	// Update all viewports for scrolling
	var menuCmd tea.Cmd
	var contentCmd tea.Cmd
	var filterCmd tea.Cmd
	var infoCmd tea.Cmd
	var statsCmd tea.Cmd

	m.menuViewport, menuCmd = m.menuViewport.Update(msg)
	m.contentViewport, contentCmd = m.contentViewport.Update(msg)
	m.filterViewport, filterCmd = m.filterViewport.Update(msg)
	m.infoViewport, infoCmd = m.infoViewport.Update(msg)
	m.statsViewport, statsCmd = m.statsViewport.Update(msg)

	// Update selected module and panels
	if m.list.SelectedItem() != nil {
		m.selectedModule = m.list.SelectedItem().(ModuleItem)
	}
	m.updatePanels()

	// Combine commands
	cmds := []tea.Cmd{cmd, menuCmd, contentCmd, filterCmd, infoCmd, statsCmd}
	return m, tea.Batch(cmds...)
}

// Commands for module operations
func (m Model) enableModuleCmd(moduleName string) tea.Cmd {
	return func() tea.Msg {
		// Use the toggle module script from actions.nix
		err := exec.Command("bash", "-c", fmt.Sprintf("echo 'Enable %s' # TODO: Call actual toggle script", moduleName)).Run()
		if err != nil {
			return ModuleEnabledMsg{Error: err}
		}
		return ModuleEnabledMsg{Success: true, ModuleName: moduleName}
	}
}

func (m Model) disableModuleCmd(moduleName string) tea.Cmd {
	return func() tea.Msg {
		// Use the toggle module script from actions.nix
		err := exec.Command("bash", "-c", fmt.Sprintf("echo 'Disable %s' # TODO: Call actual toggle script", moduleName)).Run()
		if err != nil {
			return ModuleDisabledMsg{Error: err}
		}
		return ModuleDisabledMsg{Success: true, ModuleName: moduleName}
	}
}

func refreshModulesCmd() tea.Cmd {
	return func() tea.Msg {
		// TODO: Call runtime discovery and return updated modules
		return ModulesRefreshedMsg{}
	}
}

// Run selected action via NCC_TUI_ACTION_CMD
func (m Model) runSelectedActionCmd(selected ModuleItem) tea.Cmd {
	return func() tea.Msg {
		cmdTemplate := os.Getenv("NCC_TUI_ACTION_CMD")
		if cmdTemplate == "" {
			return ActionExecutedMsg{Success: false, Error: fmt.Errorf("NCC_TUI_ACTION_CMD not set")}
		}
		cmdStr := strings.ReplaceAll(cmdTemplate, "{name}", selected.Name)
		err := exec.Command("bash", "-c", cmdStr).Run()
		if err != nil {
			return ActionExecutedMsg{Success: false, Error: err}
		}
		return ActionExecutedMsg{Success: true}
	}
}

// Messages
type ModuleEnabledMsg struct {
	Success    bool
	ModuleName string
	Error      error
}

type ModuleDisabledMsg struct {
	Success    bool
	ModuleName string
	Error      error
}

type ModulesRefreshedMsg struct {
	Modules []ModuleItem
	Error   error
}

type ActionExecutedMsg struct {
	Success bool
	Error   error
}
