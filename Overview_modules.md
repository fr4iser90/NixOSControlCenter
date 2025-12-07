# Module Ebenen-Analyse

Übersicht aller Module mit ihrer Verschachtelungstiefe (Submodule-Ebenen).

## Legende

- **Level 0**: Hauptmodul (keine Submodule)
- **Level 1**: 1 Ebene Submodule (z.B. `handlers/`, `providers/`)
- **Level 2**: 2 Ebenen Submodule (z.B. `handlers/feature-manager/sub-handlers/`)
- **Level 3+**: 3+ Ebenen (tief verschachtelt)

**Hinweis**: Diese Analyse zählt **funktionale Submodule**, nicht nur Verzeichnisse. Verzeichnisse wie `lib/`, `scripts/`, `migrations/` zählen als Level 1, wenn sie funktionale Submodule enthalten.

---

## Core-Module (`nixos/core/`)

### 1. **boot** - Level 1
```
boot/
├── bootloaders/          # Level 1
│   ├── grub.nix
│   ├── refind.nix
│   └── systemd-boot.nix
└── default.nix
```
**Submodule**: `bootloaders/` (3 Provider: grub, refind, systemd-boot)

---

### 2. **cli-formatter** - Level 1
```
cli-formatter/
├── components/           # Level 1
│   ├── boxes.nix
│   ├── lists.nix
│   ├── progress.nix
│   └── tables.nix
├── core/                 # Level 1
│   ├── layout.nix
│   └── text.nix
├── interactive/          # Level 1
│   ├── prompts.nix
│   └── spinners.nix
├── status/               # Level 1
│   ├── badges.nix
│   └── messages.nix
└── default.nix
```
**Submodule**: `components/`, `core/`, `interactive/`, `status/` (funktionale Bereiche)

---

### 3. **command-center** - Level 1
```
command-center/
├── cli/                  # Level 1
│   ├── command-preview.nix
│   └── manager-preview.nix
├── registry/             # Level 1
│   ├── types.nix
│   └── default.nix
└── default.nix
```
**Submodule**: `cli/`, `registry/`

---

### 4. **config** - Level 2
```
config/
├── config-schema/        # Level 1
│   ├── migrations/       # Level 2
│   │   └── v1-to-v2.nix
│   ├── v1.nix
│   └── v2.nix
├── config-schema.nix
├── config-detection.nix
├── config-migration.nix
└── default.nix
```
**Submodule**: `config-schema/` → `migrations/` (2 Ebenen)

---

### 5. **desktop** - Level 2
```
desktop/
├── audio/                # Level 1
│   ├── alsa.nix
│   ├── pipewire.nix
│   └── pulseaudio.nix
├── display-managers/     # Level 1
│   ├── gdm/              # Level 2
│   │   ├── packages.nix
│   │   └── settings.nix
│   ├── lightdm/          # Level 2
│   │   ├── packages.nix
│   │   └── settings.nix
│   └── sddm/             # Level 2
│       ├── packages.nix
│       └── settings.nix
├── display-servers/      # Level 1
│   ├── wayland/          # Level 2
│   │   ├── base.nix
│   │   └── extensions.nix
│   └── x11/              # Level 2
│       ├── base.nix
│       └── extensions.nix
├── environments/         # Level 1
│   ├── gnome/            # Level 2
│   │   ├── packages.nix
│   │   └── settings.nix
│   ├── plasma/           # Level 2
│   │   ├── packages.nix
│   │   └── settings.nix
│   └── xfce/             # Level 2
│       ├── packages.nix
│       └── settings.nix
└── themes/               # Level 1
    ├── color-schemes/    # Level 2
    │   └── schemes/      # Level 3 (aber nur Dateien, keine Submodule)
    ├── cursors/
    ├── fonts/
    └── icons/
```
**Submodule**: 
- Level 1: `audio/`, `display-managers/`, `display-servers/`, `environments/`, `themes/`
- Level 2: `display-managers/{gdm,lightdm,sddm}/`, `display-servers/{wayland,x11}/`, `environments/{gnome,plasma,xfce}/`
- **Max Level**: 2 (funktionale Submodule)

---

### 6. **hardware** - Level 1
```
hardware/
├── cpu/                  # Level 1
│   ├── amd.nix
│   ├── intel.nix
│   └── vm-gpu.nix
├── gpu/                  # Level 1
│   ├── amd.nix
│   ├── nvidia.nix
│   └── ...
└── memory/               # Level 1
    └── default.nix
```
**Submodule**: `cpu/`, `gpu/`, `memory/`

