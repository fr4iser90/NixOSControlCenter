# Module Manager TUI Design

## 🎯 ZIEL & VISION

Interaktive, moderne Terminal-UI für das Management von NixOS Modulen mit allen erdenklichen Features für maximale Benutzerfreundlichkeit.

---

## 🔧 WAS MACHT DER MODULE MANAGER?

### Core Funktionen:
- **Runtime Discovery**: Automatische Erkennung ALLER verfügbarer Module
- **Status Anzeige**: Echtzeit-Status (enabled/disabled/error) aus Config-Dateien
- **Batch Operations**: Mehrere Module gleichzeitig aktivieren/deaktivieren
- **Smart Dependencies**: Automatische Erkennung von Modul-Abhängigkeiten
- **Configuration Preview**: Zeige geänderte Config vor dem Anwenden
- **Rollback Support**: Einfaches Zurückrollen von Änderungen

### Advanced Features:
- **Suchen & Filtern**: Nach Name, Kategorie, Status
- **Kategorien-Gruppierung**: Module nach Typ gruppieren (core/modules)
- **Modul-Details**: Zeige README, Optionen, Abhängigkeiten
- **Configuration Editing**: Inline Config-Editing für einfache Optionen
- **Templates**: Vorgefertigte Modul-Kombinationen für häufige Setups

---

## 🎨 UI DESIGN KONZEPT

### Haupt-Layout (3-Panel Design):

```
┌─ Module Manager ── Search: [________________] ──┐
│                                                 │
│ ┌─ Module List ──────────────────┐ ┌─ Details ─┐ │
│ │                               │ │           │ │
│ │ □ system-manager              │ │ Status:   │ │
│ │ □ cli-registry                │ │ ✓ enabled │ │
│ │ □ nixos-control-center        │ │           │ │
│ │ □ boot-manager                │ │ Version:  │ │
│ │ □ network-manager             │ │ 1.2.0     │ │
│ │ □ audio-manager               │ │           │ │
│ │ □ display-manager             │ │ Desc:     │ │
│ │ □ package-manager             │ │ System    │ │
│ │ □ ...                         │ │ management│ │
│ └───────────────────────────────┘ │ utilities │ │
│                                   └───────────┘ │
│                                                 │
│ ┌─ Actions ───────────────────────────────────┐ │
│ │ [Enable] [Disable] [Details] [Config] [Help] │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Status: Ready | Selected: 3 modules             │
└─────────────────────────────────────────────────┘
```

### Alternative Layout (Vollbild-Liste):

```
┌─ Module Manager ── [Search: ________________] ── [Filter ▼] ──┐
│                                                               │
│   □ ✅ system-manager        (core)     System management     │
│   □ ❌ cli-registry          (core)     CLI command registry  │
│   □ ⚠️  nixos-control-center  (core)     NCC orchestration    │
│   □ ✅ boot-manager          (modules)  Boot configuration    │
│   □ ❌ network-manager       (modules)  Network settings      │
│   □ ✅ audio-manager         (modules)  Audio configuration   │
│   □ ✅ display-manager       (modules)  Display settings      │
│   □ ❌ package-manager       (modules)  Package management    │
│                                                               │
│   [Space] Select  [e] Enable  [d] Disable  [Enter] Details     │
│   [r] Refresh  [s] Search  [f] Filter  [q] Quit                │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## 🏗️ IMPLEMENTIERUNGS-ARCHITEKTUR

### Bubble Tea Model:
```go
type ModuleManagerModel struct {
    // Data
    modules         []Module
    filteredModules []Module
    selected        map[int]bool

    // UI State
    cursor          int
    searchQuery     string
    currentFilter   Filter
    showDetails     bool
    detailsModule   *Module

    // Async
    loading         bool
    lastAction      string
    error           error

    // UI Components
    list            *ListComponent
    searchBox       *TextInput
    filterDropdown  *Select
}
```

### Module Struct:
```go
type Module struct {
    ID          string
    Name        string
    Description string
    Category    string
    Status      string
    Version     string
    Path        string
    ConfigPath  string
    Dependencies []string
    Options     []ModuleOption
    Readme      string
}
```

---

## 🎮 INTERAKTIONEN & WORKFLOWS

### 1. Modul Auswahl & Batch Operations:
```
1. [Space] zum Auswählen mehrerer Module
2. [e] Enable alle ausgewählten
3. [d] Disable alle ausgewählten
4. Bestätigungsdialog mit Preview der Änderungen
```

### 2. Suchen & Filtern:
```
1. [/] oder [s] für Suchmodus
2. Live-Search während Tippen
3. [f] für Filter-Dropdown:
   - Alle Module
   - Nur Core Module
   - Nur User Module
   - Nur Enabled
   - Nur Disabled
   - Mit Fehlern
