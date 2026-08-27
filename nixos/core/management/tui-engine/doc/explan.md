## Wie die Module Manager TUI Templates funktionieren

Das System baut sich erfolgreich auf, aber du siehst nur Text statt eines interaktiven 5-Panel Bubble Tea Displays. Lass mich erklären, warum das so ist und wie das Template-System eigentlich funktionieren soll:

### Aktuelle Architektur

**1. Template-Struktur:**
```nix
# In tui-engine/api.nix
templates."5panel".createTUI 
  "📦 Module Manager"           # Titel
  [ "📋 List Modules" "🔍 Search/Filter" "⚙️ Settings" "❌ Quit" ]  # Menu Items
  actions.getModuleList         # Content für Panel 1 (Liste)
  actions.getFilterPanel        # Content für Panel 2 (Filter)  
  actions.getDetailsPanel       # Content für Panel 3 (Details)
  actions.getActionsPanel       # Content für Panel 4 (Actions)
```

**2. Parameter-Fluss:**
- `tui.nix` ruft das Template auf
- Template bekommt Nix-Funktionen als Parameter (nicht die Ergebnisse!)
- Go Binary bekommt diese Funktionen als Command-Line Args oder Environment Vars
- Go Binary ruft diese Nix-Funktionen während der Laufzeit auf

### Warum siehst du nur Text?

Das liegt daran, dass die **Bubble Tea Go Binary noch nicht implementiert ist**. Die Nix-Seite baut das Binary erfolgreich, aber das Go-Programm macht wahrscheinlich nur:

```go
// Pseudo-Code was aktuell passiert
func main() {
    fmt.Println("📦 Module Manager TUI Starting")
    fmt.Println("ℹ Loading modules...")
    // Runtime Discovery läuft
    // Aber KEINE Bubble Tea TUI wird gestartet!
}
```

### Wie Module ihre Menus bauen (Theorie)

**1. Nix-Template definiert Layout:**
```nix
# tui-engine/api.nix
create5PanelTUI = { title, menuItems, getList, getFilter, getDetails, getActions }:
  # Hier wird das Go Binary gebaut mit diesen Parametern
  buildTUIApp { ... }
```

**2. Module definiert Content-Funktionen:**
```nix
# actions.nix
{
  getModuleList = ''
    ${runtimeDiscovery}
    main | jq -r '.[] | "\(.id)|\(.name)|\(.description)|\(.category)|\(.status)|\(.version)|\(.path)"' 2>/dev/null || echo ""
  '';
  
  getFilterPanel = ''
    echo "🔍 FILTERS:"
    echo "Status: All" 
    echo "Category: All"
    echo "Search: Active"
  '';
  # usw...
}
```

**3. Go Binary bekommt diese als Callbacks:**
- Beim Start bekommt die Go Binary die Nix-Funktionen als executable Scripts
- Während der Laufzeit ruft Go diese Scripts auf um Content zu bekommen
- Beispiel: User drückt 'l' für Liste → Go ruft `getModuleList` Script auf

**4. Interaktivität:**
- Bubble Tea Model definiert State (selectedModule, currentPanel, filters, etc.)
- Update-Funktion behandelt Keypresses (↑↓ für Navigation, Enter für Select, etc.)
- View-Funktion rendert das 5-Panel Layout basierend auf current State
- Content wird lazy geladen durch Aufruf der Nix Scripts

### Was fehlt noch?

1. **Vollständige Go Bubble Tea Implementation** mit:
   - Model struct für State Management
   - Update function für Key Handling  
   - View function für 5-Panel Rendering
   - Runtime execution der Nix content functions

2. **Parameter Passing** von Nix zu Go:
   - Nix functions müssen als executable scripts an Go übergeben werden
   - Go muss diese scripts während runtime aufrufen können

3. **CLI Registry Integration** muss das Binary richtig aufrufen

Das Template-System ist richtig designed - es fehlt nur die Go-Implementierung der Bubble Tea TUI selbst. Die Nix-Seite funktioniert perfekt! 🚀