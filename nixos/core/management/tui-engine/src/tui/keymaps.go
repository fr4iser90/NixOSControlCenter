package tui

import "github.com/charmbracelet/bubbles/key"

type keyMap struct {
	toggle  key.Binding
	enable  key.Binding
	disable key.Binding
	refresh key.Binding
	quit    key.Binding
}

func newKeyMap() *keyMap {
	return &keyMap{
		toggle: key.NewBinding(
			key.WithKeys("t"),
			key.WithHelp("t", "toggle details"),
		),
		enable: key.NewBinding(
			key.WithKeys("e"),
			key.WithHelp("e", "enable module"),
		),
		disable: key.NewBinding(
			key.WithKeys("d"),
			key.WithHelp("d", "disable module"),
		),
		refresh: key.NewBinding(
			key.WithKeys("r"),
			key.WithHelp("r", "refresh modules"),
		),
		quit: key.NewBinding(
			key.WithKeys("q", "ctrl+c"),
			key.WithHelp("q", "quit"),
		),
	}
}
