[5 tools called]

## 📝 **STRUKTURIERTER VERSION-MIGRATION PLAN**

**Status:** ✅ Analyse komplett - 21 Dateien identifiziert

---

### **🎯 PHASE 1: OPTIONS.NIX CLEANUP (16 Dateien)**
**Ziel:** `moduleVersion` entfernen, da Version jetzt aus `_module.metadata` kommt

#### **Base Module (8 Dateien):**
- [ ] `audio/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `boot/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen  
- [ ] `desktop/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `hardware/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `localization/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `network/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `packages/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `user/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen

#### **Management Module (2 Dateien):**
- [ ] `module-manager/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `system-manager/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen

#### **Submodule (5 Dateien):**
- [ ] `system-manager/submodules/cli-formatter/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `system-manager/submodules/cli-registry/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `system-manager/submodules/system-checks/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `system-manager/submodules/system-logging/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen
- [ ] `system-manager/submodules/system-update/options.nix` - `moduleVersion = "1.0"` entfernen, `default = "1.0.0"` setzen

---

### **🎯 PHASE 2: VERSION-HELPER UPGRADE (1 Datei)**
**Ziel:** Von options.nix parsen auf metadata.version umstellen

- [ ] `system-manager/lib/version-helpers.nix` - `grep 'moduleVersion =' "$OPTIONS_FILE"` durch metadata.version ersetzen

---

### **🎯 PHASE 3: SCRIPTS UPDATE (3 Dateien)**  
**Ziel:** Version-Extraktion von options.nix auf metadata ändern

- [ ] `system-manager/scripts/check-versions.nix` - 2 Stellen (Zeile 48, 118)
- [ ] `system-manager/scripts/update-modules.nix` - 1 Stelle (Zeile 81)  
- [ ] `system-manager/submodules/system-update/handlers/system-update.nix` - 3 Stellen (Zeile 233, 245, 427)

---

### **🎯 PHASE 4: HANDLER ADJUSTMENT (1 Datei)**
**Ziel:** Version-Logic auf metadata.version anpassen

- [ ] `module-manager/handlers/module-version-check.nix` - 2 Stellen (Zeile 53, 55)

---

### **🎯 PHASE 5: TESTING & VALIDATION**
**Ziel:** Sicherstellen, dass alles funktioniert

- [ ] Alle version-related Scripts testen
- [ ] Module-Version-Checks validieren
- [ ] System stabil nach Migration

---

**📊 PROGRESS:** 0/21 Dateien erledigt
**⏱️ GESCHÄTZT:** 2-3 Stunden für komplette Migration

**Bereit für Phase 1?** 🚀

Das ist viel strukturierter als langer Text! 🎯

**Soll ich Phase 1 starten?** 🤔