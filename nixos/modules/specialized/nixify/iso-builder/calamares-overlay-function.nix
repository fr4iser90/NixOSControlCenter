# Calamares Overlay Function
# Pure overlay function (not a NixOS module)
# WORKING VERSION - Attempt 13 with default branding

{ calamaresModulePath, calamaresJobModulePath, buildTimestamp ? "cached" }:

final: prev: let
  # PackageChooser configs directory
  packageChooserConfigsPath = builtins.path {
    path = ./calamares-modules;
    name = "packagechooser-configs-src";
    filter = path: type:
      # Only include packagechooser-*.conf files
      (type == "regular" && builtins.match ".*packagechooser-.*\\.conf" path != null);
  };
  
  # Job module only (NO viewqml module!)
  calamaresJobModuleSrc = builtins.path {
    path = calamaresJobModulePath;
    name = "nixos-control-center-job-calamares-module-src";
  };
  
  # Create job module derivation
  calamaresJobModuleOverlay = prev.runCommand "nixos-control-center-job-calamares-module" {
    src = calamaresJobModuleSrc;
    inherit buildTimestamp;
  } ''
    mkdir -p $out
    cp -r $src/* $out/
  '';
  
  # Read base settings.conf from source
  baseCalamaresSettingsContentRaw = builtins.readFile "${prev.path}/pkgs/by-name/ca/calamares-nixos-extensions/src/config/settings.conf";
in {
  # Patch calamares-nixos-extensions
  calamares-nixos-extensions = prev.calamares-nixos-extensions.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.python3Packages.pyyaml ];
    inherit buildTimestamp;
    
    postInstall = (old.postInstall or "") + ''
      # Ensure etc/calamares directory exists
      mkdir -p $out/etc/calamares
      
      # Create qml directory (Calamares requires it!)
      mkdir -p $out/etc/calamares/qml
      
      # Create merged settings.conf with packagechooser
      ${prev.python3}/bin/python3 <<EOF
import yaml

# Read base config and substitute @out@
base_config_content = """${baseCalamaresSettingsContentRaw}""".replace("@out@", "$out")
config = yaml.safe_load(base_config_content)

# Set modules-search (NO non-existent paths!)
config['modules-search'] = [
    'local',
    '$out/lib/calamares/modules',
    'modules'
]

# Add our packagechooser modules - DON'T TOUCH ANYTHING ELSE!
if 'sequence' in config and isinstance(config['sequence'], list):
    for phase in config['sequence']:
        if isinstance(phase, dict) and 'show' in phase:
            show_list = phase['show']
            
            # ONLY ADD our packagechooser modules before summary
            # DON'T REMOVE ANYTHING FROM BASE-ISO!
            if 'summary' in show_list:
                summary_idx = show_list.index('summary')
                # Add our packagechooser modules
                modules_to_add = ['packagechooser@systemtype', 'packagechooser@desktop', 'packagechooser@features']
                for module in reversed(modules_to_add):
                    # Only add if not already present
                    if module not in show_list:
                        show_list.insert(summary_idx, module)
            
        # Replace nixos module with our job module
        if isinstance(phase, dict) and 'exec' in phase:
            exec_list = phase['exec']
            if 'nixos' in exec_list:
                nixos_idx = exec_list.index('nixos')
                exec_list[nixos_idx] = 'nixos-control-center-job'
            elif 'nixos-control-center-job' not in exec_list:
                exec_list.append('nixos-control-center-job')

# Use NixOS branding (not default!)
config['branding'] = 'default'

# Write config
with open("$out/etc/calamares/settings.conf", 'w') as f:
    yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True, explicit_start=False)
EOF
      
      # Copy job module to standard location (NO viewqml module!)
      mkdir -p $out/lib/calamares/modules/nixos-control-center-job
      cp -r ${calamaresJobModuleOverlay}/* $out/lib/calamares/modules/nixos-control-center-job/
      
      # Copy packagechooser configs to modules directory
      mkdir -p $out/lib/calamares/modules
      cp ${packageChooserConfigsPath}/packagechooser-systemtype.conf $out/lib/calamares/modules/ || true
      cp ${packageChooserConfigsPath}/packagechooser-desktop.conf $out/lib/calamares/modules/ || true
      cp ${packageChooserConfigsPath}/packagechooser-features.conf $out/lib/calamares/modules/ || true
      
      # CRITICAL: Copy default branding from calamares to calamares-nixos-extensions
      # Because -c flag makes Calamares look for branding under the config dir!
      mkdir -p $out/etc/calamares/branding
      cp -r ${prev.calamares}/share/calamares/branding/default $out/etc/calamares/branding/
    '';
  });
  
  # Redefine calamares-nixos with -c flag
  calamares-nixos = prev.runCommand "calamares-nixos" {
    inherit (prev.calamares-nixos) version meta;
    nativeBuildInputs = [ prev.makeWrapper ];
    buildInputs = [ final.calamares-nixos-extensions ];
  } ''
    mkdir -p $out/bin
    
    # Use -c flag to point to config directory
    # CRITICAL: Include BOTH calamares AND calamares-nixos-extensions share dirs!
    makeWrapper ${prev.lib.getExe prev.calamares} $out/bin/calamares \
      --prefix XDG_DATA_DIRS : ${prev.calamares}/share:${final.calamares-nixos-extensions}/share \
      --add-flags "-c ${final.calamares-nixos-extensions}/etc/calamares"
    
    # Copy other files from original calamares-nixos
    for file in ${prev.calamares-nixos}/*; do
      if [ "$(basename "$file")" != "bin" ]; then
        ln -s "$file" $out/$(basename "$file")
      fi
    done
  '';
  
  # Export module derivation (job only)
  calamaresJobModule = calamaresJobModuleOverlay;
}
