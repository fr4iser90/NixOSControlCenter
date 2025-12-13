# Task 2: Config Path Resolver (Simplified for Your System)

## 🎯 Goal
Implement a simple but powerful config path resolver that works perfectly with your systemType approach.

## 📋 Description
Based on your current system (systemType = "desktop" vs "server" in one config), we need precedence for personal overrides.

## 🎯 Your System: Simple & Practical!

**Your current approach is PERFECT**: `systemType = "desktop"` vs `"server"` in one config!

**We only need these folders:**

### `users/fr4iser/` - Your Personal Customizations
- **What**: Your extra packages/themes beyond what systemType provides
- **Example**: You want additional gaming packages on desktop machines
- **Priority**: **Wins** over everything else!

### `system/` - System-Wide Config (NOT your systemType!)
- **What**: Hardware and system-level configs that affect ALL users
- **Example**: `system/audio-config.nix` → Audio drivers (same for everyone)
- **Example**: `system/network-config.nix` → Network settings (same for everyone)
- **Priority**: Base system configuration

**Where does your systemType go?**
Your `systemType = "desktop"` stays in **YOUR CURRENT CONFIG FILE** and gets moved to `system/packages-config.nix`. It determines what packages get installed system-wide, but users can still override in `users/fr4iser/`.

### `shared/` - OPTIONAL: What everyone really needs
- **What**: Absolutely common stuff (browser, editor, etc.)
- **Example**: `shared/packages-config.nix` → Same for desktop AND server
- **Priority**: Fallback if system/ doesn't match

## 🎯 Precedence (Super Simple):
1. `users/fr4iser/` → **Your personal preferences**
2. `system/` → **Hardware/system configs (audio, network, etc.)**
3. `shared/` → **Absolutely common base**

## 📁 Your Config Migration Example:

**BEFORE (your current system):**
```
/etc/nixos/configs/
├── packages-config.nix  # Contains systemType + all package logic
├── audio-config.nix     # Audio config
└── network-config.nix   # Network config
```

**AFTER (with new structure):**
```
/etc/nixos/configs/
├── system/
│   ├── packages-config.nix    # systemType logic stays here! (desktop vs server packages)
│   ├── audio-config.nix       # Audio config (same for all users)
│   └── network-config.nix     # Network config (same for all users)
└── users/
    └── fr4iser/
        └── packages-config.nix # ONLY your extra packages (gaming tools, etc.)
```

**Result**: Your systemType logic stays in `system/packages-config.nix` and determines base packages. You can add personal packages in `users/fr4iser/packages-config.nix` that get merged on top!

**NO hostname/environment folders needed!** Your systemType approach is much more practical! 🚀

## ✅ Acceptance Criteria
- [ ] Simple precedence: users/ → system/ → shared/
- [ ] Works with your existing systemType logic
- [ ] Personal configs override system configs
- [ ] Caching system for performance (optional)

## 🔧 Implementation
Resolver checks in order:
1. `users/${user}/${module}-config.nix` (if exists)
2. `system/${module}-config.nix` (if exists)
3. `shared/${module}-config.nix` (if exists)
4. Fallback to old flat structure

## 📅 Dependencies
- Task 1 (Module Metadata System)

## ⏱️ Estimated Duration
2-3 days
