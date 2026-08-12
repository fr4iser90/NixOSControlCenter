package tui

import (
	"fmt"
	"log"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/lipgloss"
)

// =============================================================================
// HEADER & FOOTER SYSTEM
// =============================================================================

func init() {
	debugEnv := os.Getenv("NCC_TUI_DEBUG")
	// Accept "1" or "true" as debug flags
	if debugEnv != "1" && debugEnv != "true" {
		log.SetOutput(io.Discard)
		return
	}
	
	// Try to create log file (O_TRUNC to clear old logs, O_CREATE to create if missing)
	logFile, err := os.OpenFile("/tmp/tui-debug.log", os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0666)
	if err != nil {
		// Fallback to stderr if file can't be created
		log.SetOutput(os.Stderr)
		log.Printf("⚠️ WARNING: Could not open /tmp/tui-debug.log: %v\n", err)
		log.Printf("⚠️ WARNING: Logging to stderr instead\n")
		return
	}
	
	log.SetOutput(logFile)
	log.Printf("🐛 DEBUG: Log file initialized at /tmp/tui-debug.log\n")
	log.Printf("🐛 DEBUG: NCC_TUI_DEBUG=%s\n", debugEnv)
}

func (m Model) renderHeader(dims *LayoutDimensions) string {
	log.Printf("🐛 DEBUG renderHeader(): dims.InnerWidth=%d\n", dims.InnerWidth)

	// Allow dynamic title via env
	if title := os.Getenv("NCC_TUI_TITLE"); title != "" {
		content := lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("39")).
			Align(lipgloss.Center).
			Render(title)
		return ensureSize(content, dims.InnerWidth, dims.HeaderHeight)
	}

	// ✅ Header verwendet EXAKTE Dimensionen aus LayoutDimensions
	content := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("39")).
		Align(lipgloss.Center).
		Render("📦 Module Manager")
	
	// ✅ Garantiere exakte Größe mit ensureSize
	result := ensureSize(content, dims.InnerWidth, dims.HeaderHeight)
	
	log.Printf("🐛 DEBUG renderHeader(): result size: %dx%d\n", 
		lipgloss.Width(result), lipgloss.Height(result))
	return result
}