```

### 3. Modul-Details:
```
1. [Enter] auf Modul für Details-View
2. Zeigt:
   - Vollständige Beschreibung
   - Aktuelle Config
   - Abhängigkeiten
   - README (falls vorhanden)
   - Verfügbare Optionen
```

### 4. Configuration Editing:
```
1. [c] für Config-Edit Modus
2. Inline Editing für einfache Optionen
3. Syntax-Highlighting für Nix
4. Validation vor dem Speichern
```

---

## 🎨 VISUAL DESIGN & UX

### Farbschema:
- **Header**: Blau (#00AAFF)
- **Enabled Module**: Grün (✅)
- **Disabled Module**: Rot (❌)
- **Error Module**: Gelb (⚠️)
- **Selected**: Cyan (█)
- **Cursor**: White on Blue

### Icons & Symbole:
- ✅ Enabled
- ❌ Disabled
- ⚠️ Error/Config Issue
- 🔄 Loading
- 📦 Core Module
- 🔧 User Module
- 🔍 Search
- ⚙️ Settings
- 💾 Save
- ↩️ Back

### Responsive Design:
- **Wide Terminal**: 3-Panel Layout
- **Narrow Terminal**: Single Panel mit Tabs
- **Mobile/Small**: Kompakte Liste

---

## 🔄 WORKFLOW INTEGRATION

### Mit anderen NCC Komponenten:
- **CLI Registry**: Commands automatisch registrieren
- **System Manager**: Integration mit system-manager commands
- **Configuration Manager**: Config-Änderungen propagieren

### State Management:
- **Runtime State**: Aktuelle Modul-Status
- **Pending Changes**: Noch nicht angewendete Änderungen
- **Configuration Backup**: Automatische Backups vor Änderungen

---

## 🚀 ROADMAP & ITERATIONEN

### Phase 1: Core Functionality
- ✅ Runtime Discovery
- ✅ Basic List View
- ✅ Enable/Disable Operations
- ⏳ Search & Filter

### Phase 2: Advanced Features
- ⏳ Modul-Details View
- ⏳ Batch Operations
- ⏳ Configuration Preview

### Phase 3: Power User Features
- ⏳ Inline Config Editing
- ⏳ Dependency Management
- ⏳ Template System

### Phase 4: Polish
- ⏳ Responsive Design
- ⏳ Keyboard Shortcuts
- ⏳ Help System

---

## 🎯 ERFOLGSKRITERIEN

### User Experience:
- **Intuitiv**: Keine Dokumentation nötig für Basics
- **Schnell**: < 2 Sekunden zum Laden
- **Sicher**: Bestätigungen für gefährliche Operationen
- **Informative**: Klare Status-Anzeigen und Fehlermeldungen

### Technical:
- **Reliable**: Funktioniert immer, auch bei Config-Fehlern
- **Fast**: UI bleibt responsive bei vielen Modulen
- **Compatible**: Arbeitet mit allen Modul-Typen
- **Maintainable**: Klare Code-Struktur für Erweiterungen
