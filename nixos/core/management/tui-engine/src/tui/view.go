package tui

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/lipgloss"
)

// =============================================================================
// HEADER & FOOTER SYSTEM
// =============================================================================

func init() {
	// Setup debug logging to file
	logFile, err := os.OpenFile("/tmp/tui-debug.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err == nil {
		log.SetOutput(logFile)
		log.Printf("🐛 DEBUG: Log file initialized\n")
	}
}

func (m Model) renderHeader() string {
	log.Printf("🐛 DEBUG renderHeader(): width=%d\n", m.width)

	header := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("39")).
		Align(lipgloss.Center).
		Width(m.width).
		Height(1)

	result := header.Render("📦 Module Manager")
	log.Printf("🐛 DEBUG renderHeader(): result length: %d\n", len(result))
	return result
}

func (m Model) renderFooter() string {
	footer := lipgloss.NewStyle().
		Foreground(lipgloss.Color("241")).
		Width(m.width).
		Align(lipgloss.Left)

	shortcuts := "↑/↓ Navigate • / Search • e Enable • d Disable • r Refresh • t Details • q Quit"
	return footer.Render(shortcuts)
}

// =============================================================================
// PANEL COMPONENT LIBRARY
// =============================================================================

type PanelStyle string

const (
	PanelStyleBordered PanelStyle = "bordered"
	PanelStyleMinimal  PanelStyle = "minimal"
	PanelStyleCard     PanelStyle = "card"
	PanelStyleNaked    PanelStyle = "naked"
)

type PanelConfig struct {
	Title     string
	Content   string
	Width     int
	Height    int
	MinWidth  int
	MinHeight int
	Style     PanelStyle
	Weight    float64 // For proportional sizing
}

func (m Model) renderPanel(config PanelConfig) string {
	var style lipgloss.Style

	switch config.Style {
	case PanelStyleBordered:
		style = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("39")).
			Padding(1, 2).
			Width(config.Width).
			Height(config.Height)
	case PanelStyleMinimal:
		style = lipgloss.NewStyle().
			Padding(1, 2).
			Width(config.Width).
			Height(config.Height)
	case PanelStyleCard:
		style = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("39")).
			Padding(1, 2).
			Width(config.Width).
			Height(config.Height)
	case PanelStyleNaked:
		style = lipgloss.NewStyle().
			Width(config.Width).
			Height(config.Height)
	}

	content := config.Title + "\n\n" + config.Content
	return style.Render(content)
}

func (m Model) renderViewportPanel(title string, vp viewport.Model, width, height int) string {
	log.Printf("🐛 DEBUG renderViewportPanel(): %s width=%d height=%d\n", title, width, height)

	// Update viewport dimensions
	vp.Width = width
	vp.Height = height

	// Create border style
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 1).
		Width(width)

	// Combine title and viewport content
	viewportContent := vp.View()
	log.Printf("🐛 DEBUG renderViewportPanel(): %s viewport content: %d chars\n", title, len(viewportContent))

	content := title + "\n\n" + viewportContent
	result := style.Render(content)

	log.Printf("🐛 DEBUG renderViewportPanel(): %s final result: %d chars\n", title, len(result))
	return result
}

// =============================================================================
// LAYOUT MANAGER
// =============================================================================

type LayoutManager struct {
	width  int
	height int
}

func NewLayoutManager(width, height int) *LayoutManager {
	return &LayoutManager{width: width, height: height}
}

func (lm *LayoutManager) GetAvailableDimensions() (int, int) {
    // KORREKT: Alle Borders + Margins + Padding berücksichtigen
    
    bodyWidth := lm.width - 4  // Links/Rechts Border + Padding

    fixedOverhead := 34  // Funktioniert für 62 Zeilen
    
    // RESPONSIVE: Overhead skaliert mit Terminal-Größe
    scalingFactor := 0.5  // 50% Overhead für große Terminals
    minOverhead := 25     // Minimum für kleine Terminals
    
    totalOverhead := max(minOverhead, int(float64(lm.height) * scalingFactor))
    totalOverhead = max(totalOverhead, fixedOverhead)  // Nicht unter funktionierenden Wert
    
    bodyHeight := lm.height - totalOverhead
    
    if bodyHeight < 15 {
        bodyHeight = 15  // Nie unter 15 Zeilen
    }
    if bodyHeight > lm.height - 10 {
        bodyHeight = lm.height - 10  // Nie zu nah an Maximum
    }
    
    return bodyWidth, bodyHeight
}

