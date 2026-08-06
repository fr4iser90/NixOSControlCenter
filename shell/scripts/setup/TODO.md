# Installer Roadmap — Tickets

Checklist zum Abarbeiten. Priorität: P0 = zuerst, P3 = später / nice-to-have.

Kontext: Wizard + Strategy-Pipeline (`init.sh` → detect → mode → writers → deploy).
Siehe Analyse: Preset-`features`/`overrides` oft ungenutzt, Memory/Storage-Checks fehlen, Disk-Härtung & Compatibility-Gate ausbaufähig.

---

## Phase 1 — Quick Wins (P0)

### [INST-01] Preset `features` / `overrides` wirklich anwenden
- [ ] In `setup-preset-profile.sh` `features { ... }` parsen
- [ ] Mapping auf bestehende Writer (`write_ssh_config`, `write_homelab_config`, `write_vm_config`, `write_bootentry_config`, …)
- [ ] `overrides` (z.B. `enableSSH`) anwenden
- [ ] Optional: `email` / `domain` schreiben falls Writer existiert
- [ ] Test: Preset mit Features → Config enthält erwartete Flags (dry-run)
- **Files:** `setup/config/setup-preset-profile.sh`, `setup/config/config-writer.sh`, `tests/test-presets-dry-run.sh`
- **Done when:** Desktop/Server-Preset-Features landen in der generierten Config

### [INST-02] Memory-Detection + `MEMORY_GB`
- [ ] `checks/hardware/memory.sh` anlegen (z.B. `/proc/meminfo` → GB)
- [ ] In `imports.sh` / Collect-Pfad sourcen und `MEMORY_GB` exportieren
- [ ] In Profile-Loader / Hardware-Writer nutzen (heute: Fallback auf unset)
- [ ] Test: Collect setzt `MEMORY_GB`, Writer schreibt RAM
- **Files:** `checks/hardware/memory.sh`, `setup/config/data-collection/collect-system-data.sh`, `setup-preset-profile.sh`
- **Done when:** Installer schreibt echte RAM-Werte statt null/leer

### [INST-03] Dead Code / stale Aliases aufräumen
- [ ] `ui-aliases.nix`: tote `install-quick-*` / fehlende Scripts entfernen oder fixen
- [ ] Fehlende Targets prüfen (`gaming-setup.sh`, `workstation-setup.sh`, …)
- [ ] Entscheiden: `state-machine.sh` verdrahten (INST-10) oder löschen
- [ ] Hackathon: ins Menü oder aus Docs/Imports klar als experimental markieren
- **Files:** `shell/hooks/ui-aliases.nix`, ggf. `lib/state-machine.sh`, mode menus
- **Done when:** `install*` Aliases zeigen nur auf existierende Pfade

### [INST-04] Docs an aktuellen Flow anpassen
- [ ] `docs/INSTALL.md` auf Preset-first + Dual-UI + dry-run + Dual-Layout aktualisieren
- [ ] Hardware-Compatibility-Claims mit echtem Detect/Gate abgleichen
- [ ] Kurz `shell/scripts/README.md` (falls veraltet) syncen
- **Done when:** Doc beschreibt denselben Flow wie `init.sh`

---

## Phase 2 — Hardware & Compatibility (P1)

### [INST-05] Disk / Partition-Härtung
- [ ] Partition-Naming: `nvme0n1p1` vs `sda1` vs `vda1` korrekt ableiten
- [ ] Destruktive Steps (wipe/format) nur mit explizitem Confirm / Install-Media-Mode
- [ ] Dry-run überall in `hardware-config.sh` respektieren
- [ ] Test: Dry-run disk path; Unit/Smoke für Naming-Matrix
- **Files:** `checks/hardware/hardware-config.sh`, `tests/test-installer-remaining.sh`
- **Done when:** Non-NVMe + dry-run sicher; kein Blind-Format ohne Opt-in

### [INST-06] Storage-Detection (optional Companion zu Memory)
- [ ] `checks/hardware/storage.sh` (größte Disk, Größe, Typ, Removable)
- [ ] Warnung bei zu kleiner Disk / nur Removable
- [ ] In Collect + ggf. Compatibility-Report einspeisen
- **Done when:** Installer kennt Disk-Größe/-Typ vor Partitionierung

### [INST-07] Compatibility Gate / Report
- [ ] Nach CPU/GPU/(Memory/Storage)-Detect Matrix prüfen:
  - GPU × DE (Wayland/X11)
  - Bootloader × UEFI/BIOS
  - Unsupported Combos → warn oder abort (Flag: soft/hard)
- [ ] Report im Wizard anzeigen (TUI + GUI)
- [ ] Align mit `docs/INSTALL.md` Supported-Liste
- **Files:** neuer Check z.B. `checks/hardware/compatibility.sh`, `init.sh`, UI prompts
- **Done when:** Unbekannte/kaputte Combos werden vor Deploy gemeldet

