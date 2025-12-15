# Config Loader to Single File - Phase 3: Test & Verify

## 🎯 Phase Overview
**Time Estimate:** 1 hour
**Goal:** Test system rebuild and verify ALL functionality

## 📋 Tasks

### 1. Test System Rebuild
- [ ] Run `sudo nixos-rebuild build` to check for syntax errors
- [ ] Fix any configuration errors
- [ ] Ensure all modules load correctly

### 2. Verify Configuration Loading
- [ ] Check that systemConfig is properly loaded with ALL required paths
- [ ] Verify ALL modules can read their expected config attributes:
  - System modules read from systemConfig.system.*
  - Management modules read from systemConfig.core.management.*
  - CLI modules read from systemConfig.core.management.system-manager.submodules.*
- [ ] Confirm configHelpers still work for automatic hardware detection
- [ ] Verify no module fails to load due to missing config paths

### 3. Test Full System Build
- [ ] Run complete `sudo nixos-rebuild switch`
- [ ] Monitor for any errors during build from ALL modules
- [ ] Verify system boots correctly with all configurations applied

### 4. Functional Verification
- [ ] Test ALL CLI tools work:
  - system-manager status
  - system-manager enable-desktop
  - system-manager check-versions
  - All CLI formatting and commands
- [ ] Verify hardware detection still works (RAM, CPU, GPU auto-detection)
- [ ] Check that ALL services start properly
- [ ] Confirm ALL user configurations apply
- [ ] Test ALL system modules (audio, desktop, network, etc.)

## 🔍 Test Commands

### Basic Build Test:
```bash
# Test build without applying
sudo nixos-rebuild build --flake /home/fr4iser/Documents/Git/NixOSControlCenter/nixos#Gaming
```

### Full System Test:
```bash
# Apply configuration
sudo nixos-rebuild switch --flake /home/fr4iser/Documents/Git/NixOSControlCenter/nixos#Gaming
```

### CLI Tools Test:
```bash
# Test system-manager commands
system-manager status
system-manager enable-desktop
```

### Hardware Detection Test:
```bash
# Check if RAM detection still works
cat /etc/nixos/system-config.nix | grep sizeGB
```

## ✅ Success Criteria
- [ ] System builds successfully
- [ ] No configuration errors
- [ ] CLI tools work
- [ ] Hardware detection functional
- [ ] All services start correctly

## 📝 Notes
- If build fails, check system-config.nix syntax
- If CLI tools don't work, verify management modules are still loaded
- If hardware detection fails, check configHelpers functionality