func (lm *LayoutManager) DistributeWidths(totalWidth int, configs []PanelConfig) []int {
	widths := make([]int, len(configs))

	// First pass: assign minimum widths
	remainingWidth := totalWidth
	for i, config := range configs {
		minWidth := config.MinWidth
		if minWidth == 0 {
			minWidth = 10 // Default minimum
		}
		widths[i] = minWidth
		remainingWidth -= minWidth
	}

	// Second pass: distribute remaining space proportionally
	if remainingWidth > 0 {
		totalWeight := 0.0
		for _, config := range configs {
			totalWeight += config.Weight
		}

		if totalWeight > 0 {
			for i, config := range configs {
				extraWidth := int(float64(remainingWidth) * (config.Weight / totalWeight))
				widths[i] += extraWidth
			}
		}
	}

	return widths
}

// =============================================================================
// TEMPLATE SYSTEM ARCHITECTURE
// =============================================================================

type Template interface {
	Render(m Model) string
	GetMinWidth() int
	GetMinHeight() int
	GetPanels() []PanelConfig
}

type TemplateRegistry struct {
	templates map[string]Template
}

func NewTemplateRegistry() *TemplateRegistry {
	return &TemplateRegistry{
		templates: make(map[string]Template),
	}
}

func (tr *TemplateRegistry) Register(name string, template Template) {
	tr.templates[name] = template
}

func (tr *TemplateRegistry) Get(name string) Template {
	return tr.templates[name]
}

func (tr *TemplateRegistry) SelectTemplate(width, height int, preference string) Template {
	// Check if preferred template exists and fits
	if preference != "" {
		if template := tr.Get(preference); template != nil {
			if width >= template.GetMinWidth() && height >= template.GetMinHeight() {
				return template
			}
		}
	}

	// Fallback to responsive selection
	switch {
	case width < 40 || height < 5:
		return tr.Get("emergency")
	case width < 60:
		return tr.Get("ultra-compact")
	case width < 100:
		return tr.Get("compact")
	case width < 140:
		return tr.Get("medium")
	default:
		return tr.Get("full")
	}
}

// Content Provider Interface
type ContentProvider interface {
	GetContent(panelName string) string
}

type DefaultContentProvider struct {
	model *Model
}

func NewDefaultContentProvider(model *Model) *DefaultContentProvider {
	return &DefaultContentProvider{model: model}
}

func (cp *DefaultContentProvider) GetContent(panelName string) string {
	switch panelName {
	case "menu":
		return cp.model.list.View()
	case "content":
		return cp.model.renderContentPanelContent()
	case "filter":
		return cp.model.getNixContent(cp.model.getFilterCmd)
	case "info":
		return "⚡ ACTIONS:\n[e] Enable\n[d] Disable\n[r] Refresh\n[t] Details\n[q] Quit"
	case "stats":
		total := len(cp.model.modules)
		enabled := 0
		disabled := 0
		for _, mod := range cp.model.modules {
			if mod.Status == "enabled" {
				enabled++
			} else {
				disabled++
			}
		}
		return fmt.Sprintf("Total: %d\n✓ Enabled: %d\n✗ Disabled: %d", total, enabled, disabled)
	default:
		return "Content not available"
	}
}

// =============================================================================
// TEMPLATE IMPLEMENTATIONS
// =============================================================================

// Full Layout Template (≥140 chars) - 5 Panels horizontal
type FullLayoutTemplate struct {
	contentProvider ContentProvider
}

func NewFullLayoutTemplate(contentProvider ContentProvider) *FullLayoutTemplate {
	return &FullLayoutTemplate{contentProvider: contentProvider}
}

func (t *FullLayoutTemplate) GetMinWidth() int  { return 140 }
func (t *FullLayoutTemplate) GetMinHeight() int { return 15 }