---

### 7. **network** - Level 1
```
network/
├── lib/                  # Level 1
│   └── rules.nix
├── recommendations/      # Level 1
│   └── services.nix
├── firewall.nix
├── networkmanager.nix
└── default.nix
```
**Submodule**: `lib/`, `recommendations/`

---

### 8. **system** - Level 0
```
system/
└── default.nix
```
**Submodule**: Keine

---

### 9. **system-manager** - Level 1
```
system-manager/
├── handlers/             # Level 1
│   ├── feature-manager.nix
│   ├── channel-manager.nix
│   ├── desktop-manager.nix
│   ├── system-update.nix
│   ├── feature-version-check.nix
│   └── feature-migration.nix
├── lib/                  # Level 1
│   └── default.nix
├── scripts/              # Level 1
│   ├── check-versions.nix
│   └── update-features.nix
├── validators/           # Level 1
│   └── config-validator.nix
└── default.nix
```
**Submodule**: `handlers/`, `lib/`, `scripts/`, `validators/`
**Wichtig**: Handler sind flach (keine Sub-Handler)

---

### 10. **user** - Level 1
```
user/
├── home-manager/         # Level 1
│   ├── roles/            # Level 2 (aber nur Dateien, keine Submodule)
│   │   ├── admin.nix
│   │   ├── guest.nix
│   │   └── ...
│   └── shellInit/        # Level 2 (aber nur Dateien, keine Submodule)
│       ├── bashInit.nix
│       └── ...
└── default.nix
```
**Submodule**: `home-manager/` (Level 1)
**Max Level**: 1 (funktionale Submodule)

---

## Feature-Module (`nixos/features/`)

### 1. **ai-workspace** - Level 3+
```
ai-workspace/
├── containers/           # Level 1
│   ├── databases/       # Level 2
│   │   ├── postgres/    # Level 3
│   │   └── vector/      # Level 3
│   ├── ollama/          # Level 2
│   └── training/        # Level 2
│       ├── dataset-generator/  # Level 3
│       └── tests/       # Level 3
├── llm/                 # Level 1
│   ├── api/             # Level 2
│   │   └── rest/        # Level 3
│   │       ├── endpoints/  # Level 4
│   │       │   ├── crud/   # Level 5
│   │       │   └── vector/ # Level 5
│   │       └── services/   # Level 4
│   └── training/        # Level 2
│       ├── config/      # Level 3
│       └── pipeline/    # Level 3
├── schemas/             # Level 1
│   ├── postgres/        # Level 2
│   └── vector/          # Level 2
└── services/            # Level 1
    ├── huggingface.nix
    └── ollama.nix
```
**Submodule**: Sehr tief verschachtelt (bis Level 5)
**Status**: ⚠️ **SEHR KOMPLEX** - sollte refactored werden

---

### 2. **bootentry-manager** - Level 1
```
bootentry-manager/
├── providers/            # Level 1
│   ├── grub.nix
│   ├── refind.nix
│   └── systemd-boot.nix
├── lib/                  # Level 1
│   ├── common.nix
│   └── types.nix
└── default.nix
```
**Submodule**: `providers/`, `lib/`

---

### 3. **hackathon-manager** - Level 0
```
hackathon-manager/
├── hackathon-create.nix
├── hackathon-fetch.nix
└── default.nix
```
**Submodule**: Keine

---

### 4. **homelab-manager** - Level 1
```
homelab-manager/
├── lib/                  # Level 1
│   └── homelab-utils.nix
├── homelab-create.nix
├── homelab-fetch.nix
└── default.nix
```
**Submodule**: `lib/`

---

### 5. **ssh-client-manager** - Level 1
```
ssh-client-manager/
├── scripts/              # Level 1
├── connection-handler.nix
├── connection-preview.nix
└── default.nix
```
**Submodule**: `scripts/`

---

### 6. **ssh-server-manager** - Level 1
```
ssh-server-manager/
├── scripts/              # Level 1
│   ├── approve-request.nix
│   ├── grant-access.nix
│   └── ...
├── auth.nix
├── monitoring.nix
└── default.nix
```
**Submodule**: `scripts/`

---

