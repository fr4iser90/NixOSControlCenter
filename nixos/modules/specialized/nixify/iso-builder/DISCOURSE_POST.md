# Custom Calamares modules not appearing in NixOS Live ISO menu

## Environment

- **NixOS**: 25.11pre-git (unstable)
- **Calamares version**: 3.4.0
- **Base ISO module**: `installation-cd-graphical-calamares-plasma6.nix` (or `installation-cd-graphical-calamares-gnome.nix`)

## Problem

I'm building a custom NixOS ISO with Calamares installer that includes custom Calamares modules. The files are present on the ISO filesystem and in the squashfs, but Calamares doesn't show them in the installation menu.

**CRITICAL DISCOVERY:** Calamares is started with `--settings=/nix/store/...calamares-nixos-extensions.../settings.conf`, not `/etc/calamares/settings.conf`. This means my custom `/etc/calamares/settings.conf` is completely ignored!

## What I'm trying to do

I'm adding:
1. Custom Calamares GUI module (`nixos-control-center`) - type: `viewqml`
2. Custom Calamares job module (`nixos-control-center-job`) - type: `python`
3. Modified `settings.conf` and `modules.conf`

## Current Status

✅ **Files are on ISO filesystem:**
- `/usr/lib/calamares/modules/nixos-control-center/` exists
- `/usr/lib/calamares/modules/nixos-control-center-job/` exists
- `/etc/calamares/settings.conf` contains module in `show` sequence (but is **ignored** - see below)
- `/etc/calamares/modules.conf` registers both modules (but is **ignored** - see below)

✅ **Files are in squashfs:**
- Modules are in `nix-store.squashfs` (verified with `unsquashfs -l`)

❌ **But Calamares doesn't show them:**
- Module doesn't appear in the installation menu sidebar
- `calamares --list-modules` doesn't list them (need to verify)

**Root Cause:** Calamares is started with `--settings=/nix/store/...calamares-nixos-extensions.../settings.conf` (verified with `ps aux | grep calamares`). The store path is immutable, so my custom `/etc/calamares/settings.conf` is completely ignored. The `calamares-nixos-extensions` package has its own `settings.conf` and `modules.conf` that take precedence.

## Current Configuration

```nix
# Wrapper package that creates symlinks
calamaresModulesSymlinks = pkgs.runCommand "calamares-modules-symlinks" {} ''
  mkdir -p $out/usr/lib/calamares/modules
  ln -s ${calamaresModule} $out/usr/lib/calamares/modules/nixos-control-center
  ln -s ${calamaresJobModule} $out/usr/lib/calamares/modules/nixos-control-center-job
'';

isoImage = {
  contents = lib.mkAfter [
    {
      source = calamaresModulesSymlinks;
      target = "/usr";
    }
    {
      source = mergedCalamaresSettings;
      target = "/etc/calamares/settings.conf";
    }
    {
      source = mergedCalamaresModules;
      target = "/etc/calamares/modules.conf";
    }
  ];
  
  storeContents = [
    calamaresModule
    calamaresJobModule
    mergedCalamaresSettings
    mergedCalamaresModules
  ];
};

environment.systemPackages = [
  calamaresModule
  calamaresJobModule
  calamaresModulesSymlinks
];
```

## settings.conf

```yaml
modules-search:
  - local
  - /usr/lib/calamares/modules

sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - users
    - nixos-control-center  # <-- My custom module
    - summary
  - exec:
    - partition
    - mount
    - unpackfs
    - machineid
    - fstab
    - locale
    - keyboard
    - localecfg
    - users
    - displaymanager
    - nixos-control-center-job  # <-- My custom job module
```

## modules.conf

```yaml
nixos-control-center:
  path: /usr/lib/calamares/modules/nixos-control-center

nixos-control-center-job:
  path: /usr/lib/calamares/modules/nixos-control-center-job
```

## Module Structure

```
nixos-control-center/
├── module.desc
├── nixos-control-center.conf
├── nixos-control-center.py
└── ui.qml
```

`module.desc`:
```ini
[module]
name=nixos-control-center
prettyName=NixOS Control Center
type=viewqml
interface=qtplugin
weight=10
```

**Note:** For `viewqml` modules in Calamares 3.4, `interface=qtplugin` is required for proper GUI registration.

## Questions

1. **How does Calamares discover modules in a NixOS Live ISO?**
   - Does it read `/etc/calamares/modules.conf`?
   - Does it scan `/usr/lib/calamares/modules/`?
   - Are there specific requirements for the module structure?

2. **Are symlinks from `/usr/lib/calamares/modules/` to `/nix/store/` supported?**
   - Or do modules need to be at the exact path (not symlinks)?

3. **What's the correct way to add Calamares modules to a NixOS Live ISO?**
   - Should I use `services.calamares` to configure settings instead of copying `/etc/calamares/settings.conf`?
   - Should they be in `environment.systemPackages`?
   - Should they be copied via `isoImage.contents`?
   - How do I override the `calamares-nixos-extensions` package's `settings.conf`?

4. **How can I debug why Calamares doesn't find the modules?**
   - Are there Calamares logs I can check?
   - Can I test module discovery without rebuilding the ISO?

## Reference

I've also looked at the official NixOS Calamares module implementation:
- [calamares-nixos-extensions/src/modules/nixos/main.py](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ca/calamares-nixos-extensions/src/modules/nixos/main.py)

This shows how the standard `nixos` job module works, but I'm trying to add custom GUI modules (`viewqml` type) that appear in the installation sequence.

## Related

- [NixOS Wiki: Creating a NixOS live CD](https://nixos.wiki/wiki/Creating_a_NixOS_live_CD)
- [Calamares Documentation](https://calamares.codeberg.page/docs/documentation/)