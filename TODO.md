# ModuleConfig Centralization & Merging

## 🎯 ZIEL: moduleConfig zentral im module-manager verwalten
Module können trotzdem eigene moduleConfig haben - lokales überschreibt globales (NixOS merging)

## ✅ IMPLEMENTIERTE ÄNDERUNGEN:
- [x] moduleConfig zentral in module-manager/config.nix definiert
- [x] Duplikation aus system-manager/default.nix entfernt

## 🔄 AUSSTEHEND:
- [ ] system-update/config.nix: `moduleConfig.system-update.configPath` verwenden
- [ ] system-logging/config.nix: `moduleConfig.system-logging.configPath` verwenden
- [ ] Test nixos-rebuild switch
- [ ] Prüfen ob lokale moduleConfig Überschreibungen funktionieren

## 📋 AFFECTED FILES:
1. `nixos/core/management/module-manager/config.nix` - zentrale moduleConfig Definition
2. `nixos/core/management/system-manager/default.nix` - Duplikation entfernt
3. `nixos/core/management/system-manager/submodules/system-update/config.nix` - configPath aktualisieren
4. `nixos/core/management/system-manager/submodules/system-logging/config.nix` - configPath aktualisieren

## ❓ MERGING FRAGE:
**JA, Module können eigene moduleConfig haben!** Lokale _module.args werden mit globalen merged:
- `lib.mkMerge` kombiniert alle _module.args
- Lokales moduleConfig kann globale Einträge überschreiben/ergänzen
- Beispiel: system-manager kann zusätzliche configs für submodules definieren
