{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.features.terminal-ui.api;
  commandCenter = config.features.command-center;
  hostname = systemConfig.hostName;
  autoBuild = systemConfig.features.system-updater.auto-build or false;
  featureConfigPath = "/etc/nixos/configs/features-config.nix";
  
  featureList = [
    "system-logger"
    "system-checks" 
    "system-updater"
    "system-config-manager"
    "ssh-client-manager"
    "ssh-server-manager"
    "bootentry-manager"
    "homelab-manager"
    "vm-manager"
    "ai-workspace"
  ];

  # Helper to read current feature status from features-config.nix
  getFeatureStatus = feature: ''
    if [ -f "${featureConfigPath}" ]; then
      ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
        "(import ${featureConfigPath}).features.${feature} or false" 2>/dev/null || echo "false"
    else
      echo "false"
    fi
  '';

  # Helper to update features-config.nix
  updateFeaturesConfig = pkgs.writeShellScriptBin "update-features-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    local config_file="${featureConfigPath}"
    local feature="$1"
    local value="$2"
    
    # Create configs directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Read existing feature states
    declare -A features
    for f in ${toString featureList}; do
      if [ -f "$config_file" ]; then
        status=$(${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
          "(import $config_file).features.$f or false" 2>/dev/null || echo "false")
        features["$f"]="$status"
      else
        features["$f"]="false"
      fi
    done
    
    # Update the specific feature
    features["$feature"]="$value"
    
    # Write complete features-config.nix
    cat > "$config_file" <<EOF
{
  features = {
    system-logger = ''${features["system-logger"]};
    system-checks = ''${features["system-checks"]};
    system-updater = ''${features["system-updater"]};
    system-config-manager = ''${features["system-config-manager"]};
    ssh-client-manager = ''${features["ssh-client-manager"]};
    ssh-server-manager = ''${features["ssh-server-manager"]};
    bootentry-manager = ''${features["bootentry-manager"]};
    homelab-manager = ''${features["homelab-manager"]};
    vm-manager = ''${features["vm-manager"]};
    ai-workspace = ''${features["ai-workspace"]};
  };
}
EOF
  '';

  formatFeatureList = pkgs.writeScript "format-features" ''
    #!${pkgs.bash}/bin/bash
    for feature in ${toString featureList}; do
      status=$(${getFeatureStatus "$feature"})
      echo "$feature [$status]"
    done
  '';

  enableFeature = feature: ''
    ${updateFeaturesConfig}/bin/update-features-config "$feature" "true"
  '';

  disableFeature = feature: ''
    ${updateFeaturesConfig}/bin/update-features-config "$feature" "false"
  '';

  featureScript = pkgs.writeScriptBin "ncc-feature-manager" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    # Sudo check
    if [ "$EUID" -ne 0 ]; then
      ${ui.messages.error "This script must be run as root (use sudo)"}
      exit 1
    fi
    
    # Get feature selection with current status
    selected_features=$(
      ${formatFeatureList} | \
      ${pkgs.fzf}/bin/fzf --multi --prompt="Select features (TAB or SPACE to multi-select): " --bind='space:toggle' | \
      awk '{print $1}'
    )
    
    if [ -z "$selected_features" ]; then
      ${ui.messages.error "No features selected"}
      exit 1
    fi
    
    # Process each selected feature
    for feature in $selected_features; do
      current_status=$(${getFeatureStatus "$feature"})
      
      # Validate current status
      if [ "$current_status" != "true" ] && [ "$current_status" != "false" ]; then
        ${ui.messages.error "Invalid feature status for $${feature}: $${current_status}"}
        exit 1
      fi
      
      # Toggle feature
      if [ "$current_status" = "true" ]; then
        ${ui.messages.loading "Disabling $feature..."}
        ${disableFeature "$feature"}
        ${ui.messages.success "$feature disabled"}
      else
        ${ui.messages.loading "Enabling $feature..."}
        ${enableFeature "$feature"}
        ${ui.messages.success "$feature enabled"}
      fi
    done
    if sudo nixos-rebuild switch --flake /etc/nixos#${hostname}; then
      ${ui.messages.success "System successfully rebuilt!"}
    else
      ${ui.messages.error "Rebuild failed! Check logs for details."}
    fi
  '';

in {
  config = {
    environment.systemPackages = [ featureScript updateFeaturesConfig ];

    features.command-center.commands = [
      {
        name = "feature-manager";
        description = "Toggle NixOS features using fzf";
        category = "system";
        script = "${featureScript}/bin/ncc-feature-manager";
        arguments = [];
        dependencies = [ "fzf" "nix" ];
        shortHelp = "feature-manager - Toggle NixOS features";
        longHelp = ''
          Interactive feature toggler using fzf for selection.
          Features show current state in brackets.
          Use TAB or SPACE to select multiple features.
          Requires sudo privileges and triggers system rebuild.
        '';
      }
    ];
  };
}
