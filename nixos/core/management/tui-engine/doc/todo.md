🎯 ZIEL: Vollständiges TUI Template System
Modulares, wiederverwendbares Template-System für verschiedene Layouts mit korrektem Height-Management, um Abschneiden zu verhindern.
📋 PHASE 1: Grundstruktur & Core Components
1.1 Header & Footer System
[ ] renderHeader() Funktion mit konfigurierbarem Titel
[ ] renderFooter() Funktion mit Shortcuts & Status
[ ] Height-Management: Header = 1 Zeile, Footer = 1 Zeile
1.2 Panel Component Library
[ ] Basis renderPanel() Funktion mit verschiedenen Styles:
bordered (volle Border)
minimal (nur Padding)
card (gerundete Border)
naked (keine Border)
[ ] PanelConfig struct für Width, Height, Style, Title, Content
1.3 Layout Manager
[ ] LayoutManager struct mit:
Terminal dimensions
Available space calculation
Panel positioning logic
[ ] Height calculation: availableHeight = terminalHeight - headerHeight - footerHeight
📋 PHASE 2: Template System Architecture
2.1 Template Interface
type Template interface {    Render(m Model) string    GetMinWidth() int    GetMinHeight() int    GetPanels() []PanelConfig}
2.2 Template Registry
[ ] TemplateRegistry map für verschiedene Templates
[ ] Template selection basierend auf:
Terminal width
User preference
Application type
[ ] Fallback-System für zu kleine Terminals
2.3 Dynamic Panel Filling
[ ] Panel content injection system
[ ] Content provider interface für verschiedene Datenquellen
[ ] Lazy loading für große Content-Bereiche
📋 PHASE 3: Spezifische Templates Implementieren
3.1 Full Layout Template (≥140 chars)
┌─ Header ──────────────────────────────────────┐├─────┬─────────────┬──────┬──────┬──────┤│Menu │ Content     │Filter│ Info │Stats │  ← 5 Panels horizontal└─────┴─────────────┴──────┴──────┴──────┘└─ Footer ──────────────────────────────────────┘
[ ] Panel widths: 20% | 40% | 13% | 13% | 13%
[ ] BorderTop(false) für alle Panels
[ ] Height: terminalHeight - 2
3.2 Medium Layout Template (100-139 chars)
┌─ Header ──────────────────┐├──────┬─────────┬─────┤│ Menu │Content  │Info │  ← 3 Panels horizontal└──────┴─────────┴─────┘└─ Footer ──────────────────┘
[ ] Panel widths: 25% | 50% | 25%
[ ] Stats Panel entfernt, Filter integriert
3.3 Compact Layout Template (60-99 chars)
┌─ Header ──────────┐├─────┬─────┤│Menu │Cont.│  ← 2 Panels horizontal  ├─────┴─────┤│  Stats    │  ← Footer-Panel└─ Footer ──────────┘
[ ] Vertical split: Menu + Content oben, Stats unten
[ ] Info/Filter als Tabs oder entfernt
3.4 Ultra-Compact Template (<60 chars)
┌─ Header ─┐├─────────┤│  Menu   │├─────────┤  │ Content │├─────────┤│  Stats  │└─ Footer─┘
[ ] Single column stack
[ ] Minimal Panels ohne Borders
📋 PHASE 4: Responsive System & Edge Cases
4.1 Responsive Breakpoints
[ ] Automatische Template-Auswahl:
< 40: Emergency minimal (nur Text)
< 60: Ultra compact
< 100: Compact
< 140: Medium
≥ 140: Full
[ ] Smooth transitions ohne Layout-Sprünge
4.2 Height Management (Anti-Abschneiden)
[ ] Dynamic height calculation für alle Panels
[ ] Scrollbars für overflow content
[ ] Minimum heights für Lesbarkeit
[ ] Header/Footer priority (werden nie abgeschnitten)
4.3 Width Management
[ ] Proportional panel sizing
[ ] Minimum widths für Panels
[ ] Text wrapping für schmale Panels
[ ] Graceful degradation bei zu schmalen Terminals
📋 PHASE 5: Advanced Features
5.1 Panel States & Interactions
[ ] Active/Inactive Panel states
[ ] Focus indicators
[ ] Panel resizing (optional)
[ ] Panel collapsing/expanding
5.2 Content Management
[ ] Viewport system für scrollbare Panels
[ ] Content pagination
[ ] Search highlighting
[ ] Content filtering pro Panel
5.3 Theme System
[ ] Color schemes (Dark/Light/Custom)
[ ] Border styles (Normal/Rounded/Double)
[ ] Font weights & sizes
[ ] Custom color palettes
📋 PHASE 6: Integration & Testing
6.1 Module Manager Integration
[ ] Template selection in commands.nix
[ ] Configuration options für verschiedene Views
[ ] Backward compatibility mit alten Layouts
6.2 Testing & QA
[ ] Unit tests für alle Templates
[ ] Integration tests für verschiedene Terminal-Größen
[ ] Visual regression tests
[ ] Performance tests für große Content-Bereiche
6.3 Documentation
[ ] Template usage guide
[ ] Customization examples
[ ] Best practices für neue Templates
[ ] API documentation
🎯 IMPLEMENTIERUNGSPLAN
Schritt 1: Core Components (1-2 Tage)
Header/Footer System implementieren
Panel Component Library erstellen
Layout Manager aufbauen
Schritt 2: Template System (2-3 Tage)
Template Interface definieren
Template Registry implementieren
Full Layout Template fertigstellen
Schritt 3: Responsive Templates (2-3 Tage)
Medium Layout implementieren
Compact Layout implementieren
Ultra-Compact Layout implementieren
Schritt 4: Polish & Testing (1-2 Tage)
Height/Width Management finalisieren
Edge cases behandeln
Tests schreiben
Schritt 5: Integration (1 Tag)
In Module Manager integrieren
Configuration options hinzufügen
Documentation schreiben