### 7. **system-checks** - Level 2
```
system-checks/
├── prebuild/             # Level 1
│   ├── checks/           # Level 2
│   │   ├── hardware/     # Level 3 (aber nur Dateien)
│   │   │   ├── cpu.nix
│   │   │   └── disk.nix
│   │   └── system/       # Level 3 (aber nur Dateien)
│   │       ├── security.nix
│   │       └── services.nix
│   └── lib/              # Level 2
├── postbuild/            # Level 1
│   └── default.nix
└── default.nix
```
**Submodule**: 
- Level 1: `prebuild/`, `postbuild/`
- Level 2: `prebuild/checks/`, `prebuild/lib/`
- **Max Level**: 2 (funktionale Submodule)

---

### 8. **system-config-manager** - Level 0
```
system-config-manager/
├── default.nix
└── options.nix
```
**Submodule**: Keine

---

### 9. **system-discovery** - Level 1
```
system-discovery/
├── scanners/             # Level 1
│   ├── browser.nix
│   ├── credentials.nix
│   ├── desktop.nix
│   ├── ide.nix
│   ├── packages.nix
│   └── steam.nix
├── encryption.nix
├── github-download.nix
└── default.nix
```
**Submodule**: `scanners/`

---

### 10. **system-logger** - Level 1
```
system-logger/
├── collectors/           # Level 1
│   ├── bootentries.nix
│   ├── bootloader.nix
│   ├── desktop.nix
│   ├── network.nix
│   └── ...
└── default.nix
```
**Submodule**: `collectors/`

---

### 11. **vm-manager** - Level 3
```
vm-manager/
├── base/                 # Level 1
│   └── config/           # Level 2
│       ├── network.nix
│       └── storage.nix
├── containers/           # Level 1
│   ├── engines/          # Level 2
│   │   ├── docker.nix
│   │   └── podman.nix
│   └── templates/        # Level 2
│       └── default.nix
├── core/                 # Level 1
│   ├── monitoring.nix
│   ├── networking.nix
│   └── storage.nix
├── iso-manager/          # Level 1
│   ├── hash-collector.nix
│   ├── iso-download.nix
│   └── iso-validation.nix
├── machines/             # Level 1
│   └── drivers/          # Level 2
│       └── qemu.nix
├── lib/                  # Level 1
│   ├── distros.nix
│   └── vm.nix
└── testing/              # Level 1
    └── default.nix
```
**Submodule**: 
- Level 1: `base/`, `containers/`, `core/`, `iso-manager/`, `machines/`, `lib/`, `testing/`
- Level 2: `base/config/`, `containers/engines/`, `containers/templates/`, `machines/drivers/`
- **Max Level**: 2 (funktionale Submodule)

---

## Zusammenfassung

### Ebenen-Verteilung

| Level | Core-Module | Feature-Module | Gesamt |
|-------|-------------|---------------|--------|
| **0** | 1 (system) | 2 (hackathon-manager, system-config-manager) | 3 |
| **1** | 7 (boot, cli-formatter, command-center, hardware, network, system-manager, user) | 6 (bootentry-manager, homelab-manager, ssh-client-manager, ssh-server-manager, system-discovery, system-logger) | 13 |
| **2** | 2 (config, desktop) | 2 (system-checks, vm-manager) | 4 |
| **3+** | 0 | 1 (ai-workspace) | 1 |

### Statistik

- **Durchschnittliche Ebenen**: ~1.2
- **Maximale Ebenen**: 5 (ai-workspace)
- **Meiste Module**: Level 1 (13 Module)
- **Komplexeste Module**: 
  - `ai-workspace` (Level 5) ⚠️
  - `vm-manager` (Level 2)
  - `desktop` (Level 2)
  - `system-checks` (Level 2)

### Empfehlungen

1. **System-Manager**: Level 1 ✅ (perfekt für Hybrid-Ansatz)
2. **ai-workspace**: ⚠️ **Refactoring nötig** (zu tief verschachtelt)
3. **Alle anderen**: Level 0-2 ✅ (akzeptabel)

### Config-Struktur-Empfehlung

**Hybrid-Ansatz:**
- **System-Manager**: 1 Ebene (`features`, `channels`, `desktop`, etc.)
- **Feature-Module**: Können eigene Submodule haben (Level 1-2)
- **Maximal**: 2 Ebenen für Config-Struktur

**Beispiel:**
```nix
# system-manager-config.nix (1 Ebene)
{
  features = { system-logger = true; };
  channels = { autoUpdate = false; };
}

# system-logger-config.nix (kann Submodule haben)
{
  logging = { level = "info"; };
  rotation = { strategy = "daily"; };
}
```