func (t *FullLayoutTemplate) GetPanels() []PanelConfig {
	return []PanelConfig{
		{Title: "📋 MENU", MinWidth: 20, Weight: 0.2, Style: PanelStyleBordered},
		{Title: "📦 CONTENT", MinWidth: 25, Weight: 0.4, Style: PanelStyleBordered},
		{Title: "🔍 FILTER", MinWidth: 15, Weight: 0.13, Style: PanelStyleBordered},
		{Title: "ℹ️ INFO", MinWidth: 15, Weight: 0.13, Style: PanelStyleBordered},
		{Title: "📊 STATS", MinWidth: 15, Weight: 0.13, Style: PanelStyleBordered},
	}
}

func (t *FullLayoutTemplate) Render(m Model) string {
	header := m.renderHeader()
	footer := m.renderFooter()

	// Get dimensions
	lm := NewLayoutManager(m.width, m.height)
	bodyWidth, bodyHeight := lm.GetAvailableDimensions()

	// Get panel configs and distribute widths
	panels := t.GetPanels()
	widths := lm.DistributeWidths(bodyWidth, panels)

	// Create scrollable panels using viewports
	menu := m.renderViewportPanel("📋 MENU", m.menuViewport, widths[0], bodyHeight)
	content := m.renderViewportPanel("📦 CONTENT", m.contentViewport, widths[1], bodyHeight)
	filter := m.renderViewportPanel("🔍 FILTER", m.filterViewport, widths[2], bodyHeight)
	info := m.renderViewportPanel("ℹ️ INFO", m.infoViewport, widths[3], bodyHeight)
	stats := m.renderViewportPanel("📊 STATS", m.statsViewport, widths[4], bodyHeight)

	// Join horizontally
	body := lipgloss.JoinHorizontal(lipgloss.Top, menu, content, filter, info, stats)

	// Join with header and footer
	return lipgloss.JoinVertical(lipgloss.Left, header, body, footer)
}

// Medium Layout Template (100-139 chars) - 3 Panels horizontal
type MediumLayoutTemplate struct {
	contentProvider ContentProvider
}

func NewMediumLayoutTemplate(contentProvider ContentProvider) *MediumLayoutTemplate {
	return &MediumLayoutTemplate{contentProvider: contentProvider}
}

func (t *MediumLayoutTemplate) GetMinWidth() int  { return 100 }
func (t *MediumLayoutTemplate) GetMinHeight() int { return 12 }

func (t *MediumLayoutTemplate) GetPanels() []PanelConfig {
	return []PanelConfig{
		{Title: "📋 MENU", MinWidth: 20, Weight: 0.25, Style: PanelStyleBordered},
		{Title: "📦 CONTENT", MinWidth: 25, Weight: 0.5, Style: PanelStyleBordered},
		{Title: "ℹ️ INFO", MinWidth: 15, Weight: 0.25, Style: PanelStyleBordered},
	}
}

func (t *MediumLayoutTemplate) Render(m Model) string {
    log.Printf("🐛 DEBUG MediumTemplate.Render(): Start\n")

    header := m.renderHeader()
    log.Printf("🐛 DEBUG MediumTemplate.Render(): Header length: %d\n", len(header))

    footer := m.renderFooter()
    log.Printf("🐛 DEBUG MediumTemplate.Render(): Footer length: %d\n", len(footer))

    // ✅ DIMENSION-BERECHNUNG WIEDER HINZUFÜGEN!
    lm := NewLayoutManager(m.width, m.height)
    bodyWidth, bodyHeight := lm.GetAvailableDimensions()
    log.Printf("🐛 DEBUG MediumTemplate.Render(): bodyWidth=%d bodyHeight=%d\n", bodyWidth, bodyHeight)

    widths := lm.DistributeWidths(bodyWidth, t.GetPanels())
    log.Printf("🐛 DEBUG MediumTemplate.Render(): widths=%v\n", widths)

    // Dann renderViewportPanel verwenden statt View() direkt
    log.Printf("🐛 DEBUG MediumTemplate.Render(): Erstelle Panels...\n")
    menu := m.renderViewportPanel("📋 MENU", m.menuViewport, widths[0], bodyHeight)
    content := m.renderViewportPanel("📦 CONTENT", m.contentViewport, widths[1], bodyHeight)
    info := m.renderViewportPanel("ℹ️ INFO", m.infoViewport, widths[2], bodyHeight)
    log.Printf("🐛 DEBUG MediumTemplate.Render(): Panels erstellt\n")

    log.Printf("🐛 DEBUG MediumTemplate.Render(): Join Horizontal...\n")
    body := lipgloss.JoinHorizontal(lipgloss.Top, menu, content, info)

    log.Printf("🐛 DEBUG MediumTemplate.Render(): Join Vertical...\n")
    result := lipgloss.JoinVertical(lipgloss.Left, header, body, footer)

    log.Printf("🐛 DEBUG MediumTemplate.Render(): Final result: %d chars\n", len(result))
    return result
}

