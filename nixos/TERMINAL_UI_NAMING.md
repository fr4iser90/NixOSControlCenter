# Terminal-UI Namensvorschläge (OHNE "UI")

## 🎯 Was macht terminal-ui?

- **Colors**: Farben für Terminal-Output
- **Text Formatting**: Header, Subheader, Code-Blocks
- **Layout**: Indentation, Frames, Sections
- **Components**: Lists, Tables, Progress Bars, Boxes
- **Interactive**: Prompts, Spinners
- **Status**: Messages (info, success, warning, error), Badges

**Zusammenfassung:** Output-Formatting-Framework für Terminal/CLI
**Wichtig:** Es ist KEIN UI im klassischen Sinne - nur formatierte Terminal-Ausgabe!

---

## 📝 Namensvorschläge (OHNE "UI")

### Kategorie 1: **Output-bezogen** (Empfehlung)

#### `output` ⭐⭐⭐
**Pro:**
- ✅ Sehr kurz
- ✅ Klar: Output-Management
- ✅ Nicht terminal-spezifisch
- ✅ Einfach

**Contra:**
- ⚠️ Sehr generisch (aber OK wenn klar kontextualisiert)

**Verwendung:**
```nix
config.features.output.api
output = config.features.output.api;
```

---

#### `output-formatting` ⭐⭐
**Pro:**
- ✅ Sehr beschreibend
- ✅ Klar: Output-Formatierung
- ✅ Präzise

**Contra:**
- ⚠️ Länger
- ⚠️ "formatting" = eher Verb, nicht Substantiv

**Verwendung:**
```nix
config.features.output-formatting.api
```

---

#### `output-formatter`
**Pro:**
- ✅ Sehr beschreibend
- ✅ Klar: Formatiert Output
- ✅ Präzise

**Contra:**
- ⚠️ Länger
- ⚠️ "formatter" = eher Tool, nicht Framework

**Verwendung:**
```nix
config.features.output-formatter.api
```

---

#### `output-core` ⭐⭐
**Pro:**
- ✅ Kurz
- ✅ "Core" = fundamentale Funktion
- ✅ Passt wenn in Core verschoben wird

**Contra:**
- ⚠️ "Core" könnte verwirrend sein (wenn nicht in Core)

**Verwendung:**
```nix
config.features.output-core.api
```

---

### Kategorie 2: **Formatting-bezogen**

#### `formatting` ⭐
**Pro:**
- ✅ Sehr kurz
- ✅ Klar: Formatierung
- ✅ Einfach

**Contra:**
- ⚠️ Zu generisch (was wird formatiert?)
- ⚠️ Kollidiert mit anderen "formatting" Begriffen

**Verwendung:**
```nix
config.features.formatting.api
```

---

#### `formatter` ⭐⭐
**Pro:**
- ✅ Sehr kurz
- ✅ Klar: Formatter
- ✅ Professionell
- ✅ Einfach

**Contra:**
- ⚠️ Zu generisch (was formatiert?)
- ⚠️ Kollidiert mit anderen "formatter" Begriffen

**Verwendung:**
```nix
config.features.formatter.api
formatter = config.features.formatter.api;
```

---

#### `cli-formatter` ⭐⭐⭐
**Pro:**
- ✅ Klar: CLI-Formatter
- ✅ Präzise: Für Command Line Interface
- ✅ Beschreibend aber nicht zu lang
- ✅ Professionell
- ✅ Passt zu "command-center"

**Contra:**
- ⚠️ Länger als `formatter`

**Verwendung:**
```nix
config.features.cli-formatter.api
formatter = config.features.cli-formatter.api;
```

---

#### `console-formatter` ⭐
**Pro:**
- ✅ Klar: Console-Formatter
- ✅ Beschreibend

**Contra:**
- ⚠️ Länger
- ⚠️ "console" = weniger präzise als "cli" oder "terminal"

**Verwendung:**
```nix
config.features.console-formatter.api
```

---

#### `terminal-formatter` ⭐
**Pro:**
- ✅ Sehr klar: Terminal-Formatter
- ✅ Sehr beschreibend

**Contra:**
- ⚠️ Länger
- ⚠️ "terminal" = spezifisch (aber passt)

**Verwendung:**
```nix
config.features.terminal-formatter.api
```

---

### Kategorie 3: **Terminal/Console-bezogen**

#### `terminal-output` ⭐
**Pro:**
- ✅ Sehr beschreibend
- ✅ Klar: Terminal-Output

**Contra:**
- ⚠️ Länger
- ⚠️ "terminal" = spezifisch (aber passt)

**Verwendung:**
```nix
config.features.terminal-output.api
```

---

#### `console-output`
**Pro:**
- ✅ Beschreibend
- ✅ Klar: Console-Output

**Contra:**
- ⚠️ Länger
- ⚠️ "console" = weniger präzise als "terminal"

**Verwendung:**
```nix
config.features.console-output.api
```

---

#### `cli-output`
**Pro:**
- ✅ Kurz
- ✅ Klar: CLI-Output
- ✅ Präzise

