package tui

import (
	"encoding/json"
	"os/exec"

	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type ModuleItem struct {
	Name            string `json:"name"`
	DescriptionText string `json:"description"`
	Status          string `json:"status"`
	Category        string `json:"category"`
	Path            string `json:"path"`
	Action          string `json:"action"`
	Args            []ActionArg `json:"args"`
	Actions         []ActionDef `json:"actions"`
}

type ActionArg struct {
	Name    string `json:"name"`
	Prompt  string `json:"prompt"`
	Secret  bool   `json:"secret"`
	Default string `json:"default"`
}

type ActionDef struct {
	Name  string      `json:"name"`
	Label string      `json:"label"`
	Args  []ActionArg `json:"args"`
}

func (i ModuleItem) Title() string       { return i.Name }
func (i ModuleItem) Description() string { return i.DescriptionText }
func (i ModuleItem) FilterValue() string { return i.Name }

type Model struct {
	spinner  spinner.Model
	keys     *keyMap
	list     list.Model
	help     help.Model
	docStyle lipgloss.Style
	modules  []ModuleItem

	// Nix function commands from template
	getListCmd    string
	getFilterCmd  string
	getDetailsCmd string
	getActionsCmd string
	getStatsCmd   string

	// 5-panel layout state
	selectedModule ModuleItem
	showDetails    bool
	filterStatus   string
	searchTerm     string

	// Panel contents
	menuPanel    string
	contentPanel string
	filterPanel  string
	infoPanel    string
	statsPanel   string

	// Responsive design
	width  int
	height int

	// Action dialog / prompt state
	uiState         UIState
	actionIndex     int
	selectedAction  ActionDef
	promptInputs    []textinput.Model
	promptArgs      []ActionArg
	promptIndex     int

	// Scrollable viewports for all panels
	contentViewport viewport.Model
	menuViewport    viewport.Model
	filterViewport  viewport.Model
	infoViewport    viewport.Model
	statsViewport   viewport.Model
}

type UIState int

const (
	StateNormal UIState = iota
	StateActionDialog
	StatePrompt
)

func NewModel(modules []ModuleItem, getListCmd, getFilterCmd, getDetailsCmd, getActionsCmd, getStatsCmd string) Model {
	// Create list items from modules
	items := make([]list.Item, len(modules))
	for i, module := range modules {
		items[i] = module
	}

	// Initialize list (single-line delegate)
	delegate := list.NewDefaultDelegate()
	delegate.ShowDescription = false
	delegate.SetSpacing(0)
	delegate.SetHeight(1)
	l := list.New(items, delegate, 0, 0)
	// No list title for FZF-like output
	l.Title = ""
	l.SetShowTitle(false)
	l.SetShowStatusBar(false)
	l.SetShowHelp(false)

	// Initialize other components
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	h := help.New()

	// Create document style
	docStyle := lipgloss.NewStyle()

	// Initialize viewports for all panels
	contentVp := viewport.New(30, 15) // Will be resized dynamically
	menuVp := viewport.New(25, 15)    // Will be resized dynamically
	filterVp := viewport.New(20, 15)  // Will be resized dynamically
	infoVp := viewport.New(20, 15)    // Will be resized dynamically
	statsVp := viewport.New(15, 15)   // Will be resized dynamically

	model := Model{
		spinner:         s,
		keys:            newKeyMap(),
		list:            l,
		help:            h,
		docStyle:        docStyle,
		modules:         modules,
		getListCmd:      getListCmd,
		getFilterCmd:    getFilterCmd,
		getDetailsCmd:   getDetailsCmd,
		getActionsCmd:   getActionsCmd,
		getStatsCmd:     getStatsCmd,
		filterStatus:    "all",
		showDetails:     false,
		width:           120, // Default width
		height:          30,  // Default height
		contentViewport: contentVp,
		menuViewport:    menuVp,
		filterViewport:  filterVp,
		infoViewport:    infoVp,
		statsViewport:   statsVp,
		uiState:         StateNormal,
		actionIndex:     0,
	}

	// Initialize viewport content
	model.updatePanels()

	return model
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(
		tea.EnterAltScreen,
		m.spinner.Tick,
	)
}

func GetModulesFromNixFunction(nixCmd string) ([]ModuleItem, error) {
	cmd := exec.Command("bash", "-c", nixCmd)
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	var modules []ModuleItem
	if err := json.Unmarshal(output, &modules); err != nil {
		return nil, err
	}
	return modules, nil
}