### [INST-08] Installer ↔ System-Manager HW Sync
- [ ] Post-Install Checks (`system-manager/.../hardware/{cpu,gpu}.nix`) mit Installer-Detect abgleichen
- [ ] Eine Naming-/Value-Convention (z.B. `GPU_CONFIG`, CPU vendor)
- [ ] Kurz doku: wer schreibt wann (install vs. later update)
- **Done when:** Gleiche HW-Werte Install + Runtime-Update

---

## Phase 3 — Architecture Hardening (P2)

### [INST-09] Preset-Parsing härten (Nix eval / Validierung)
- [ ] Option A: Presets mit `nix-instantiate` / `nix eval` validieren bevor Apply
- [ ] Option B: schrittweise von grep/awk auf strukturierten Parser
- [ ] Bestehende Parser-Edge-Case-Tests behalten / erweitern
- **Files:** `setup-preset-profile.sh`, presets under `modes/presets/`, `modes/profiles/`
- **Done when:** Kaputte Presets failen klar vor Writers

### [INST-10] State Machine / Wizard-Back (oder entfernen)
- [ ] Entweder: ESC/Back im multi-step TUI via `state-machine.sh` verdrahten
- [ ] Oder: ungenutzten Code löschen (siehe INST-03)
- **Done when:** Kein toter State-Machine-Code mehr

### [INST-11] Legacy Desktop/Server Modes konsolidieren
- [ ] Entscheiden: Preset-Pfad ist SSOT; Legacy `modes/desktop|server/setup.sh` deprecaten
- [ ] Dispatch in `init.sh` vereinfachen
- [ ] Tests auf einen Happy-Path fokussieren, Legacy smoke behalten bis Removal
- **Done when:** Ein klarer Primary-Path + dokumentierter Legacy-Exit

### [INST-12] Profiles als First-Class Presets
- [ ] Entscheiden welche `modes/profiles/*` im Hauptmenü erscheinen (Jetson schon)
- [ ] Personal-Profile-Name-Map bereinigen oder Advanced-only dokumentieren
- [ ] Device-Profile Template (Hardware pinned vs. null = live detect)
- **Done when:** Menü und Profile-Ordner stimmen überein

---

## Phase 4 — Tests & Polish (P2–P3)

### [INST-13] Test-Lücken schließen
- [ ] Features-Block Apply (INST-01)
- [ ] Memory Write (INST-02)
- [ ] Non-NVMe Partition Naming (INST-05)
- [ ] Monolith + Split Roundtrip inkl. SSH/Homelab Flags
- [ ] Compatibility soft-fail (INST-07)
- **Files:** `tests/test-presets-dry-run.sh`, `test-installer-full.sh`, `test-installer-remaining.sh`
- **Done when:** Neue Features haben mindestens einen dry-run Assert

### [INST-14] GUI/TUI Parity Check
- [ ] Alle Advanced-Optionen (Load Profile, Import, From Scratch) in beiden UIs
- [ ] Compatibility-Report in beiden UIs (nach INST-07)
- [ ] Answers-File Contract dokumentieren
- **Done when:** Kein Feature nur in einer UI

### [INST-15] Dry-run Story vervollständigen
- [ ] Alle destruktiven Pfade gelistet und gegated
- [ ] `install-dry` Alias + Docs stimmen
- [ ] CI/local: `run-all.sh` ohne Root-Schreiben grün
- **Done when:** Dry-run = zero disk mutation (außer temp answers)

---

## Empfohlene Reihenfolge

```
INST-01  features/overrides apply
INST-02  memory detection
INST-03  dead aliases cleanup
INST-05  disk hardening
INST-07  compatibility gate
INST-04  docs sync
INST-13  tests for 01/02/05/07
INST-06  storage (optional)
INST-08  system-manager sync
INST-09  nix preset validation
INST-11  legacy consolidate
INST-10  state machine decide
INST-12  profiles menu
INST-14  UI parity
INST-15  dry-run polish
```

---

## Notizen / Parking Lot

- [ ] Calamares / ISO-Pfad (`nixify/iso-builder`) vs. Shell-Installer: bewusst getrennt lassen oder später angleichen?
- [ ] Secure Boot / TPM Detection?
- [ ] Laptop vs. Desktop Heuristik (Battery, Chassis type)?
- [ ] Network Interface Detect für Server/Homelab Defaults?
- [ ] Virtualization Detect (bereits GPU-VM) → Auto-enable `vm-manager` Feature?

---

## Fortschritt

| ID | Status | Notes |
|----|--------|-------|
| INST-01 | ☐ | |
| INST-02 | ☐ | |
| INST-03 | ☐ | |
| INST-04 | ☐ | |
| INST-05 | ☐ | |
| INST-06 | ☐ | |
| INST-07 | ☐ | |
| INST-08 | ☐ | |
| INST-09 | ☐ | |
| INST-10 | ☐ | |
| INST-11 | ☐ | |
| INST-12 | ☐ | |
| INST-13 | ☐ | |
| INST-14 | ☐ | |
| INST-15 | ☐ | |