// Compact Layout Template (60-99 chars) - Vertical stack
type CompactLayoutTemplate struct {
	contentProvider ContentProvider
}

func NewCompactLayoutTemplate(contentProvider ContentProvider) *CompactLayoutTemplate {
	return &CompactLayoutTemplate{contentProvider: contentProvider}
}

func (t *CompactLayoutTemplate) GetMinWidth() int  { return 60 }
func (t *CompactLayoutTemplate) GetMinHeight() int { return 15 }

func (t *CompactLayoutTemplate) GetPanels() []PanelConfig {
	return []PanelConfig{
		{Title: "📋 MENU", MinWidth: 25, Weight: 0.5, Style: PanelStyleBordered},
		{Title: "📦 CONTENT", MinWidth: 25, Weight: 0.5, Style: PanelStyleBordered},
		{Title: "📊 STATS", MinWidth: 15, Weight: 1.0, Style: PanelStyleBordered},
	}
}

func (t *CompactLayoutTemplate) Render(m Model) string {
	header := m.renderHeader()
	footer := m.renderFooter()

	lm := NewLayoutManager(m.width, m.height)
	bodyWidth, bodyHeight := lm.GetAvailableDimensions()

	// Top row: Menu + Content
	menu := m.renderPanel(PanelConfig{
		Title:   "📋 MENU",
		Content: t.contentProvider.GetContent("menu"),
		Width:   bodyWidth / 2,
		Height:  bodyHeight * 2 / 3,
		Style:   PanelStyleBordered,
	})

	content := m.renderPanel(PanelConfig{
		Title:   "📦 CONTENT",
		Content: t.contentProvider.GetContent("content"),
		Width:   bodyWidth / 2,
		Height:  bodyHeight * 2 / 3,
		Style:   PanelStyleBordered,
	})

	// Bottom row: Stats (full width)
	stats := m.renderPanel(PanelConfig{
		Title:   "📊 STATS",
		Content: t.contentProvider.GetContent("stats"),
		Width:   bodyWidth,
		Height:  bodyHeight / 3,
		Style:   PanelStyleBordered,
	})

	topRow := lipgloss.JoinHorizontal(lipgloss.Top, menu, content)
	body := lipgloss.JoinVertical(lipgloss.Left, topRow, stats)

	return lipgloss.JoinVertical(lipgloss.Left, header, body, footer)
}

// Ultra-Compact Template (<60 chars) - Single column
type UltraCompactLayoutTemplate struct {
	contentProvider ContentProvider
}

func NewUltraCompactLayoutTemplate(contentProvider ContentProvider) *UltraCompactLayoutTemplate {
	return &UltraCompactLayoutTemplate{contentProvider: contentProvider}
}

func (t *UltraCompactLayoutTemplate) GetMinWidth() int  { return 40 }
func (t *UltraCompactLayoutTemplate) GetMinHeight() int { return 12 }

func (t *UltraCompactLayoutTemplate) GetPanels() []PanelConfig {
	return []PanelConfig{
		{Title: "📋 MENU", MinWidth: 20, Weight: 1.0, Style: PanelStyleBordered},
		{Title: "📦 CONTENT", MinWidth: 20, Weight: 1.0, Style: PanelStyleBordered},
		{Title: "📊 STATS", MinWidth: 15, Weight: 1.0, Style: PanelStyleBordered},
	}
}

