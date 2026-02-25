# Calamares Overlay Function
# Pure overlay function (not a NixOS module)
# To be applied when importing nixpkgs
#
# MINIMAL APPROACH:
# - Only patch calamares-nixos-extensions
# - calamares-nixos is NOT touched (it automatically uses patched extensions)
# - No runCommand wrapper, no sed on store paths, no string magic

{ calamaresModulePath, calamaresJobModulePath }:

final: prev: let
  # Use builtins.path to track the entire directory as input
  # This ensures Nix rebuilds when ANY file in the directory changes
  calamaresModuleSrc = builtins.path {
    path = calamaresModulePath;
    name = "nixos-control-center-calamares-module-src";
  };
  calamaresJobModuleSrc = builtins.path {
    path = calamaresJobModulePath;
    name = "nixos-control-center-job-calamares-module-src";
  };
  
  # Read module.desc directly - this forces Nix to track file content changes
  # When the file content changes, Nix will rebuild the derivation
  calamaresModuleDesc = builtins.readFile "${calamaresModulePath}/module.desc";
  calamaresJobModuleDesc = builtins.readFile "${calamaresJobModulePath}/module.desc";
  
  # Create module derivations (needed for modules.conf paths)
  # CRITICAL: Track directory as Store-Pfad AND module.desc as separate derivation
  # This ensures Nix rebuilds when:
  # 1. ANY file in the directory changes (via builtins.path)
  # 2. module.desc content changes (via writeText derivation)
  calamaresModuleOverlay = prev.runCommand "nixos-control-center-calamares-module" {
    src = calamaresModuleSrc;  # Store-Pfad des Verzeichnisses (tracks all files)
    moduleDescFile = prev.writeText "module.desc" calamaresModuleDesc;  # Separate derivation for module.desc
  } ''
    mkdir -p $out
    # Copy all files EXCEPT module.desc from Store-Pfad
    find $src -mindepth 1 -maxdepth 1 ! -name module.desc -exec cp -r {} $out/ \;
    # Copy module.desc from separate derivation (forces rebuild when content changes)
    cp $moduleDescFile $out/module.desc
  '';
  
  calamaresJobModuleOverlay = prev.runCommand "nixos-control-center-job-calamares-module" {
    src = calamaresJobModuleSrc;  # Store-Pfad des Verzeichnisses
    moduleDescFile = prev.writeText "module.desc" calamaresJobModuleDesc;  # Separate derivation
  } ''
    mkdir -p $out
    # Copy all files EXCEPT module.desc from Store-Pfad
    find $src -mindepth 1 -maxdepth 1 ! -name module.desc -exec cp -r {} $out/ \;
    # Copy module.desc from separate derivation
    cp $moduleDescFile $out/module.desc
  '';
  
  # Create modules.conf
  mergedCalamaresModules = prev.writeText "calamares-modules.conf" ''
---
# Calamares Modules Configuration
# Modules are loaded directly from Nix store paths

nixos-control-center:
  path: "${toString calamaresModuleOverlay}"

nixos-control-center-job:
  path: "${toString calamaresJobModuleOverlay}"
'';
  
  # Read base settings.conf from source (to avoid closure inflation)
  baseCalamaresSettingsContentRaw = builtins.readFile "${prev.path}/pkgs/by-name/ca/calamares-nixos-extensions/src/config/settings.conf";
in {
  # ONLY patch calamares-nixos-extensions
  # calamares-nixos will automatically use the patched version (Nix propagation)
  calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.python3Packages.pyyaml ];
    
    postInstall = (old.postInstall or "") + ''
      # Ensure etc/calamares directory exists
      mkdir -p $out/etc/calamares
      
      # Create merged settings.conf by modifying the base config
      ${prev.python3}/bin/python3 <<EOF
import yaml
import sys

# Read base config and substitute @out@ with actual $out
base_config_content = """${baseCalamaresSettingsContentRaw}""".replace("@out@", "$out")

# Parse YAML
config = yaml.safe_load(base_config_content)

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
with open("$out/etc/calamares/settings.conf", 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
EOF
      
      # Copy modules.conf
      cp ${mergedCalamaresModules} $out/etc/calamares/modules.conf
    '';
  });
  
  # CRITICAL: Redefine calamares-nixos to FORCE patched extensions
  # This ensures calamares-nixos ALWAYS uses the patched calamares-nixos-extensions
  # We use runCommand to create a wrapper that explicitly uses final.calamares-nixos-extensions
  # This prevents any transitive dependencies from pulling in the unpatched version
  calamares-nixos = prev.runCommand "calamares-nixos" {
    inherit (prev.calamares-nixos) version meta;
    nativeBuildInputs = [ prev.makeWrapper ];
    # CRITICAL: Make patched extensions a direct buildInput to force it in closure
    buildInputs = [ final.calamares-nixos-extensions ];
  } ''
    mkdir -p $out/bin
    
    # Create wrapper that uses patched extensions
    makeWrapper ${prev.lib.getExe prev.calamares} $out/bin/calamares \
      --prefix XDG_DATA_DIRS : ${final.calamares-nixos-extensions}/share \
      --prefix XDG_CONFIG_DIRS : ${final.calamares-nixos-extensions}/etc \
      --add-flag --xdg-config
    
    # Copy other files from original calamares-nixos
    for file in ${prev.calamares-nixos}/*; do
      if [ "$(basename "$file")" != "bin" ]; then
        ln -s "$file" $out/$(basename "$file")
      fi
    done
  '';
  
  # Export module derivations so they can be referenced in iso-config.nix
  calamaresModule = calamaresModuleOverlay;
  calamaresJobModule = calamaresJobModuleOverlay;
}
