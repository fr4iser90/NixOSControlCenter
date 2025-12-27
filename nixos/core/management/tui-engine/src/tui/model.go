package tui

import (
	"github.com/charmbracelet/bubbles/help"
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type ModuleItem struct {
	Name            string `json:"name"`
	DescriptionText string `json:"description"`
	Status          string `json:"status"`
	Category        string `json:"category"`
	Path            string `json:"path"`
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
}

func NewModel(modules []ModuleItem, getListCmd, getFilterCmd, getDetailsCmd, getActionsCmd string) Model {
	// Create list items from modules
	items := make([]list.Item, len(modules))
	for i, module := range modules {
		items[i] = module
	}

	// Initialize list
	l := list.New(items, list.NewDefaultDelegate(), 0, 0)
	l.Title = "📦 Module Manager"

	// Initialize other components
	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	h := help.New()

	// Create document style
	docStyle := lipgloss.NewStyle()

	return Model{
		spinner:      s,
		keys:         newKeyMap(),
		list:         l,
		help:         h,
		docStyle:     docStyle,
		modules:      modules,
		getListCmd:   getListCmd,
		getFilterCmd: getFilterCmd,
		getDetailsCmd: getDetailsCmd,
		getActionsCmd: getActionsCmd,
		filterStatus: "all",
		showDetails:  false,
	}
}

func (m Model) Init() tea.Cmd {
	return m.spinner.Tick
}
