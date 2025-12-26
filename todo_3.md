## 🎯 **Management-TUI Plan: module-manager, system-manager & ncc Hauptmenü**

Du hast recht - wir brauchen klare TUI-Menüs für die Management-Ebene! Hier ist der Plan:

## 🏗️ **1. NCC Hauptmenü** (`ncc`)

**Zweck:** Übersicht aller NCC-Bereiche via fzf

```
$ ncc
🔧 Module Management (10/25 active)       │ 📊 Status: 10/25 modules enabled
⚙️ System Operations (NixOS 25.11)        │ ✅ Health: Healthy, Uptime: 2d 4h
👥 User Administration (3 users)          │ 👤 Users: 3 total, 2 admins
📦 Package Operations (152 sys, 45 user)  │ 📦 System: 152, User: 45 packages
⚙️ Configuration (15 configs)             │ 🔧 Modified: 3 configs
🔄 Quick Update (System)                  │ ⚡ Last: 2 days ago
💾 Quick Backup (System)                  │ 💾 Last: 1 day ago

> module  ↵  (fuzzy search aktiv)
6/8     (TAB für Multi-Select, Enter für Navigation)
```

**Reines fzf-Interface:**
- **Bereichs-Übersicht** mit Live-Status
- **Quick-Actions** für häufige Tasks
- **Direkte Navigation** zu Unter-Tools
- **Status-Preview** rechts mit Details

## 🔧 **2. Module-Manager** (`ncc module-manager`)

**Zweck:** Modul-Verwaltung via fzf

```
$ ncc module-manager
❌ bootentry-manager (Infrastructure)    │ 🔧 Module: bootentry-manager
❌ homelab-manager (Infrastructure)      │ 📂 Category: Infrastructure
✅ audio (Core)                          │ ⚡ Status: enabled
✅ boot (Core)                           │ 📝 Description: Core audio module
❌ ssh-server-manager (Security)         │ 🎯 Actions: enable, disable, info
❌ ai-workspace (Specialized)            │ 🔍 Fuzzy search: "audio" → filter

> audio  ↵  (fuzzy search aktiv)
8/16    (TAB für Multi-Select, Enter für Aktion)
```

**Reines fzf-Interface:**
- **Fullscreen fuzzy search** über gesamtes Terminal
- **Live-Preview-Panel** rechts mit Modul-Details
- **Multi-Select** mit TAB für Bulk-Operations
- **Sofort-Aktionen** über Enter (enable/disable/configure)
- **Kategorie-Gruppen** zur besseren Übersicht
- **Vim-Keys** (Ctrl-J/K) für Navigation

## ⚙️ **3. System-Manager** (`ncc system`)

**Zweck:** System-Operationen via fzf

```
$ ncc system
🔄 System Update (Core)                  │ ⚡ Last run: 2 days ago
💾 Create Backup (Core)                  │ 💾 Size: 45GB, Duration: 5min
🔍 System Check (Core)                   │ ✅ Status: Healthy
📋 View Logs (Core)                      │ 📊 Errors: 0, Warnings: 3
🧹 Cleanup System (Maintenance)          │ 💾 Space reclaim: 2.1GB
🔧 Repair Issues (Maintenance)           │ 🔍 Found issues: 0
📊 Generate Report (Maintenance)         │ 📈 Health score: 95%
📈 Live Monitor (Monitoring)             │ 📊 CPU: 15%, RAM: 60%

> update  ↵  (fuzzy search aktiv)
7/9     (TAB für Multi-Select, Enter für Execute)
```

**Reines fzf-Interface:**
- **Operations-Liste** mit Live-Status
- **Kategorie-Gruppen** (Core, Maintenance, Monitoring)
- **Preview-Panel** mit Details und Historie
- **Sofort-Execution** über Enter
- **Multi-Select** für Batch-Operations

## 📋 **Implementierungs-Plan:**

### **Phase 1: Reine fzf-Implementierung**
```bash
# 1. Module-Manager fzf
module-manager/
├── commands.nix            # ncc module-manager Implementation
└── lib/
    ├── discovery.nix       # Modul-Discovery
    └── actions.nix         # enable/disable Logic

# 2. System-Manager fzf
system-manager/
├── commands.nix            # ncc system-manager Implementation
└── lib/
    ├── status.nix          # System-Status
    └── operations.nix      # System-Operations

# 3. NCC Hauptmenü fzf
nixos-control-center/
├── commands/               # CLI-Commands
│   └── main.nix            # ncc (Haupt-fzf-Menü)
└── lib/
    └── fzf-helpers.nix     # fzf-Utilities
```

### **Phase 2: Integration**
- **Cross-Links:** NCC-Menü → Module-Manager → System-Manager
- **Status-Sync:** Alle Menüs zeigen aktuelle System-Status
- **History:** Zuletzt verwendete Aktionen merken

### **Phase 3: Advanced Features**
- **Vim-Navigation:** h/j/k/l für Menü-Navigation (wenn nicht in fzf)
- **fzf-Integration:** Fullscreen fuzzy search für Modul-Auswahl
- **Sessions:** Zuletzt verwendete Aktionen merken
- **Terminal-Optimierung:** fzf übernimmt Terminal komplett bei Bedarf

## 🎯 **Was zuerst implementieren?**

## ✅ **GEWÄHLT: OPTION B - REINES FZF-INTERFACE!**

**Keine Mischung - nur fzf!** 🎯