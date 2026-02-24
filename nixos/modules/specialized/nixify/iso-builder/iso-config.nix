# NixOS ISO Configuration with Calamares and NixOS Control Center Module
# This creates a custom NixOS ISO with Calamares installer and your custom module

{ pkgs, lib, config, desktopEnv, ... }:

let
  # Path to Calamares modules
  calamaresModulePath = ./calamares-modules/nixos-control-center;
  calamaresJobModulePath = ./calamares-modules/nixos-control-center-job;
  
  # Calamares GUI module files - packaged for ISO
  calamaresModule = pkgs.runCommand "nixos-control-center-calamares-module" {} ''
    mkdir -p $out
    cp -r ${calamaresModulePath}/* $out/
    chmod -R u+w $out
  '';
  
  # Calamares job module files - packaged for ISO
  calamaresJobModule = pkgs.runCommand "nixos-control-center-job-calamares-module" {} ''
    mkdir -p $out
    cp -r ${calamaresJobModulePath}/* $out/
    chmod -R u+w $out
  '';
  
  # Wrapper package that creates symlinks in /usr/lib/calamares/modules/
  # This makes the modules available at the expected path in the live system
  calamaresModulesSymlinks = pkgs.runCommand "calamares-modules-symlinks" {} ''
    mkdir -p $out/usr/lib/calamares/modules
    
    # Create symlinks to Calamares modules in the Nix store
    ln -s ${calamaresModule} $out/usr/lib/calamares/modules/nixos-control-center
    ln -s ${calamaresJobModule} $out/usr/lib/calamares/modules/nixos-control-center-job
  '';
  
  # NixOS Control Center repository (will be copied to ISO)
  # Get nixos/ directory (assuming we're in nixos/modules/specialized/nixify/iso-builder)
  # 4 levels up = nixos/ directory
  nixosDir = builtins.path {
    path = ../../../..;
    filter = path: type:
      type == "directory" || 
      (type == "regular" && !(builtins.match ".*\\.git.*" path != null));
  };
  
  # Get shell/ directory from repository root
  # 5 levels up = Repository-Root, then shell/
  shellDir = builtins.path {
    path = ../../../../../shell;
    filter = path: type:
      type == "directory" || 
      (type == "regular" && !(builtins.match ".*\\.git.*" path != null));
  };
  
  nixosControlCenterRepo = pkgs.runCommand "nixos-control-center-repo" {} ''
    mkdir -p $out
    # Copy nixos/ directory
    cp -r ${nixosDir}/* $out/ 2>/dev/null || true
    # Copy shell/ directory
    mkdir -p $out/shell
    cp -r ${shellDir}/* $out/shell/ 2>/dev/null || true
    # Remove build artifacts and git
    rm -rf $out/.git $out/result $out/result-* $out/*.iso 2>/dev/null || true
    chmod -R u+w $out
  '';
  
  # Merge Calamares modules.conf at BUILD TIME
  # The base config might not have a modules.conf (modules are auto-discovered)
  # We create one that registers our custom modules
  # NOTE: mergedCalamaresSettings is created in the overlay to avoid infinite recursion
  mergedCalamaresModules = pkgs.writeText "calamares-modules.conf" ''
---
# Calamares Modules Configuration
# Standard modules are auto-discovered by Calamares, we only register our custom modules

nixos-control-center:
  path: /usr/lib/calamares/modules/nixos-control-center

nixos-control-center-job:
  path: /usr/lib/calamares/modules/nixos-control-center-job
'';
  
  # Select base ISO based on desktop environment
  # desktopEnv is passed as specialArg from build-iso-*.nix scripts (required, no default)
  baseIsoModule = 
    if desktopEnv == "gnome" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix>
    else if desktopEnv == "plasma6" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix>
    else
      throw "Unknown desktop environment: ${desktopEnv}. Supported: gnome, plasma6";
in
{
  imports = [
    baseIsoModule
  ];

  # Allow unfree packages (needed for firmware, etc.)
  nixpkgs.config.allowUnfree = true;

  # ISO configuration
  # Set baseName to control the ISO filename (isoName is derived from baseName)
  # Include desktop environment in name for clarity
  image = {
    baseName = lib.mkForce "nixos-nixify-${desktopEnv}-${config.system.nixos.version}-${pkgs.stdenv.hostPlatform.system}";
  };
  
  isoImage = {
    
    # Use lib.mkAfter to append to baseIsoModule's contents
    contents = lib.mkAfter [
      {
        source = nixosControlCenterRepo;
        target = "/nixos";
      }
    # NOTE: Modules are now installed via calamaresModulesSymlinks package
    # which creates symlinks from /usr/lib/calamares/modules/ to Store paths
    # This ensures they're available in the live system runtime
    # We still copy them via contents for ISO filesystem, but the symlinks
    # make them accessible at runtime
      {
      source = calamaresModulesSymlinks;
      target = "/usr";
    }
      # NOTE: settings.conf is now patched in calamares-nixos-extensions via overlay
      # We don't need to copy it separately anymore
      {
        source = mergedCalamaresModules;
        target = "/etc/calamares/modules.conf";
      }
    ];
    
    # CRITICAL: storeContents OHNE lib.mkAfter - direkt setzen
    # lib.mkAfter funktioniert nicht, weil storeContents zu früh konsumiert wird
    # Die ISO module definiert storeContents bereits, und mkAfter wird nicht richtig angewendet
    # Lösung: Direkt überschreiben, nicht mit mkAfter
    # Community-Lösung: storeContents direkt setzen (ohne mkAfter)
    storeContents = [
      nixosControlCenterRepo
      calamaresModule
      calamaresJobModule
      mergedCalamaresModules
    ];
    
    # Make repository accessible from installer
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
  
  # CRITICAL: Falls storeContents allein nicht funktioniert,
  # zwinge die ISO-Derivation, direkt von unseren Derivationen abzuhängen
  # Dies macht die Derivationen zu direkten Dependencies der ISO
  # Community-Lösung: overrideAttrs auf der Derivation selbst
  # WICHTIG: Wir müssen dies NACH der Definition von isoImage machen,
  # daher verwenden wir lib.mkOverride mit hoher Priorität
  system.build.isoImage = lib.mkOverride 1000 (
    (config.system.build.isoImage).overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [
        nixosControlCenterRepo
        calamaresModule
        calamaresJobModule
        mergedCalamaresModules
      ];
    })
  );

  # System packages needed for Calamares module
  # CRITICAL: Also include custom directory derivations to force them as dependencies
  # Note: Files (mergedCalamaresSettings, mergedCalamaresModules) cannot be in systemPackages
  # They are already referenced in isoImage.contents and will be built as dependencies
  environment.systemPackages = with pkgs; lib.mkAfter [
    # Python dependencies for Calamares module
    python3
    python3Packages.pyqt5
    
    # Tools for hardware checks
    pciutils  # lspci for GPU detection
    usbutils  # lsusb
    dmidecode  # Hardware info
    
    # NixOS Control Center dependencies
    bash
    git
    nix
    
    # CRITICAL: Force evaluation of custom directory derivations by adding them to systemPackages
    # This ensures they are built and available, even though they're also in isoImage.contents
    # The ISO builder will copy them from the store paths referenced in contents
    # Note: Only directories can be in systemPackages, not files
    nixosControlCenterRepo
    calamaresModule
    calamaresJobModule
    # Wrapper package that creates symlinks - makes modules available at expected path
    calamaresModulesSymlinks
  ];

  # Enable services needed for hardware detection
  services.udev.enable = true;
  hardware.enableAllFirmware = true;
  
  # CRITICAL: Patch calamares-nixos-extensions to use our custom settings.conf
  # Calamares is started with --settings=/nix/store/...calamares-nixos-extensions.../settings.conf
  # We need to override the package to use our merged settings.conf instead
  # IMPORTANT: mergedCalamaresSettings must be created in the overlay to avoid infinite recursion
  # because it needs prev.calamares-nixos-extensions, not pkgs.calamares-nixos-extensions
  nixpkgs.overlays = [
    (final: prev: let
      # Get base config from prev (before overlay) to avoid infinite recursion
      baseCalamaresSettings = "${prev.calamares-nixos-extensions}/etc/calamares/settings.conf";
      
      # Create merged settings.conf INSIDE the overlay using prev.calamares-nixos-extensions
      mergedCalamaresSettings = prev.runCommand "calamares-settings-merged" {
        nativeBuildInputs = [ prev.python3Packages.pyyaml ];
      } ''
        # Read base config
        BASE_CONFIG="${baseCalamaresSettings}"
        
        # Use Python to merge YAML and insert our module
        ${prev.python3}/bin/python3 <<EOF
import yaml
import sys

# Read base config
with open("$BASE_CONFIG", 'r') as f:
    config = yaml.safe_load(f)

# Add /usr/lib/calamares/modules to modules-search if not present
if 'modules-search' in config:
    if isinstance(config['modules-search'], list):
        if '/usr/lib/calamares/modules' not in config['modules-search']:
            config['modules-search'].append('/usr/lib/calamares/modules')
    else:
        config['modules-search'] = [config['modules-search'], '/usr/lib/calamares/modules']
else:
    config['modules-search'] = ['local', '/usr/lib/calamares/modules']

# Insert our module before "summary" in the show sequence
# Also remove standard Calamares desktop module to avoid duplicate desktop selection
if 'sequence' in config and isinstance(config['sequence'], list):
    for phase in config['sequence']:
        if isinstance(phase, dict) and 'show' in phase:
            show_list = phase['show']
            # Remove standard desktop module (has desktop selection - shown in screenshot)
            if 'desktop' in show_list:
                show_list.remove('desktop')
            # Insert our module before summary
            if 'summary' in show_list:
                summary_idx = show_list.index('summary')
                if 'nixos-control-center' not in show_list:
                    show_list.insert(summary_idx, 'nixos-control-center')
            elif 'nixos-control-center' not in show_list:
                show_list.append('nixos-control-center')
        
        if isinstance(phase, dict) and 'exec' in phase:
            exec_list = phase['exec']
            if 'nixos' in exec_list:
                # Replace Calamares nixos module with our flake-based installation
                nixos_idx = exec_list.index('nixos')
                exec_list[nixos_idx] = 'nixos-control-center-job'
            elif 'nixos-control-center-job' not in exec_list:
                exec_list.append('nixos-control-center-job')

# Write merged config
with open("$out", 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
EOF
      '';
    in {
      calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
        # Replace the settings.conf in the package with our merged one
        postInstall = (old.postInstall or "") + ''
          # Replace settings.conf with our custom merged version
          rm -f $out/etc/calamares/settings.conf
          cp ${mergedCalamaresSettings} $out/etc/calamares/settings.conf
          
          # Also replace modules.conf if it exists
          if [ -f $out/etc/calamares/modules.conf ]; then
            rm -f $out/etc/calamares/modules.conf
          fi
          cp ${mergedCalamaresModules} $out/etc/calamares/modules.conf
        '';
      });
    })
  ];
  
}
