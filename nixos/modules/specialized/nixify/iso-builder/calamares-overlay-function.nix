# Calamares Overlay Function
# Pure overlay function (not a NixOS module)
# To be applied when importing nixpkgs
#
# MINIMAL APPROACH:
# - Only patch calamares-nixos-extensions
# - calamares-nixos is NOT touched (it automatically uses patched extensions)
# - No runCommand wrapper, no sed on store paths, no string magic
#
# FORCE REBUILD: 2026-02-26-11:30 - Added debug output and error handling

{ calamaresModulePath, calamaresJobModulePath, buildTimestamp ? "cached" }:

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
  # 3. buildTimestamp changes (forces rebuild with --force-rebuild)
  calamaresModuleOverlay = prev.runCommand "nixos-control-center-calamares-module" {
    src = calamaresModuleSrc;  # Store-Pfad des Verzeichnisses (tracks all files)
    moduleDescFile = prev.writeText "module.desc" calamaresModuleDesc;  # Separate derivation for module.desc
    inherit buildTimestamp;  # CRITICAL: Force rebuild when timestamp changes
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
    inherit buildTimestamp;  # CRITICAL: Force rebuild when timestamp changes
  } ''
    mkdir -p $out
    # Copy all files EXCEPT module.desc from Store-Pfad
    find $src -mindepth 1 -maxdepth 1 ! -name module.desc -exec cp -r {} $out/ \;
    # Copy module.desc from separate derivation
    cp $moduleDescFile $out/module.desc
  '';
  
  # CRITICAL: Create a parent directory containing both modules
  # Calamares modules-search expects directories CONTAINING modules, not the modules themselves
  # Structure: custom-calamares-modules/
  #              ├── nixos-control-center/
  #              └── nixos-control-center-job/
  customCalamaresModulesDir = prev.runCommand "custom-calamares-modules" {} ''
    mkdir -p $out
    ln -s ${calamaresModuleOverlay} $out/nixos-control-center
    ln -s ${calamaresJobModuleOverlay} $out/nixos-control-center-job
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
    
    # FORCE REBUILD: Use buildTimestamp parameter to control caching
    # When buildTimestamp changes, Nix will rebuild this derivation
    # "cached" = use cache, current timestamp = force rebuild
    inherit buildTimestamp;
    
    postInstall = (old.postInstall or "") + ''
      # Debug: Show build timestamp
      echo "DEBUG: Build timestamp: ${buildTimestamp}"
      # Debug: Show build progress
      echo "================================================"
      echo "DEBUG: Patching calamares-nixos-extensions"
      echo "DEBUG: Output directory: $out"
      echo "================================================"
      
      # Ensure etc/calamares directory exists
      mkdir -p $out/etc/calamares
      echo "DEBUG: Created $out/etc/calamares directory"
      
      # Create merged settings.conf by modifying the base config
      echo "DEBUG: Creating merged settings.conf..."
      ${prev.python3}/bin/python3 <<EOF
import yaml
import sys

# Read base config and substitute @out@ with actual $out
base_config_content = """${baseCalamaresSettingsContentRaw}""".replace("@out@", "$out")

# Parse YAML
config = yaml.safe_load(base_config_content)

# Ensure modules-search includes custom module locations
if 'modules-search' not in config:
    config['modules-search'] = []

# Add standard paths first
for path in ['local', '$out/lib/calamares/modules', 'modules']:
    if path not in config['modules-search']:
        config['modules-search'].append(path)

# ADD our custom modules parent directory - THIS IS THE FIX!
# Calamares searches WITHIN this directory for modules (not the modules themselves)
# This directory contains: nixos-control-center/ and nixos-control-center-job/
config['modules-search'].append('${toString customCalamaresModulesDir}')

# Insert our module before "summary" in the show sequence
# CRITICAL: Only modify the FIRST show: sequence (not the finished sequence)
# Also remove standard Calamares desktop module to avoid duplicate desktop selection
if 'sequence' in config and isinstance(config['sequence'], list):
    modified_first_show = False
    for phase in config['sequence']:
        if isinstance(phase, dict) and 'show' in phase and not modified_first_show:
            show_list = phase['show']
            # Remove standard desktop module
            if 'desktop' in show_list:
                show_list.remove('desktop')
            # Insert our module before summary (only in FIRST show sequence)
            if 'summary' in show_list:
                summary_idx = show_list.index('summary')
                if 'nixos-control-center' not in show_list:
                    show_list.insert(summary_idx, 'nixos-control-center')
                modified_first_show = True
            elif 'nixos-control-center' not in show_list:
                show_list.append('nixos-control-center')
                modified_first_show = True
        
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

print("DEBUG: settings.conf created successfully")
EOF
      
      echo "DEBUG: Verifying settings.conf..."
      if [ -f "$out/etc/calamares/settings.conf" ]; then
        echo "DEBUG: ✓ settings.conf exists"
        echo "DEBUG: modules-search configuration:"
        grep -A 3 "modules-search:" "$out/etc/calamares/settings.conf" || echo "WARNING: modules-search not found"
      else
        echo "ERROR: settings.conf was not created!"
        exit 1
      fi
      
      # NOTE: modules.conf with path: entries is NOT compatible with modules-search!
      # Calamares will find modules via modules-search directories, not via modules.conf path:
      # DO NOT copy modules.conf - modules are discovered via modules-search paths
      echo "DEBUG: Skipping modules.conf (modules discovered via modules-search)"
      
      # Create modules config directory
      mkdir -p $out/etc/calamares/modules
      
      # Copy module config files to /etc/calamares/modules/
      # CRITICAL: Config files must be in /etc/calamares/modules/, NOT in module directory!
      # Otherwise Calamares treats them as instance configs and creates @modulename
      cat > $out/etc/calamares/modules/nixos-control-center.yaml <<'NIXOSCONFIG'
---
# NixOS Control Center Calamares Module Configuration

# Path to NixOS Control Center repository on ISO
repoPath: "/mnt/cdrom/nixos"

# Path to shell.nix installer
shellNixPath: "/etc/nixos/shell.nix"

# Path to scripts directory
scriptsPath: "/etc/nixos/shell/scripts"

# Enable hardware checks
enableHardwareChecks: true
NIXOSCONFIG
      
      echo "DEBUG: Created /etc/calamares/modules/nixos-control-center.yaml"
      
      # Verify final structure
      echo "================================================"
      echo "DEBUG: Final /etc/calamares structure:"
      ls -la $out/etc/calamares/
      echo "DEBUG: /etc/calamares/modules/ structure:"
      ls -la $out/etc/calamares/modules/
      echo "================================================"
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
