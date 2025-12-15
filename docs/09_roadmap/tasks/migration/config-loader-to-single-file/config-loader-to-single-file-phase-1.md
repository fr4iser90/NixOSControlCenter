# Config Loader to Single File - Phase 1: Create Consolidated Config

## 🎯 Phase Overview
**Time Estimate:** 2 hours
**Goal:** Create single system-config.nix with ALL required attribute paths

## 📋 Tasks

### 1. Collect All Configuration Templates
- [ ] Read all *-config.nix template files
- [ ] Document current configuration structure
- [ ] Identify all configurable attributes

### 2. Create Consolidated system-config.nix
- [ ] Create new system-config.nix in nixos/ root
- [ ] Include ALL expected attribute paths for modules:
  - system.* (hardware, audio, desktop, etc.)
  - core.management.* (module-manager, system-manager)
  - core.management.system-manager.submodules.* (cli-registry, cli-formatter, etc.)
- [ ] Merge all template configurations with correct nesting
- [ ] Ensure proper attribute structure for ALL modules
- [ ] Add comments for each section

### 3. Verify Configuration Structure
- [ ] Check Nix syntax validity
- [ ] Ensure ALL required attributes present for ALL modules
- [ ] Compare with current working system
- [ ] Verify all expected paths exist

## 🔍 Configuration Templates to Include

### Core System Config (from system-manager-config.nix):
```nix
{
  configVersion = "1.0";
  systemType = "desktop";
  system = { channel = "stable"; };
  hostName = "Gaming";
  timeZone = "Europe/Berlin";
  allowUnfree = true;
}
```

### Hardware Config (from hardware-config.nix):
```nix
hardware = {
  cpu = "intel";
  gpu = "amd";
  ram = { sizeGB = 8; };
};
```

### Boot Config (from boot-config.nix):
```nix
bootloader = "systemd-boot";
```

### Audio Config (from audio-config.nix):
```nix
audio = {
  enable = true;
  system = "pipewire";
};
```

### Desktop Config (from desktop-config.nix):
```nix
desktop = {
  enable = true;
  environment = "plasma";
  display = {
    manager = "sddm";
    server = "wayland";
    session = "plasma";
  };
  theme = { dark = true; };
  keyboard = { layout = "us"; options = ""; };
};
```

### Network Config (from network-config.nix):
```nix
network = {
  networkManager = { dns = "default"; };
  networking = {
    services = {};
    firewall = { trustedNetworks = []; };
  };
};
```

### Packages Config (from packages-config.nix):
```nix
# Package configurations will be handled by modules
```

### User Config (from user-config.nix):
```nix
users = {
  fr4iser = {
    autoLogin = true;
    defaultShell = "zsh";
    role = "admin";
  };
};
```

### Localization Config (from localization-config.nix):
```nix
localization = {
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "us";
  keyboardOptions = "";
};
```

## ✅ Success Criteria
- [ ] system-config.nix created with all configurations
- [ ] Valid Nix syntax
- [ ] All current configurations preserved
- [ ] Ready for flake.nix integration

## 📝 Notes
- Keep all existing configuration values
- Maintain exact same structure as templates
- Ensure configHelpers can still update hardware.ram.sizeGB automatically
