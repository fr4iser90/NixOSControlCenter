# Calamares Overlay Module
# This module defines the overlay BEFORE the base ISO module is imported
# This ensures the base module uses the patched calamares-nixos-extensions

{ pkgs, lib, desktopEnv, ... }:

let
  # Path to Calamares modules
  calamaresModulePath = ./calamares-modules/nixos-control-center;
  calamaresJobModulePath = ./calamares-modules/nixos-control-center-job;
in
{
  nixpkgs.overlays = [
    (final: prev: let
      # Get base config from prev (before overlay) to avoid infinite recursion
      baseCalamaresSettings = "${prev.calamares-nixos-extensions}/etc/calamares/settings.conf";
      
      # Create module derivations INSIDE the overlay
      calamaresModuleOverlay = prev.runCommand "nixos-control-center-calamares-module" {} ''
        mkdir -p $out
        cp -r ${calamaresModulePath}/* $out/
        chmod -R u+w $out
      '';
      
      calamaresJobModuleOverlay = prev.runCommand "nixos-control-center-job-calamares-module" {} ''
        mkdir -p $out
        cp -r ${calamaresJobModulePath}/* $out/
        chmod -R u+w $out
      '';
      
      # Create mergedCalamaresModules INSIDE the overlay
      mergedCalamaresModules = prev.writeText "calamares-modules.conf" ''
---
# Calamares Modules Configuration
# Modules are loaded directly from Nix store paths

nixos-control-center:
  path: "${toString calamaresModuleOverlay}"

nixos-control-center-job:
  path: "${toString calamaresJobModuleOverlay}"
'';
      
      # Create merged settings.conf INSIDE the overlay
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

# Insert our module before "summary" in the show sequence
# Also remove standard Calamares desktop module to avoid duplicate desktop selection
if 'sequence' in config and isinstance(config['sequence'], list):
    for phase in config['sequence']:
        if isinstance(phase, dict) and 'show' in phase:
            show_list = phase['show']
            # Remove standard desktop module
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
      
      # CRITICAL: Patch calamares-nixos-extensions FIRST
      patchedCalamaresExtensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
        # Replace the settings.conf in the package with our merged one
        postInstall = (old.postInstall or "") + ''
          # Ensure etc/calamares directory exists
          mkdir -p $out/etc/calamares
          
          # Replace settings.conf with our custom merged version
          rm -f $out/etc/calamares/settings.conf
          cp ${mergedCalamaresSettings} $out/etc/calamares/settings.conf
          
          # Copy modules.conf
          cp ${mergedCalamaresModules} $out/etc/calamares/modules.conf
        '';
      });
    in {
      # CRITICAL: Patch calamares-nixos-extensions to use our merged config
      calamares-nixos-extensions = patchedCalamaresExtensions;
      
      # CRITICAL: calamares-nixos KOMPLETT neu definieren (THE NIX WAY)
      # Definition aus pkgs/by-name/ca/calamares-nixos/package.nix
      # Ersetzt calamares-nixos-extensions durch final.calamares-nixos-extensions
      calamares-nixos = prev.runCommand "calamares-wrapped"
        {
          inherit (prev.calamares) pname version meta;
          
          nativeBuildInputs = [ prev.makeWrapper ];
        }
        ''
          mkdir -p $out/bin

          cd ${prev.calamares}

          for i in *; do
            if [ "$i" == "bin" ]; then
              continue
            fi
            ln -s ${prev.calamares}/$i $out/$i
          done

          makeWrapper ${prev.lib.getExe prev.calamares} $out/bin/calamares \
            --prefix XDG_DATA_DIRS : ${final.calamares-nixos-extensions}/share \
            --prefix XDG_CONFIG_DIRS : ${final.calamares-nixos-extensions}/etc \
            --add-flag --xdg-config
        '';
      
      # Export module derivations so they can be referenced in iso-config.nix
      calamaresModule = calamaresModuleOverlay;
      calamaresJobModule = calamaresJobModuleOverlay;
    })
  ];
}