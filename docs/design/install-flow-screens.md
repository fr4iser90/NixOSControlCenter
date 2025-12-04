# Install Flow: Alle Screens Visualisiert

## 📺 SCREEN 1: Installation Type Selection

```
┌─────────────────────────────────────────────────────────────┐
│ Choose installation method                                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ▶ 📦 Presets                                                │
│    🔧 Custom Install                                          │
│    ⚙️  Advanced Options                                       │
│                                                              │
│  [Preview Window rechts]                                     │
│  ┌─────────────────────────┐                                │
│  │ Desktop                  │                                │
│  │ ──────────────────────── │                                │
│  │                          │                                │
│  │ Base desktop environment │                                │
│  │ with GUI (Plasma)...     │                                │
│  └─────────────────────────┘                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Navigation: ↑↓ zum Navigieren, Enter zum Bestätigen, Space für Preview
```

---

## 📺 SCREEN 2A: Preset Selection (wenn "📦 Presets" gewählt)

**PROBLEM: Headers sind auswählbar! Whitespaces werden angezeigt!**

```
┌─────────────────────────────────────────────────────────────┐
│ Select preset                                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ▶ 🖥️  System Presets          ← PROBLEM: AUSWÄHLBAR! ❌    │
│      Desktop                  ← Whitespace davor sichtbar   │
│      Server                    ← Whitespace davor sichtbar │
│      Homelab Server            ← Whitespace davor sichtbar  │
│                                                              │
│    🤖 Device Presets           ← PROBLEM: AUSWÄHLBAR! ❌    │
│      Jetson Nano               ← Whitespace davor sichtbar  │
│                                                              │
│  [Preview Window rechts]                                     │
│  ┌─────────────────────────┐                                │
│  │ Desktop                  │                                │
│  │ ──────────────────────── │                                │
│  │ Base desktop environment │                                │
│  │ with GUI (Plasma)...     │                                │
│  └─────────────────────────┘                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘

AKTUELLES VERHALTEN:
- Headers (🖥️ System Presets, 🤖 Device Presets) sind AUSWÄHLBAR ❌
- Whitespaces (  Desktop) werden in fzf angezeigt ❌
- Wenn Header ausgewählt → Error: "Cannot select category header"

SOLLTE SEIN:
- Headers NICHT auswählbar (nur visuell)
- Whitespaces sollten nicht sichtbar sein (oder sauber formatiert)
```

---

## 📺 SCREEN 2B: Custom Install Feature Selection

```
┌─────────────────────────────────────────────────────────────┐
│ Select features (Space to select, Enter to confirm)           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ▶ 🖥️  Desktop Environment      ← Header (auswählbar?)      │
│    ✓ plasma                    ← Mit ✓ markiert             │
│      gnome                                                      │
│      xfce                                                       │
│                                                              │
│    📦 Development               ← Header                      │
│      web-dev                                                    │
│      game-dev                                                   │
│      python-dev                                                 │
│      system-dev                                                 │
│                                                              │
│    🎮 Gaming & Media            ← Header                      │
│      streaming                                                  │
│      emulation                                                  │
│                                                              │
│    🐳 Containerization          ← Header                      │
│      docker                                                      │
│      docker-rootless                                            │
│      podman                                                     │
│                                                              │
│    💾 Services                  ← Header                      │
│      database                                                    │
│      web-server                                                 │
│      mail-server                                                │
│                                                              │
│    🖥️  Virtualization            ← Header                      │
│      qemu-vm                                                    │
│      virt-manager                                               │
│                                                              │
│  [Preview Window rechts]                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Navigation: Space/Tab zum Toggle, Ctrl-A für All, Enter zum Bestätigen
```

---

## 📺 SCREEN 2C: Advanced Options

```
┌─────────────────────────────────────────────────────────────┐
│ Advanced Options                                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ▶ 📁 Load Profile from File                                 │
│    📋 Show Available Profiles                                │
│    🔄 Import from Existing Config                            │
│                                                              │
│  [Preview Window rechts]                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📺 SCREEN 3A: Advanced → Load Profile from File

```
══════ Setup Mode ══════
[INFO] Selected modules: 📁 Load Profile from File

[INFO] Enter path to profile file:
  Examples:
  • profiles/fr4iser-home
  • /absolute/path/to/profile.nix
  • ~/my-config.nix

Profile path: _
```

---

## 📺 SCREEN 3B: Advanced → Show Available Profiles

```
┌─────────────────────────────────────────────────────────────┐
│ Available Profiles (Select one to load)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ▶ fr4iser-home                                             │
│    gira-home                                                 │
│    fr4iser-jetson                                            │
│                                                              │
│  [Preview Window rechts: zeigt Profile-Inhalt]              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📺 SCREEN 4: Homelab Server Setup Flow

### 4.1: Admin Username (Text Input)

```
══════ Homelab Configuration ══════
Debug: Admin user set to: fr4iser

[?] Enter admin username [fr4iser]: _
```

---

