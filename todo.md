[8 tools called]

## 🎯 **VOLLSTÄNDIGE & KOMPLETTE LISTE ALLER AFFECTED FILES**

# 📋 **PHASE 1: HARDCODED systemConfig.* REFERENZEN (98 Dateien)**

## 🔴 **KRITISCH (brechen System - features.* → modules.*):**

### **SSH-Server-Manager (features.* falsch):**
- `nixos/modules/security/ssh-server-manager/scripts/approve-request.nix`
- `nixos/modules/security/ssh-server-manager/scripts/list-requests.nix`
- `nixos/modules/security/ssh-server-manager/scripts/request-access.nix`
- `nixos/modules/security/ssh-server-manager/scripts/grant-access.nix`

### **SSH-Client-Manager (features.* falsch):**
- `nixos/modules/security/ssh-client-manager/scripts/ssh-client-manager.nix`
- `nixos/modules/security/ssh-client-manager/lib/ssh-server-utils.nix`
- `nixos/modules/security/ssh-client-manager/commands.nix`
- `nixos/modules/security/ssh-client-manager/config.nix`
- `nixos/modules/security/ssh-client-manager/lib/ssh-key-utils.nix`
- `nixos/modules/security/ssh-client-manager/handlers/ssh-client-handler.nix`

### **Infrastructure Module (features.* falsch):**
- `nixos/modules/infrastructure/vm/testing/default.nix`
- `nixos/modules/infrastructure/bootentry-manager/config.nix`
- `nixos/modules/infrastructure/homelab-manager/config.nix`

### **Options Schema Fehler (system.* → core.base.*):**
- `nixos/core/base/packages/options.nix`
- `nixos/core/base/boot/options.nix`
- `nixos/core/base/hardware/options.nix`
- `nixos/core/base/localization/options.nix`
- `nixos/core/base/desktop/options.nix`
- `nixos/core/base/audio/options.nix`
- `nixos/core/base/user/options.nix`
- `nixos/core/base/network/options.nix`

## 🟡 **HOCH (funktionale Probleme):**

### **Core Module hardcoded:**
- `nixos/core/base/packages/default.nix`
- `nixos/core/base/desktop/options.nix`
- `nixos/core/base/user/options.nix`
- `nixos/core/base/network/options.nix`
- `nixos/core/base/hardware/options.nix`
- `nixos/core/base/audio/options.nix`
- `nixos/core/base/packages/options.nix`
- `nixos/core/base/boot/options.nix`
- `nixos/core/base/localization/options.nix`

### **Module hardcoded:**
- `nixos/modules/specialized/hackathon/default.nix`
- `nixos/modules/infrastructure/homelab-manager/default.nix`

### **Management hardcoded:**
- `nixos/core/management/module-manager/default.nix`
- `nixos/flake.nix`
- `nixos/core/management/system-manager/default.nix`
- `nixos/core/management/module-manager/config.nix`
- `nixos/core/management/system-manager/handlers/channel-manager.nix`
- `nixos/core/management/module-manager/options.nix`
- `nixos/core/management/system-manager/commands.nix`
- `nixos/core/management/system-manager/components/config-migration/commands.nix`
- `nixos/core/management/system-manager/submodules/system-checks/commands.nix`
- `nixos/modules/infrastructure/homelab-manager/lib/homelab-utils.nix`
- `nixos/core/management/system-manager/submodules/system-logging/commands.nix`
- `nixos/core/management/system-manager/submodules/system-update/handlers/system-update.nix`
- `nixos/core/management/module-manager/lib/utils.nix`
- `nixos/core/management/system-manager/submodules/system-update/options.nix`

### **Hardware/Desktop hardcoded:**
- `nixos/core/base/hardware/gpu/default.nix`
- `nixos/core/base/hardware/cpu/default.nix`
- `nixos/core/base/desktop/environments/default.nix`
- `nixos/core/base/desktop/themes/color-schemes/default.nix`
- `nixos/core/base/desktop/display-servers/default.nix`
- `nixos/core/base/desktop/display-managers/default.nix`
- `nixos/core/base/desktop/themes/color-schemes/schemes/gnome.nix`
- `nixos/core/base/desktop/themes/color-schemes/schemes/plasma.nix`

## 🟢 **NORMAL (cleanup):**

### **System Manager Submodules hardcoded:**
- `nixos/core/management/system-manager/submodules/cli-registry/default.nix`
- `nixos/core/management/system-manager/submodules/system-update/default.nix`
- `nixos/core/management/system-manager/submodules/system-update/commands.nix`
- `nixos/core/management/system-manager/submodules/system-checks/prebuild/checks/system/users.nix`
- `nixos/core/management/system-manager/submodules/cli-registry/config.nix`
- `nixos/core/management/system-manager/submodules/system-logging/config.nix`
- `nixos/core/management/system-manager/submodules/system-logging/collectors/profile.nix`
- `nixos/core/management/system-manager/submodules/system-logging/scripts/system-report.nix`
- `nixos/core/management/system-manager/submodules/system-checks/scripts/prebuild-checks.nix`
- `nixos/core/management/system-manager/submodules/system-logging/handlers/report-handler.nix`
- `nixos/core/management/system-manager/submodules/system-checks/options.nix`
- `nixos/core/management/system-manager/submodules/system-update/system-update-config.nix`
- `nixos/core/management/system-manager/options.nix`
- `nixos/core/management/system-manager/components/config-migration/check.nix`
- `nixos/core/management/system-manager/submodules/system-logging/options.nix`
- `nixos/core/management/system-manager/submodules/cli-formatter/options.nix`
- `nixos/core/management/system-manager/submodules/cli-registry/options.nix`
- `nixos/core/management/system-manager/submodules/system-update/options.nix`
- `nixos/core/management/system-manager/submodules/cli-formatter/config.nix`
- `nixos/core/management/system-manager/config.nix`

