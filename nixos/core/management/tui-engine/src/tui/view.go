package tui

import (
	"fmt"
	// "log"
	"os/exec"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func (m Model) View() string {
	// log.Println("🐛 DEBUG: View() called, items: %d", len(m.list.Items()))

	if len(m.list.Items()) == 0 {
		// log.Println("🐛 DEBUG: Showing spinner")
		return m.spinner.View()
	}

	// Update panels before rendering
	// log.Println("🐛 DEBUG: Updating panels...")
	m.updatePanels()

	// Create 5-panel layout
	// log.Println("🐛 DEBUG: Rendering 5-panel layout")
	result := lipgloss.JoinHorizontal(
		lipgloss.Top,
		m.renderMenuPanel(),
		m.renderContentPanel(),
		m.renderFilterPanel(),
		m.renderInfoPanel(),
		m.renderStatsPanel(),
	)

	// log.Println("🐛 DEBUG: Rendered view with length: %d", len(result))
	return result
}

func (m *Model) updatePanels() {
	// Update menu panel (module list)
	m.menuPanel = m.renderModuleList()

	// Update content panel (module details or list preview)
	if m.showDetails && m.selectedModule.Name != "" {
		m.contentPanel = m.renderModuleDetails()
	} else {
		m.contentPanel = m.renderModulePreview()
	}

	// Update filter panel
	m.filterPanel = m.renderFilterPanel()

	// Update info panel
	m.infoPanel = m.renderInfoPanel()

	// Update stats panel
	m.statsPanel = m.renderStatsPanel()
}

func (m Model) renderMenuPanel() string {
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 2).
		Width(25).
		Height(20)

	return style.Render("📋 MENU\n\n" + m.list.View())
}

func (m Model) renderContentPanel() string {
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 2).
		Width(35).
		Height(20)

	return style.Render("📦 CONTENT\n\n" + m.contentPanel)
}

func (m Model) renderFilterPanel() string {
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 2).
		Width(20).
		Height(20)

	// Get filter content from Nix function
	filterContent := m.getNixContent(m.getFilterCmd)

	return style.Render("🔍 FILTER\n\n" + filterContent)
}

func (m Model) renderInfoPanel() string {
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 2).
		Width(20).
		Height(20)

	actions := "⚡ ACTIONS:\n[e] Enable\n[d] Disable\n[r] Refresh\n[t] Toggle Details\n[q] Quit"
	return style.Render("ℹ️ INFO\n\n" + actions)
}

func (m Model) renderStatsPanel() string {
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 2).
		Width(20).
		Height(20)

	total := len(m.modules)
	enabled := 0
	disabled := 0
	for _, mod := range m.modules {
		if mod.Status == "enabled" {
			enabled++
		} else {
			disabled++
		}
	}

	stats := fmt.Sprintf("📊 STATS:\nTotal: %d\n✓ Enabled: %d\n✗ Disabled: %d", total, enabled, disabled)
	return style.Render(stats)
}

func (m Model) renderModuleList() string {
	return m.list.View()
}

func (m Model) renderModulePreview() string {
	if len(m.modules) == 0 {
		return "No modules loaded"
	}

	preview := "Available Modules:\n\n"
	for i, mod := range m.modules {
		if i >= 5 { // Show only first 5
			break
		}
		status := "?"
		if mod.Status == "enabled" {
			status = "✓"
		} else if mod.Status == "disabled" {
			status = "✗"
		}
		preview += fmt.Sprintf("%s %s\n", status, mod.Name)
	}

	return preview
}

func (m Model) renderModuleDetails() string {
	if m.selectedModule.Name == "" {
		return "No module selected"
	}

	details := fmt.Sprintf("📦 Module Details:\n\nName: %s\nStatus: %s\nCategory: %s\n\nDescription:\n%s",
		m.selectedModule.Name,
		m.selectedModule.Status,
		m.selectedModule.Category,
		m.selectedModule.DescriptionText,
	)

	return details
}

// Helper function to execute Nix content functions
func (m Model) getNixContent(nixCmd string) string {
	if nixCmd == "" {
		return "Content not available"
	}

	cmd := exec.Command("bash", "-c", nixCmd)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Sprintf("Error: %v", err)
	}

	return strings.TrimSpace(string(output))
}