### 4.2: Homelab Type Selection (fzf)

```
┌─────────────────────────────────────────────────────────────┐
│ Select homelab type                                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ▶ Single-Server                                             │
│    Multi-Server (Docker Swarm)                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Navigation: ↑↓ zum Navigieren, Enter zum Bestätigen
```

---

### 4.3: Swarm Role Selection (fzf) - nur wenn "Multi-Server" gewählt

```
┌─────────────────────────────────────────────────────────────┐
│ Select Swarm role                                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ▶ Manager                                                   │
│    Worker                                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.4: Docker User Setup (Text Input)

**Nur wenn Single-Server gewählt wurde**

```
[?] Use separate user for Docker? (y/n) [n]: _
```

**Default:**
- `docker` (root) → Default: `y` (Extra User empfohlen)
- `docker-rootless` → Default: `n` (Main User OK)

---

### 4.5: Virtualization Username (Text Input)

**Nur wenn "Use separate user" = yes**

```
[?] Enter virtualization username(docker) [docker]: _
```

---

### 4.6: Virtualization Password (Text Input)

**Nur wenn "Use separate user" = yes**

```
[?] Enter password for virtualization user: _
```

---

### 4.7: Email Configuration (Text Input)

```
[?] Enter main email address [example@example.com]: _
```

---

### 4.8: Domain Configuration (Text Input)

```
[?] Enter domain name [example.com]: _
```

---

### 4.9: Desktop Enabled (Text Input)

```
[?] Enable desktop environment? (y/n) [n]: _
```

---

## 📺 SCREEN 5: Custom Install → Docker User Setup

**Nur wenn Docker-Feature ausgewählt wurde**

### 5.1: Docker User Setup Prompt

```
[?] Use separate user for Docker? (y/n) [y]: _
```

**Default basierend auf Docker-Mode:**
- `docker` → Default: `y`
- `docker-rootless` → Default: `n`

---

### 5.2: Virtualization Username (wenn "yes")

```
[?] Enter virtualization username(docker) [docker]: _
```

---

## 📺 SCREEN 6: Deployment/Completion

```
══════ Deployment ══════
[INFO] Building NixOS configuration...
[INFO] Deploying...
[SUCCESS] Setup complete! 🎉
```

---

## 🔴 PROBLEME IDENTIFIZIERT

### Problem 1: Preset Selection Headers sind auswählbar
**Location:** `setup-mode.sh` Zeile 44-50

**Aktuell:**
- Headers (`🖥️  System Presets`, `🤖 Device Presets`) werden als normale Zeilen angezeigt
- Sie sind AUSWÄHLBAR in fzf
- Nach Auswahl → Error: "Cannot select category header"

**Lösung:**
- Headers mit speziellem Präfix markieren (z.B. `__HEADER__🖥️  System Presets`)
- Beim Parsen filtern: Wenn Auswahl mit `__HEADER__` beginnt → Error
- ODER: Headers mit `--header-lines` ausblenden (geht nicht, da mehrere Header)

---

### Problem 2: Whitespaces werden in fzf angezeigt
**Location:** `setup-mode.sh` Zeile 31, 38

**Aktuell:**
- Presets werden mit `  $preset\n` hinzugefügt (2 Spaces)
- Diese Whitespaces werden in fzf SICHTBAR angezeigt
- Nach Auswahl wird `sed 's/^  //'` verwendet, um sie zu entfernen

**Problem:**
- fzf zeigt die Whitespaces an → sieht unprofessionell aus
- User sieht: `  Desktop` statt `Desktop`

**Lösung:**
- Headers mit Präfix markieren, Presets OHNE Whitespace
- Beim Parsen: Header-Präfix entfernen, Presets direkt verwenden

---

### Problem 3: Custom Install Headers sind auch auswählbar
**Location:** `setup-mode.sh` Zeile 196

**Aktuell:**
- Headers werden gefiltert mit: `if [[ ! "$choice" =~ ^[🖥️📦🎮🐳💾] ]]`
- Aber sie sind trotzdem in der Liste und AUSWÄHLBAR

**Lösung:**
- Gleiche Lösung wie bei Presets: Headers mit Präfix markieren

---

## ✅ LÖSUNG: Headers mit Präfix markieren

**Strategie:**
1. Headers mit `__HEADER__` Präfix markieren
2. Presets OHNE Whitespace hinzufügen
3. Beim Parsen: Headers filtern (wenn `__HEADER__` → Error)
4. Presets direkt verwenden (kein `sed` nötig)

**Beispiel:**
```bash
preset_list+="__HEADER__🖥️  System Presets\n"
for preset in "${SYSTEM_PRESETS[@]}"; do
    preset_list+="$preset\n"  # KEIN Whitespace!
done
```

**Beim Parsen:**
```bash
if [[ "$preset_choice" =~ ^__HEADER__ ]]; then
    log_error "Cannot select category header"
    return 1
fi
# Kein sed nötig, da kein Whitespace!
```