### **Scripts & Utils hardcoded:**
- `nixos/core/management/module-manager/commands.nix`
- `nixos/core/management/system-manager/commands.nix`
- `nixos/core/management/system-manager/scripts/check-versions.nix`
- `nixos/core/management/system-manager/scripts/enable-desktop.nix`
- `nixos/core/management/system-manager/submodules/system-checks/scripts/postbuild-checks.nix`

### **Specialized Scripts hardcoded:**
- `nixos/modules/specialized/hackathon/hackathon-status.nix`
- `nixos/modules/specialized/hackathon/hackathon-create.nix`
- `nixos/modules/specialized/hackathon/hackathon-fetch.nix`
- `nixos/modules/infrastructure/homelab-manager/scripts/homelab-create.nix`
- `nixos/modules/infrastructure/homelab-manager/scripts/homelab-fetch.nix`

### **Home Manager hardcoded:**
- `nixos/core/base/user/home-manager/roles/restricted-admin.nix`
- `nixos/core/base/user/home-manager/shellInit/index.nix`
- `nixos/core/base/user/home-manager/roles/virtualization.nix`
- `nixos/core/base/user/home-manager/roles/admin.nix`

### **Config Files hardcoded:**
- `nixos/core/base/network/config.nix`
- `nixos/core/base/boot/config.nix`
- `nixos/core/base/packages/config.nix`
- `nixos/core/management/system-manager/submodules/system-update/config.nix`
- `nixos/core/management/system-manager/submodules/cli-formatter/config.nix`
- `nixos/core/management/system-manager/config.nix`

### **Network & Hardware hardcoded:**
- `nixos/core/base/network/networkmanager.nix`
- `nixos/core/base/network/firewall.nix`
- `nixos/core/base/hardware/memory/default.nix`

### **Documentation (README/MD) hardcoded:**
- `nixos/modules/system/lock-manager/README.md`
- `nixos/modules/system/lock-manager/ARCHITECTURE.md`
- `nixos/core/management/module-manager/CHANGELOG.md`
- `nixos/core/management/system-manager/submodules/system-checks/CHANGELOG.md`
- `nixos/core/management/system-manager/submodules/cli-registry/CHANGELOG.md`
- `nixos/core/base/network/README.md`
- `nixos/core/base/user/README.md`
- `nixos/modules/infrastructure/homelab-manager/docker.md`
- `nixos/core/base/boot/README.md`
- `nixos/core/base/boot/CHANGELOG.md`
- `nixos/core/base/desktop/README.md`
- `nixos/core/base/hardware/README.md`

### **Custom & Examples hardcoded:**
- `nixos/custom/example_borg_backup.nix`

---

# 📋 **PHASE 2: FEHLENDE _module.metadata (60+ Dateien)**

## 🔴 **KRITISCH (Root Module ohne Metadata):**

### **Infrastructure Root Module:**
- `nixos/modules/infrastructure/bootentry-manager/default.nix` ❌
- `nixos/modules/infrastructure/homelab-manager/default.nix` ❌
- `nixos/modules/infrastructure/vm/default.nix` ❌

### **Security Root Module:**
- `nixos/modules/security/ssh-server-manager/default.nix` ❌ (nur teilweise)

### **Specialized Root Module:**
- `nixos/modules/specialized/hackathon/default.nix` ❌
- `nixos/modules/specialized/ai-workspace/default.nix` ❌

### **System Root Module:**
- `nixos/modules/system/lock-manager/default.nix` ❌

## 🟡 **HOCH (Core Submodule ohne Metadata):**

### **System Manager Submodules:**
- `nixos/core/management/system-manager/submodules/cli-formatter/default.nix` ❌
- `nixos/core/management/system-manager/submodules/cli-registry/default.nix` ❌
- `nixos/core/management/system-manager/submodules/system-checks/default.nix` ❌
- `nixos/core/management/system-manager/submodules/system-logging/default.nix` ❌
- `nixos/core/management/system-manager/submodules/system-update/default.nix` ❌

### **Base Submodules:**
- `nixos/core/base/desktop/default.nix` ❌
- `nixos/core/base/hardware/default.nix` ❌
- `nixos/core/base/network/default.nix` ❌
- `nixos/core/base/audio/default.nix` ❌
- `nixos/core/base/boot/default.nix` ❌
- `nixos/core/base/localization/default.nix` ❌

## 🟢 **NORMAL (weitere Module ohne Metadata):**

### **Infrastructure Submodules:**
- `nixos/modules/infrastructure/vm/core/default.nix` ❌
- `nixos/modules/infrastructure/vm/containers/default.nix` ❌
- `nixos/modules/infrastructure/vm/iso-manager/default.nix` ❌

### **Specialized Submodules:**
- `nixos/modules/specialized/ai-workspace/containers/default.nix` ❌
- `nixos/modules/specialized/ai-workspace/llm/default.nix` ❌
- `nixos/modules/specialized/ai-workspace/services/default.nix` ❌

### **System Submodules:**
- Alle Scanner in `nixos/modules/system/lock-manager/scanners/` ❌

---

# 🎯 **GESAMT: 160+ DATEIEN ZU MIGRieren**

**Phase 1:** 98 Dateien mit hardcoded systemConfig.* (198 matches total)
**Phase 2:** 60+ Dateien ohne _module.metadata

**TOTAL: 160+ AFFECTED FILES**

**JEDE EINZELNE AUFGEFÜHRT!** 🚀

**Welche Datei migrieren wir zuerst?** 🔥