package tui

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/key"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/bubbles/list"
)

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		// Prompt mode
		if m.uiState == StatePrompt {
			switch msg.String() {
			case "enter":
				if m.promptIndex < len(m.promptInputs)-1 {
					m.promptIndex++
					m.promptInputs[m.promptIndex].Focus()
					return m, nil
				}
				return m, m.runPromptedActionCmd()
			case "esc":
				m.uiState = StateNormal
				return m, nil
			}
			var cmd tea.Cmd
			m.promptInputs[m.promptIndex], cmd = m.promptInputs[m.promptIndex].Update(msg)
			return m, cmd
		}

		// Action dialog mode
		if m.uiState == StateActionDialog {
			switch msg.String() {
			case "up", "k":
				if m.actionIndex > 0 {
					m.actionIndex--
				}
				return m, nil
			case "down", "j":
				if m.actionIndex < len(m.selectedModule.Actions)-1 {
					m.actionIndex++
				}
				return m, nil
			case "enter":
				return m, m.startSelectedAction()
			case "esc":
				m.uiState = StateNormal
				return m, nil
			}
		}

		switch {
		case key.Matches(msg, m.keys.runAction):
			if m.list.SelectedItem() != nil {
				selected := m.list.SelectedItem().(ModuleItem)
				m.selectedModule = selected
				if len(selected.Actions) > 0 {
					m.uiState = StateActionDialog
					m.actionIndex = 0
					return m, nil
				}
				return m, m.runSelectedActionCmd(selected, selected.Action, selected.Args)
			}

		case key.Matches(msg, m.keys.connect):
			return m, m.runShortcutAction("connect")
		case key.Matches(msg, m.keys.delete):
			return m, m.runShortcutAction("delete")
		case key.Matches(msg, m.keys.edit):
			return m, m.runShortcutAction("edit")
		case key.Matches(msg, m.keys.newItem):
			return m, m.runShortcutAction("add")

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
		// Action executed - refresh list and return to normal state
		m.uiState = StateNormal
		return m, refreshModulesCmd()

	case ModulesRefreshedMsg:
		if msg.Error != nil {
			return m, nil
		}
		m.modules = msg.Modules
		items := make([]list.Item, len(msg.Modules))
		for i, module := range msg.Modules {
			items[i] = module
		}
		m.list.SetItems(items)
		m.updatePanels()
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
		modules, err := GetModulesFromNixFunction(getEnvCmd("NCC_TUI_LIST_CMD"))
		if err != nil {
			return ModulesRefreshedMsg{Error: err}
		}
		return ModulesRefreshedMsg{Modules: modules}
	}
}

// Run selected action via NCC_TUI_ACTION_CMD
func (m Model) runSelectedActionCmd(selected ModuleItem, action string, args []ActionArg) tea.Cmd {
	return func() tea.Msg {
		cmdTemplate := os.Getenv("NCC_TUI_ACTION_CMD")
		if cmdTemplate == "" {
			return ActionExecutedMsg{Success: false, Error: fmt.Errorf("NCC_TUI_ACTION_CMD not set")}
		}
		cmdStr := strings.ReplaceAll(cmdTemplate, "{name}", selected.Name)
		cmdStr = strings.ReplaceAll(cmdStr, "{action}", action)
		for _, arg := range args {
			cmdStr = strings.ReplaceAll(cmdStr, "{arg:"+arg.Name+"}", arg.Default)
		}
		err := exec.Command("bash", "-c", cmdStr).Run()
		if err != nil {
			return ActionExecutedMsg{Success: false, Error: err}
		}
		return ActionExecutedMsg{Success: true}
	}
}

func (m Model) startSelectedAction() tea.Cmd {
	if m.actionIndex < 0 || m.actionIndex >= len(m.selectedModule.Actions) {
		m.uiState = StateNormal
		return nil
	}
	selectedAction := m.selectedModule.Actions[m.actionIndex]
	if len(selectedAction.Args) == 0 {
		return m.runSelectedActionCmd(m.selectedModule, selectedAction.Name, selectedAction.Args)
	}
	m.selectedAction = selectedAction
	m.promptArgs = selectedAction.Args
	m.promptInputs = make([]textinput.Model, len(selectedAction.Args))
	for i, arg := range selectedAction.Args {
		input := textinput.New()
		input.Placeholder = arg.Prompt
		input.Prompt = arg.Name + ": "
		if arg.Default != "" {
			input.SetValue(arg.Default)
		}
		if arg.Secret {
			input.EchoMode = textinput.EchoPassword
			input.EchoCharacter = '•'
		}
		if i == 0 {
			input.Focus()
		}
		m.promptInputs[i] = input
	}
	m.promptIndex = 0
	m.uiState = StatePrompt
	return nil
}

func (m Model) runShortcutAction(name string) tea.Cmd {
	if m.list.SelectedItem() == nil {
		return nil
	}
	selected := m.list.SelectedItem().(ModuleItem)
	for _, action := range selected.Actions {
		if action.Name == name {
			m.selectedModule = selected
			m.selectedAction = action
			if len(action.Args) == 0 {
				return m.runSelectedActionCmd(selected, action.Name, action.Args)
			}
			m.promptArgs = action.Args
			m.promptInputs = make([]textinput.Model, len(action.Args))
			for i, arg := range action.Args {
				input := textinput.New()
				input.Placeholder = arg.Prompt
				input.Prompt = arg.Name + ": "
				if arg.Default != "" {
					input.SetValue(arg.Default)
				}
				if arg.Secret {
					input.EchoMode = textinput.EchoPassword
					input.EchoCharacter = '•'
				}
				if i == 0 {
					input.Focus()
				}
				m.promptInputs[i] = input
			}
			m.promptIndex = 0
			m.uiState = StatePrompt
			return nil
		}
	}
	return nil
}

func (m Model) runPromptedActionCmd() tea.Cmd {
	for i := range m.promptArgs {
		m.promptArgs[i].Default = m.promptInputs[i].Value()
	}
	selected := m.selectedModule
	action := m.selectedAction.Name
	args := m.promptArgs
	m.uiState = StateNormal
	return m.runSelectedActionCmd(selected, action, args)
}

func getEnvCmd(key string) string {
	return os.Getenv(key)
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