func (t *UltraCompactLayoutTemplate) Render(m Model) string {
	header := m.renderHeader()
	footer := m.renderFooter()

	lm := NewLayoutManager(m.width, m.height)
	bodyWidth, bodyHeight := lm.GetAvailableDimensions()

	menu := m.renderPanel(PanelConfig{
		Title:   "📋 MENU",
		Content: t.contentProvider.GetContent("menu"),
		Width:   bodyWidth,
		Height:  bodyHeight / 3,
		Style:   PanelStyleBordered,
	})

	content := m.renderPanel(PanelConfig{
		Title:   "📦 CONTENT",
		Content: t.contentProvider.GetContent("content"),
		Width:   bodyWidth,
		Height:  bodyHeight / 3,
		Style:   PanelStyleBordered,
	})

	stats := m.renderPanel(PanelConfig{
		Title:   "📊 STATS",
		Content: t.contentProvider.GetContent("stats"),
		Width:   bodyWidth,
		Height:  bodyHeight / 3,
		Style:   PanelStyleBordered,
	})

	body := lipgloss.JoinVertical(lipgloss.Left, menu, content, stats)
	return lipgloss.JoinVertical(lipgloss.Left, header, body, footer)
}

// Emergency Template for very small terminals
type EmergencyLayoutTemplate struct {
	contentProvider ContentProvider
}

func NewEmergencyLayoutTemplate(contentProvider ContentProvider) *EmergencyLayoutTemplate {
	return &EmergencyLayoutTemplate{contentProvider: contentProvider}
}

func (t *EmergencyLayoutTemplate) GetMinWidth() int  { return 20 }
func (t *EmergencyLayoutTemplate) GetMinHeight() int { return 5 }

func (t *EmergencyLayoutTemplate) GetPanels() []PanelConfig {
	return []PanelConfig{
		{Title: "📦 MODULES", MinWidth: 20, Weight: 1.0, Style: PanelStyleMinimal},
	}
}

func (t *EmergencyLayoutTemplate) Render(m Model) string {
	header := m.renderHeader()

	content := m.renderPanel(PanelConfig{
		Title:   "📦 MODULES",
		Content: t.contentProvider.GetContent("menu"),
		Width:   m.width,
		Height:  m.height - 1, // Header only
		Style:   PanelStyleMinimal,
	})

	return lipgloss.JoinVertical(lipgloss.Left, header, content)
}

func (m Model) View() string {
	// 🐛 DEBUG: Was passiert in View()?
	log.Printf("🐛 DEBUG View(): width=%d height=%d\n", m.width, m.height)

	// ✅ Klare Fehlermeldung bei zu kleiner Terminal
	if m.width < 80 || m.height < 20 {
		log.Printf("🐛 DEBUG View(): Terminal zu klein!\n")
		return fmt.Sprintf("❌ TERMINAL ZU KLEIN!\n\n"+
			"Aktuelle Größe: %dx%d\n"+
			"Benötigt: mindestens 80x20\n\n"+
			"Bitte Terminal vergrößern und neu starten!",
			m.width, m.height)
	}

	if len(m.list.Items()) == 0 {
		log.Printf("🐛 DEBUG View(): Keine Items, zeige Spinner\n")
		return m.spinner.View()
	}

	// Update panels before rendering
	log.Printf("🐛 DEBUG View(): Rufe updatePanels() auf\n")
	m.updatePanels()

	// Choose layout based on terminal size
	log.Printf("🐛 DEBUG View(): Rufe renderResponsiveLayout() auf\n")
	result := m.renderResponsiveLayout()
	log.Printf("🐛 DEBUG View(): renderResponsiveLayout returned: %d chars\n", len(result))

	return result
}

func (m *Model) updatePanels() {
	// Update all viewport content
	m.menuViewport.SetContent(m.renderModuleListContent())
	m.contentViewport.SetContent(m.renderContentPanelContent())
	m.filterViewport.SetContent(m.renderFilterContent())
	m.infoViewport.SetContent(m.renderInfoContent())
	m.statsViewport.SetContent(m.renderStatsContent())
}

// OLD PANEL FUNCTIONS REMOVED - REPLACED BY TEMPLATE SYSTEM

func (m Model) renderModuleListContent() string {
	return m.list.View()
}