**Contra:**
- ⚠️ "CLI" = Command Line Interface (nicht ganz präzise)

**Verwendung:**
```nix
config.features.cli-output.api
```

---

### Kategorie 4: **Display/Print-bezogen**

#### `display`
**Pro:**
- ✅ Kurz
- ✅ Klar: Display-Management
- ✅ Professionell

**Contra:**
- ⚠️ "display" = eher Hardware, nicht Output

**Verwendung:**
```nix
config.features.display.api
```

---

#### `print`
**Pro:**
- ✅ Sehr kurz
- ✅ Klar: Print-Funktionen

**Contra:**
- ⚠️ "print" = eher Funktion, nicht Framework
- ⚠️ Kollidiert mit anderen "print" Begriffen

**Verwendung:**
```nix
config.features.print.api
```

---

## 🏆 Top 3 Empfehlungen (OHNE "UI")

### 1. **`output`** ⭐⭐⭐
**Warum:**
- ✅ Sehr kurz
- ✅ Klar: Output-Management
- ✅ Nicht terminal-spezifisch
- ✅ Einfach und professionell

**Code:**
```nix
output = config.features.output.api;
# Oder kurz:
out = config.features.output.api;
```

---

### 2. **`output-core`** ⭐⭐
**Warum:**
- ✅ Kurz
- ✅ "Core" = fundamentale Funktion
- ✅ Passt zu "command-center" (beide kurz)
- ✅ Klingt nach fundamentale Infrastruktur

**Code:**
```nix
output = config.features.output-core.api;
```

---

### 3. **`formatter`** ⭐
**Warum:**
- ✅ Kurz
- ✅ Klar: Formatter
- ✅ Professionell
- ⚠️ Aber: Eher Tool, nicht Framework

**Code:**
```nix
formatter = config.features.formatter.api;
```

---

## 📊 Vergleichstabelle (OHNE "UI")

| Name | Länge | Klarheit | Präzision | Empfehlung |
|------|-------|----------|-----------|------------|
| `cli-formatter` | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| `formatter` | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐ |
| `console-formatter` | ⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐ |
| `terminal-formatter` | ⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| `output` | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐ |
| `output-core` | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| `output-formatting` | ⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| `cli-output` | ⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐ |

---

## 💡 Kontext: Andere Feature-Namen

**Aktuelle Features:**
- `terminal-ui` (zu ändern - kein UI!)
- `command-center` (kurz, prägnant)
- `system-checks` (beschreibend)
- `system-logger` (beschreibend)
- `system-updater` (beschreibend)

**Muster:**
- Kurz: `command-center`
- Beschreibend: `system-*`

**Empfehlung:**
- `output` passt zu `command-center` (beide kurz)
- `output-core` passt zu `command-center` (beide kurz + "core")
- `output-formatting` passt zu `system-*` (beschreibend)

---

## 🎯 Finale Empfehlung

### **`cli-formatter`** ⭐⭐⭐

**Warum:**
1. ✅ Klar: CLI-Formatter (Command Line Interface)
2. ✅ Präzise: Für Terminal/Console Output
3. ✅ Professionell
4. ✅ Beschreibend aber nicht zu lang
5. ✅ KEIN "UI" im Namen (korrekt!)
6. ✅ Passt zu "command-center" (beide haben "cli"/"command")

**Migration:**
```nix
# Alt
ui = config.features.terminal-ui.api;

# Neu
formatter = config.features.cli-formatter.api;
# Oder kurz:
fmt = config.features.cli-formatter.api;
```

**Alternativen:**
- `formatter` - Sehr kurz, aber generisch
- `console-formatter` - Länger, "console" weniger präzise
- `terminal-formatter` - Länger, "terminal" spezifisch
- `output` - Sehr kurz, aber nicht beschreibend genug

---

## ❓ Fragen zur Entscheidung

1. **Soll der Name kurz sein?** → `output` oder `formatter`
2. **Soll der Name beschreibend sein?** → `output-formatting` oder `terminal-output`
3. **Soll "Core" im Namen sein?** → `output-core`
4. **Soll "UI" im Namen sein?** → ❌ NEIN! (Es ist kein UI)

---

## 📝 Zusammenfassung

**Top 3 (OHNE "UI"):**
1. `cli-formatter` ⭐⭐⭐ (Empfehlung)
2. `formatter` ⭐⭐
3. `output` ⭐⭐

**Entscheidungskriterien:**
- Kurz → `formatter`
- Beschreibend → `cli-formatter` oder `terminal-formatter`
- Professionell → `cli-formatter` oder `formatter`
- Einfach → `formatter`

**Vergleich CLI/Terminal/Console:**
- `cli-formatter` ⭐⭐⭐ - Präzise, professionell
- `terminal-formatter` ⭐ - Sehr beschreibend, aber länger
- `console-formatter` ⭐ - Beschreibend, aber "console" weniger präzise

**Wichtig:** KEIN "UI" im Namen - es ist nur Output-Formatting für CLI/Terminal!