func (m Model) renderFooter(dims *LayoutDimensions) string {
	// ✅ Footer verwendet EXAKTE Dimensionen aus LayoutDimensions
	shortcuts := os.Getenv("NCC_TUI_FOOTER")
	if shortcuts == "" {
		shortcuts = "↑/↓ Navigate • / Search • e Enable • d Disable • r Refresh • t Details • q Quit"
	}
	
	content := lipgloss.NewStyle().
		Foreground(lipgloss.Color("241")).
		Align(lipgloss.Left).
		Render(shortcuts)
	
	// ✅ Garantiere exakte Größe mit ensureSize
	return ensureSize(content, dims.InnerWidth, dims.FooterHeight)
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

// Helper function to set viewport dimensions before rendering
// This ensures the viewport (passed by value) has correct dimensions
func (m *Model) setViewportDimensions(vp *viewport.Model, width, height int) {
	borderOverhead := 4
	paddingOverhead := 4
	totalVerticalOverhead := borderOverhead + paddingOverhead
	contentHeight := height - totalVerticalOverhead
	if contentHeight < 1 {
		contentHeight = 1
	}
	vp.Width = width
	vp.Height = contentHeight
}

func (m Model) renderViewportPanel(title string, vp viewport.Model, width, height int) string {
	// ✅ CRITICAL FIX: Ziehe Border + Padding Overhead ab!
	// Border: NormalBorder = 2 top + 2 bottom = 4
	// Padding: (1,1) = 2 top + 2 bottom = 4
	// Total vertical overhead = 8 lines
	borderOverhead := 4  // 2 top + 2 bottom for NormalBorder
	paddingOverhead := 4 // 2 top + 2 bottom for Padding(1,1)
	totalVerticalOverhead := borderOverhead + paddingOverhead
	
	// Calculate actual content height
	contentHeight := height - totalVerticalOverhead
	if contentHeight < 1 {
		contentHeight = 1 // Safety minimum
	}

	// ✅ FIX: Viewport dimensions are set BEFORE calling renderViewportPanel
	// Don't modify vp here - it's a copy! Dimensions are set in the original model
	// vp.Width and vp.Height are already set in the template Render() method

	// Create border style ohne Width-Constraint
	style := lipgloss.NewStyle().
		Border(lipgloss.NormalBorder()).
		BorderForeground(lipgloss.Color("39")).
		Padding(1, 1)
		// REMOVED: .Width(width) - lässt Panel natürliche Breite verwenden
	
	// Combine title and viewport content
	viewportContent := vp.View()
	
	content := title + "\n\n" + viewportContent
	result := style.Render(content)

	return result
}

// =============================================================================
// LAYOUT DIMENSIONS - SINGLE SOURCE OF TRUTH
// =============================================================================

type LayoutDimensions struct {
	// Terminal size (absolute reference)
	TerminalWidth  int
	TerminalHeight int
	
	// Inner dimensions (after border)
	InnerWidth  int
	InnerHeight int
	
	// Component dimensions (fixed)
	HeaderHeight int
	FooterHeight int
	
	// Body dimensions (calculated)
	BodyWidth  int
	BodyHeight int
}

func NewLayoutDimensions(termWidth, termHeight int, borderStyle lipgloss.Style) *LayoutDimensions {
	// Get border insets (border-agnostic!)
	borderX, borderY := GetBorderInset(borderStyle)
	
	// Calculate inner dimensions
	innerWidth := termWidth - borderX
	innerHeight := termHeight - borderY
	
	// Fixed component heights
	headerHeight := 1
	footerHeight := 1
	
	// Body gets remaining space
	bodyWidth := innerWidth
	bodyHeight := innerHeight - headerHeight - footerHeight
	
	return &LayoutDimensions{
		TerminalWidth:  termWidth,
		TerminalHeight: termHeight,
		InnerWidth:     innerWidth,
		InnerHeight:    innerHeight,
		HeaderHeight:   headerHeight,
		FooterHeight:   footerHeight,
		BodyWidth:      bodyWidth,
		BodyHeight:     bodyHeight,
	}
}

// GetBorderInset returns horizontal and vertical border size
func GetBorderInset(style lipgloss.Style) (x, y int) {
	// ✅ Lipgloss Border: GetHorizontalBorderSize() und GetVerticalBorderSize() verwenden!
	horizontalBorder := style.GetHorizontalBorderSize()
	verticalBorder := style.GetVerticalBorderSize()
	
	return horizontalBorder, verticalBorder
}

// ensureSize guarantees exact dimensions with clipping and padding
func ensureSize(content string, width, height int) string {
	style := lipgloss.NewStyle().
		Width(width).      // Padding if too small
		Height(height).    // Padding if too small
		MaxWidth(width).   // Clipping if too large
		MaxHeight(height)  // Clipping if too large
	
	return style.Render(content)
}

// =============================================================================
// LAYOUT MANAGER (Legacy - kept for compatibility)
// =============================================================================

type LayoutManager struct {
	width  int
	height int
}

func NewLayoutManager(width, height int) *LayoutManager {
	return &LayoutManager{width: width, height: height}
}

func (lm *LayoutManager) GetAvailableDimensions() (int, int) {
    // ✅ NUR ECHTE OVERHEADS BERÜCKSICHTIGEN
    
    // Outer border: 2 links + 2 rechts für die RoundedBorder in renderResponsiveLayout
    outerBorderWidth := 4
    
    // Header (1 Zeile) + Footer (1 Zeile) + Outer border oben (1) + unten (1)
    outerBorderHeight := 4
    
    // Panel-Overhead: Jeder Panel hat Border(2 links+rechts) + Padding(2 links+rechts) = 4 Zeichen
    // Bei 5 Panels horizontal = 5 * 4 = 20 Zeichen Overhead
    panelOverhead := 5 * 4
    
    // Verfügbare Breite für Template-Body
    bodyWidth := lm.width - outerBorderWidth - panelOverhead
    
    // Verfügbare Höhe für Template-Body
    // Header(1) + Footer(1) + Outer border(2) + Panel borders oben/unten(2) = 6
    bodyHeight := lm.height - outerBorderHeight - 2
    
    // Sicherheitschecks
    if bodyWidth < 60 {
        bodyWidth = 60  // Minimum Breite
    }
    if bodyHeight < 10 {
        bodyHeight = 10  // Minimum Höhe
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
	Render(m Model, dims *LayoutDimensions) string
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

// FZF-style Template (2 panels: list + preview/actions)
type FzfLayoutTemplate struct {
	contentProvider ContentProvider
}

func NewFzfLayoutTemplate(contentProvider ContentProvider) *FzfLayoutTemplate {
	return &FzfLayoutTemplate{contentProvider: contentProvider}
}

func (t *FzfLayoutTemplate) GetMinWidth() int  { return 60 }
func (t *FzfLayoutTemplate) GetMinHeight() int { return 8 }

func (t *FzfLayoutTemplate) GetPanels() []PanelConfig {
	return []PanelConfig{
		{Title: "", MinWidth: 25, Weight: 0.35, Style: PanelStyleBordered},
		{Title: "", MinWidth: 35, Weight: 0.65, Style: PanelStyleBordered},
	}
}

func (t *FzfLayoutTemplate) Render(m Model, dims *LayoutDimensions) string {
	header := m.renderHeader(dims)
	footer := m.renderFooter(dims)

	lm := NewLayoutManager(m.width, m.height)
	bodyWidth, bodyHeight := lm.GetAvailableDimensions()
	widths := lm.DistributeWidths(bodyWidth, t.GetPanels())

	// ✅ FIX: Set viewport dimensions BEFORE calling renderViewportPanel
	// This ensures the viewport (passed by value) has correct dimensions
	m.setViewportDimensions(&m.menuViewport, widths[0], bodyHeight)
	m.setViewportDimensions(&m.contentViewport, widths[1], bodyHeight)
	
	// ✅ CRITICAL FIX: ALWAYS set YOffset to 0 to prevent auto-scrolling
	// NEVER use lastMenuYOffset - always keep at 0 to prevent movement
	// IMPORTANT: Set YOffset RIGHT BEFORE calling renderViewportPanel
	// This ensures the viewport (passed by value) has the correct YOffset
	m.menuViewport.SetYOffset(0)
	m.menuViewport.SetYOffset(0) // Double-call to ensure it sticks
	m.menuViewport.SetYOffset(0) // Triple-call for extra safety

	menu := m.renderViewportPanel("", m.menuViewport, widths[0], bodyHeight)
	preview := m.renderViewportPanel("", m.contentViewport, widths[1], bodyHeight)
	body := lipgloss.JoinHorizontal(lipgloss.Top, menu, preview)

	return lipgloss.JoinVertical(lipgloss.Left, header, body, footer)
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
		{Title: "⚙️ ACTIONS", MinWidth: 15, Weight: 0.13, Style: PanelStyleBordered},
		{Title: "📊 STATS", MinWidth: 15, Weight: 0.13, Style: PanelStyleBordered},
	}
}

func (t *FullLayoutTemplate) Render(m Model, dims *LayoutDimensions) string {
	// ✅ Render header and footer with EXACT dimensions
	header := m.renderHeader(dims)
	footer := m.renderFooter(dims)

	// Get dimensions
	lm := NewLayoutManager(m.width, m.height)
	bodyWidth, bodyHeight := lm.GetAvailableDimensions()

	// Get panel configs and distribute widths
	panels := t.GetPanels()
	widths := lm.DistributeWidths(bodyWidth, panels)

	// ✅ FIX: Set viewport dimensions BEFORE calling renderViewportPanel
	m.setViewportDimensions(&m.menuViewport, widths[0], bodyHeight)
	m.setViewportDimensions(&m.contentViewport, widths[1], bodyHeight)
	m.setViewportDimensions(&m.filterViewport, widths[2], bodyHeight)
	m.setViewportDimensions(&m.infoViewport, widths[3], bodyHeight)
	m.setViewportDimensions(&m.statsViewport, widths[4], bodyHeight)
	
	// ✅ CRITICAL FIX: ALWAYS set YOffset to 0 to prevent auto-scrolling
	// NEVER use lastMenuYOffset - always keep at 0 to prevent movement
	// IMPORTANT: Set YOffset RIGHT BEFORE calling renderViewportPanel
	// This ensures the viewport (passed by value) has the correct YOffset
	m.menuViewport.SetYOffset(0)
	m.menuViewport.SetYOffset(0) // Double-call to ensure it sticks
	m.menuViewport.SetYOffset(0) // Triple-call for extra safety

	// Create scrollable panels using viewports
	menu := m.renderViewportPanel("📋 MENU", m.menuViewport, widths[0], bodyHeight)
	content := m.renderViewportPanel("📦 CONTENT", m.contentViewport, widths[1], bodyHeight)
	filter := m.renderViewportPanel("🔍 FILTER", m.filterViewport, widths[2], bodyHeight)
	info := m.renderViewportPanel("⚙️ ACTIONS", m.infoViewport, widths[3], bodyHeight)
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

func (t *MediumLayoutTemplate) Render(m Model, dims *LayoutDimensions) string {
    // ✅ Render header and footer with EXACT dimensions
    header := m.renderHeader(dims)
    footer := m.renderFooter(dims)

    // ✅ DIMENSION-BERECHNUNG WIEDER HINZUFÜGEN!
    lm := NewLayoutManager(m.width, m.height)
    bodyWidth, bodyHeight := lm.GetAvailableDimensions()
    widths := lm.DistributeWidths(bodyWidth, t.GetPanels())

    // ✅ FIX: Set viewport dimensions BEFORE calling renderViewportPanel
    m.setViewportDimensions(&m.menuViewport, widths[0], bodyHeight)
    m.setViewportDimensions(&m.contentViewport, widths[1], bodyHeight)
    m.setViewportDimensions(&m.infoViewport, widths[2], bodyHeight)
    
    // ✅ CRITICAL FIX: ALWAYS set YOffset to 0 to prevent auto-scrolling
    // NEVER use lastMenuYOffset - always keep at 0 to prevent movement
    // IMPORTANT: Set YOffset RIGHT BEFORE calling renderViewportPanel
    // This ensures the viewport (passed by value) has the correct YOffset
    m.menuViewport.SetYOffset(0)
    m.menuViewport.SetYOffset(0) // Double-call to ensure it sticks
    m.menuViewport.SetYOffset(0) // Triple-call for extra safety

    // Dann renderViewportPanel verwenden statt View() direkt
    menu := m.renderViewportPanel("📋 MENU", m.menuViewport, widths[0], bodyHeight)
    content := m.renderViewportPanel("📦 CONTENT", m.contentViewport, widths[1], bodyHeight)
    info := m.renderViewportPanel("ℹ️ INFO", m.infoViewport, widths[2], bodyHeight)

    body := lipgloss.JoinHorizontal(lipgloss.Top, menu, content, info)
    result := lipgloss.JoinVertical(lipgloss.Left, header, body, footer)

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

func (t *CompactLayoutTemplate) Render(m Model, dims *LayoutDimensions) string {
	// ✅ Render header and footer with EXACT dimensions
	header := m.renderHeader(dims)
	footer := m.renderFooter(dims)

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

func (t *UltraCompactLayoutTemplate) Render(m Model, dims *LayoutDimensions) string {
	// ✅ Render header and footer with EXACT dimensions
	header := m.renderHeader(dims)
	footer := m.renderFooter(dims)

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

func (t *EmergencyLayoutTemplate) Render(m Model, dims *LayoutDimensions) string {
	// ✅ Render header with EXACT dimensions
	header := m.renderHeader(dims)

	content := m.renderPanel(PanelConfig{
		Title:   "📦 MODULES",
		Content: t.contentProvider.GetContent("menu"),
		Width:   dims.BodyWidth,
		Height:  dims.BodyHeight,
		Style:   PanelStyleMinimal,
	})

	return lipgloss.JoinVertical(lipgloss.Left, header, content)
}

func (m *Model) View() string {
	if len(m.list.Items()) == 0 {
		return m.spinner.View()
	}

	// ✅ CRITICAL FIX: ALWAYS set YOffset to 0 to prevent auto-scrolling
	// NEVER use lastMenuYOffset - always keep at 0 to prevent movement
	// The menu should NEVER scroll automatically, even when content changes
	m.menuViewport.SetYOffset(0)
	m.menuViewport.SetYOffset(0) // Double-call to ensure it sticks

	// Choose layout based on terminal size
	return m.renderResponsiveLayout()
}

func (m *Model) updatePanels() {
	// ✅ CRITICAL FIX: Keep menu viewport completely static - no auto-scrolling
	// ALWAYS use 0 as YOffset - NEVER use lastMenuYOffset
	// This prevents the menu from scrolling when content changes
	
	// Render menu content (all items, no centering)
	menuContent := m.renderStaticModuleListContent()
	m.menuViewport.SetContent(menuContent)
	
	// ✅ CRITICAL FIX: SetContent() ALWAYS resets YOffset to 0, so we MUST restore it immediately
	// ALWAYS set to 0 - never use lastMenuYOffset to prevent movement
	// We need to call SetYOffset MULTIPLE times because SetContent() might reset it
	m.menuViewport.SetYOffset(0)
	m.menuViewport.SetYOffset(0) // Double-call to ensure it sticks
	m.menuViewport.SetYOffset(0) // Triple-call for extra safety
	
	// Don't update lastMenuYOffset here - only update it when user manually scrolls
	
	m.contentViewport.SetContent(m.renderContentPanelContent())
	m.filterViewport.SetContent(m.renderFilterContent())
	m.infoViewport.SetContent(m.renderInfoContent())
	m.statsViewport.SetContent(m.renderStatsContent())
}

// OLD PANEL FUNCTIONS REMOVED - REPLACED BY TEMPLATE SYSTEM

func (m Model) renderModuleListContent() string {
	// Default list rendering (keeps bubbletea list behavior)
	return m.list.View()
}

func (m Model) renderStaticModuleListContent() string {
	// ✅ FIX: Render ALL items to prevent content shifting when selection changes
	// The viewport will handle scrolling naturally, maintaining stable position
	if len(m.modules) == 0 {
		return "No entries"
	}
	
	// Find selected index for highlighting
	selectedIndex := -1
	if m.list.SelectedItem() != nil {
		if selected, ok := m.list.SelectedItem().(ModuleItem); ok {
			for i, mod := range m.modules {
				if mod.Name == selected.Name {
					selectedIndex = i
					break
				}
			}
		}
	}
	
	// Render all items - viewport handles scrolling
	lines := make([]string, len(m.modules))
	for i, mod := range m.modules {
		prefix := "  "
		if i == selectedIndex {
			prefix = "> "
		}
		lines[i] = fmt.Sprintf("%s%s", prefix, mod.Name)
	}
	return strings.Join(lines, "\n")
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
	// ✅ Renamed to ACTIONS - show what user can DO
	content := "⚙️ ACTIONS\n\n"

	if m.uiState == StateActionDialog {
		content += "Select action:\n\n"
		for i, action := range m.selectedModule.Actions {
			marker := "  "
			if i == m.actionIndex {
				marker = "> "
			}
			label := action.Label
			if label == "" {
				label = action.Name
			}
			content += fmt.Sprintf("%s%s\n", marker, label)
		}
		content += "\nEnter: confirm • Esc: cancel"
		return content
	}

	if m.uiState == StatePrompt {
		content += "Fill inputs:\n\n"
		for i, input := range m.promptInputs {
			marker := "  "
			if i == m.promptIndex {
				marker = "> "
			}
			content += fmt.Sprintf("%s%s\n", marker, input.View())
		}
		content += "\nEnter: next/submit • Esc: cancel"
		return content
	}
	
	if m.selectedModule.Name == "" {
		content += "Select a module to see\navailable actions.\n\n"
		content += "Navigation:\n"
		content += "↑/↓  Navigate list\n"
		content += "/    Search modules\n"
		content += "q    Quit\n"
		return content
	}
	
	// Show available actions for selected module
	content += "Module Actions:\n\n"
	
	// Check if module is enabled/disabled
	if m.selectedModule.Status == "enabled" {
		content += "[d] Disable Module\n"
	} else if m.selectedModule.Status == "disabled" {
		content += "[e] Enable Module\n"
	}
	
	content += "[r] Reload Config\n"
	content += "[t] Show Details\n"
	content += "[c] View Config\n"
	content += "[l] View Logs\n"
	content += "\n"
	content += "Navigation:\n"
	content += "[q] Quit\n"
	content += "[?] Help\n"
	
	return content
}

func (m Model) renderStatsContent() string {
	if m.getStatsCmd != "" {
		return m.getNixContent(m.getStatsCmd)
	}
	// ✅ Calculate real statistics
	total := len(m.modules)
	enabled := 0
	disabled := 0
	broken := 0
	unknown := 0

	for _, mod := range m.modules {
		switch mod.Status {
		case "enabled":
			enabled++
		case "disabled":
			disabled++
		case "broken":
			broken++
		default:
			unknown++
		}
	}

	content := "📊 STATISTICS\n\n"
	content += fmt.Sprintf("Total: %d modules\n", total)
	content += "━━━━━━━━━━━━━━━━\n"
	
	// Show percentages
	if total > 0 {
		enabledPct := (enabled * 100) / total
		disabledPct := (disabled * 100) / total
		
		content += fmt.Sprintf("✓ Enabled: %d (%d%%)\n", enabled, enabledPct)
		content += fmt.Sprintf("✗ Disabled: %d (%d%%)\n", disabled, disabledPct)
		
		if broken > 0 {
			brokenPct := (broken * 100) / total
			content += fmt.Sprintf("? Broken: %d (%d%%)\n", broken, brokenPct)
		}
		
		if unknown > 0 {
			content += fmt.Sprintf("? Unknown: %d\n", unknown)
		}
	}
	
	content += "\nCategories:\n"
	content += "🔧 Core: (TBD)\n"
	content += "📦 Custom: (TBD)\n"
	
	return content
}

func (m Model) renderContentPanelContent() string {
	if m.uiState == StateActionDialog {
		return "Choose an action for the selected item."
	}
	if m.uiState == StatePrompt {
		return "Provide the required inputs to run this action."
	}
	if os.Getenv("NCC_TUI_LAYOUT") == "fzf" {
		return m.renderPreviewContent()
	}
	if m.showDetails && m.selectedModule.Name != "" {
		return m.renderModuleDetails()
	} else {
		return m.renderModulePreview()
	}
}

func (m Model) renderPreviewContent() string {
	log.Printf("🔍 DEBUG renderPreviewContent(): Called for server: %s\n", m.selectedModule.Name)
	if m.selectedModule.Name == "" {
		log.Printf("🔍 DEBUG renderPreviewContent(): No selected module, returning empty\n")
		return ""
	}

	// Check if currently loading
	if m.previewLoading == m.selectedModule.Name {
		log.Printf("🔍 DEBUG renderPreviewContent(): Currently loading, showing 'Loading...'\n")
		return "Loading..."
	}

	// Use cached content if available
	if content, ok := m.previewCache[m.selectedModule.Name]; ok {
		log.Printf("🔍 DEBUG renderPreviewContent(): Cache hit, returning cached content (length: %d)\n", len(content))
		return content
	}

	// No cache yet, return empty (will be loaded asynchronously)
	log.Printf("🔍 DEBUG renderPreviewContent(): Cache miss, returning empty (async load in progress)\n")
	return ""
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
	log.Printf("🔍 DEBUG getNixContent(): Starting - cmd: %s\n", nixCmd)
	if nixCmd == "" {
		return "Content not available"
	}

	log.Printf("🔍 DEBUG getNixContent(): Executing command - THIS BLOCKS!\n")
	startTime := time.Now()
	cmd := exec.Command("bash", "-c", nixCmd)
	output, err := cmd.Output()
	duration := time.Since(startTime)
	log.Printf("🔍 DEBUG getNixContent(): Command finished after %v - BLOCKED UI!\n", duration)
	if err != nil {
		log.Printf("🔍 DEBUG getNixContent(): Error: %v\n", err)
		return fmt.Sprintf("Error: %v", err)
	}

	log.Printf("🔍 DEBUG getNixContent(): Success, output length: %d\n", len(output))
	return strings.TrimSpace(string(output))
}

// Responsive layout system
// Global template registry - initialized once
var templateRegistry *TemplateRegistry

func init() {
	templateRegistry = NewTemplateRegistry()
}

func (m Model) renderResponsiveLayout() string {
	// Layout override via env
	preferredLayout := strings.TrimSpace(os.Getenv("NCC_TUI_LAYOUT"))

	// ✅ 1. Create border style
	borderStyle := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("39"))
	
	// ✅ 2. Calculate EXACT dimensions (border-agnostic!)
	dims := NewLayoutDimensions(m.width, m.height, borderStyle)

	// ✅ 3. Create content provider with current model
	cp := NewDefaultContentProvider(&m)

	// ✅ 4. Create fresh templates with current content provider
	templateRegistry.Register("emergency", NewEmergencyLayoutTemplate(cp))
	templateRegistry.Register("ultra-compact", NewUltraCompactLayoutTemplate(cp))
	templateRegistry.Register("compact", NewCompactLayoutTemplate(cp))
	templateRegistry.Register("medium", NewMediumLayoutTemplate(cp))
	templateRegistry.Register("full", NewFullLayoutTemplate(cp))
	templateRegistry.Register("fzf", NewFzfLayoutTemplate(cp))

	// ✅ 5. Select appropriate template
	var template Template
	if preferredLayout != "" {
		template = templateRegistry.Get(preferredLayout)
	} else {
		template = templateRegistry.SelectTemplate(m.width, m.height, preferredLayout)
	}

	if template == nil {
		template = templateRegistry.Get("emergency")
	}

	// ✅ 6. Render inner layout with EXACT dimensions (dims explizit übergeben!)
	innerLayout := template.Render(m, dims)

	// ✅ 8. Border wraps content (OHNE Width/Height - passt sich an!)
	borderedLayout := borderStyle.Render(innerLayout)

	return borderedLayout
}

// OLD LAYOUT FUNCTIONS REMOVED - REPLACED BY TEMPLATE SYSTEM

// OLD PANEL FUNCTIONS REMOVED - REPLACED BY TEMPLATE SYSTEM

// Utility function for max
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