func (m Model) renderFilterContent() string {
	content := "🔍 FILTER OPTIONS\n\n"
	content += fmt.Sprintf("Status: %s\n", m.filterStatus)
	content += fmt.Sprintf("Search: %s\n", m.searchTerm)
	content += "\nAvailable Filters:\n"
	content += "• all - Show all modules\n"
	content += "• enabled - Only enabled\n"
	content += "• disabled - Only disabled\n"
	content += "• broken - Only broken\n"
	return content
}

func (m Model) renderInfoContent() string {
	if m.selectedModule.Name == "" {
		return "ℹ️ INFO\n\nSelect a module to see details..."
	}

	content := fmt.Sprintf("ℹ️ MODULE INFO\n\n")
	content += fmt.Sprintf("Name: %s\n", m.selectedModule.Name)
	content += fmt.Sprintf("Description: %s\n", m.selectedModule.DescriptionText)
	content += fmt.Sprintf("Status: %s\n", m.selectedModule.Status)
	content += fmt.Sprintf("Category: %s\n", m.selectedModule.Category)
	content += fmt.Sprintf("Path: %s\n", m.selectedModule.Path)
	return content
}

func (m Model) renderStatsContent() string {
	total := len(m.modules)
	enabled := 0
	disabled := 0
	broken := 0

	for _, mod := range m.modules {
		switch mod.Status {
		case "enabled":
			enabled++
		case "disabled":
			disabled++
		case "broken":
			broken++
		}
	}

	content := "📊 STATISTICS\n\n"
	content += fmt.Sprintf("Total: %d\n", total)
	content += fmt.Sprintf("Enabled: %d\n", enabled)
	content += fmt.Sprintf("Disabled: %d\n", disabled)
	content += fmt.Sprintf("Broken: %d\n", broken)
	content += fmt.Sprintf("\nTerminal: %dx%d\n", m.width, m.height)
	return content
}

func (m Model) renderContentPanelContent() string {
	if m.showDetails && m.selectedModule.Name != "" {
		return m.renderModuleDetails()
	} else {
		return m.renderModulePreview()
	}
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

// Responsive layout system
// Global template registry - initialized once
var templateRegistry *TemplateRegistry

func init() {
	templateRegistry = NewTemplateRegistry()
}

func (m Model) renderResponsiveLayout() string {
	log.Printf("🐛 DEBUG renderResponsiveLayout(): Start\n")

	// Create content provider with current model
	cp := NewDefaultContentProvider(&m)

	// Create fresh templates with current content provider
	templateRegistry.Register("emergency", NewEmergencyLayoutTemplate(cp))
	templateRegistry.Register("ultra-compact", NewUltraCompactLayoutTemplate(cp))
	templateRegistry.Register("compact", NewCompactLayoutTemplate(cp))
	templateRegistry.Register("medium", NewMediumLayoutTemplate(cp))
	templateRegistry.Register("full", NewFullLayoutTemplate(cp))

	// Select appropriate template
	template := templateRegistry.SelectTemplate(m.width, m.height, "")
	log.Printf("🐛 DEBUG renderResponsiveLayout(): Template selected: %T\n", template)

	if template == nil {
		log.Printf("🐛 DEBUG renderResponsiveLayout(): Kein Template gefunden, verwende Emergency!\n")
		// Fallback to emergency template
		template = templateRegistry.Get("emergency")
	}

	// Render inner layout
	log.Printf("🐛 DEBUG renderResponsiveLayout(): Rufe template.Render() auf\n")
	innerLayout := template.Render(m)
	log.Printf("🐛 DEBUG renderResponsiveLayout(): template.Render returned: %d chars\n", len(innerLayout))

	// ✅ Border mit Padding zurück!
	border := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 2)  // Padding zurück - du willst es so!

	borderedLayout := border.Render(innerLayout)

	// Add top margin (2 lines space above border)
	topMargin := strings.Repeat("\n", 2)

	return topMargin + borderedLayout
}

// OLD LAYOUT FUNCTIONS REMOVED - REPLACED BY TEMPLATE SYSTEM

// OLD PANEL FUNCTIONS REMOVED - REPLACED BY TEMPLATE SYSTEM

// Utility function for max
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
