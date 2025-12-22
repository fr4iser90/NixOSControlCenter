{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  # Import the handler for business logic
  handler = import ./handlers/module-manager.nix { inherit config lib pkgs systemConfig getModuleConfig; };

  ui = let apiPath = getModuleApi "cli-formatter"; in
       if apiPath == "" then {} else lib.attrByPath (lib.splitString "." apiPath) {} config;  # Generic API access
  hostname = lib.attrByPath ["hostName"] "nixos" (getModuleConfig "network");  # Generic config access

  # 🎯 COMMAND REGISTRATION: Per MODULE_TEMPLATE in commands.nix!

  # Script to update module-manager-config.nix
  updateModuleConfig = pkgs.writeShellScriptBin "update-module-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    module_name="$1"
    enable_value="$2"
    config_file="/etc/nixos/configs/module-manager-config.nix"

    # Create directory if needed
    mkdir -p "$(dirname "$config_file")"

    # If config doesn't exist, create from template
    if [ ! -f "$config_file" ]; then
      cp ${../../../core/management/module-manager/module-manager-config.nix} "$config_file"
    fi

    # Read current config
    current_config=$(cat "$config_file")

    # Parse module name (modules.ssh-client-manager → modules / ssh-client-manager)
    if [[ "$module_name" == *"."* ]]; then
      category="modules"
      module_short="$module_name"
    else
      category="core"
      module_short="$module_name"
    fi

    # Update the config using nix
    ${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
      let
        config = $current_config;
        updated = config // {
          $category = (config.$category or {}) // {
            $module_short = $enable_value;
          };
        };
      in builtins.toJSON updated
    " | ${pkgs.jq}/bin/jq . > "$config_file.tmp"

    mv "$config_file.tmp" "$config_file"
    echo "Updated $module_name: $enable_value"
  '';

  moduleManagerScript = pkgs.writeScriptBin "ncc-module-manager" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Sudo check
    if [ "$EUID" -ne 0 ]; then
      ${ui.messages.error "This script must be run as root (use sudo)"}
      exit 1
    fi

    # Header
    ${ui.text.header "NixOS Module Manager"}
    ${ui.text.normal "Available modules from your current configuration:"}
    ${ui.text.newline}

    # Show current config status
    echo "Current module status:"
    echo "======================"

    # Read current config
    config_file="/etc/nixos/configs/module-manager-config.nix"
    if [ -f "$config_file" ]; then
      echo "Core modules:"
      ${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
        let config = import $config_file;
        in builtins.concatStringsSep \"\\n\" (
          builtins.attrNames (config.core or {})
        )
      " 2>/dev/null | while read module; do
        status=$(${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
          let config = import $config_file;
          in config.core.\"$module\" or false
        " 2>/dev/null)
        printf "  %-25s [%s]\\n" "$module" "$(if [ "$status" = "true" ]; then echo "✓"; else echo "○"; fi)"
      done

      echo ""
      echo "Feature modules:"
      ${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
        let config = import $config_file;
        in builtins.concatStringsSep \"\\n\" (
          builtins.attrNames (config.modules or {})
        )
      " 2>/dev/null | while read module; do
        status=$(${pkgs.nix}/bin/nix-instantiate --eval --strict -E "
          let config = import $config_file;
          in config.modules.\"$module\" or false
        " 2>/dev/null)
        printf "  %-25s [%s]\\n" "$module" "$(if [ "$status" = "true" ]; then echo "✓"; else echo "○"; fi)"
      done
    else
      echo "No config file found - using defaults"
    fi

    echo ""
    echo "Module selection:"
    echo "================="

    # Module selection with fzf
    selected_modules=$(
      ${handler.formatModuleList} | \
      ${pkgs.fzf}/bin/fzf --multi --prompt="Select modules (TAB to multi-select): " | \
      awk '{print $1}'
    )

    if [ -z "$selected_modules" ]; then
      ${ui.messages.error "No modules selected"}
      exit 1
    fi

    # Process each selected module
    for module_name in $selected_modules; do
      current_status=$(${handler.getModuleStatus "$module_name"})

      # Validate status
      if [ "$current_status" != "true" ] && [ "$current_status" != "false" ]; then
        ${ui.messages.error "Invalid module status for $module_name: $current_status"}
        exit 1
      fi

      # Toggle module
      if [ "$current_status" = "true" ]; then
        ${ui.messages.loading "Disabling $module_name..."}
        ${updateModuleConfig}/bin/update-module-config "$module_name" false
        ${ui.messages.success "$module_name disabled"}
      else
        ${ui.messages.loading "Enabling $module_name..."}
        ${updateModuleConfig}/bin/update-module-config "$module_name" true
        ${ui.messages.success "$module_name enabled"}
      fi
    done

    # System rebuild
    ${ui.messages.loading "Rebuilding system..."}
    if sudo nixos-rebuild switch --flake /etc/nixos#${hostname} 2>&1; then
      ${ui.messages.success "System successfully rebuilt!"}
    else
      EXIT_CODE=$?
      # Check if build was successful but switch failed
      if [ -f /nix/var/nix/profiles/system ]; then
        CURRENT_GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)
        if [ -n "$CURRENT_GEN" ]; then
          ${ui.messages.warning "Build completed, but switch encountered issues (exit code: $EXIT_CODE)"}
          ${ui.messages.info "Current generation: $CURRENT_GEN"}
          ${ui.messages.info "Some services may have failed to reload - this is often harmless."}
        else
          ${ui.messages.error "Rebuild failed! Check logs for details."}
        fi
      else
        ${ui.messages.error "Rebuild failed! Check logs for details."}
      fi
    fi
  '';

in {
  # 🎯 COMMAND REGISTRATION: In commands.nix per MODULE_TEMPLATE!
  core.management.system-manager.submodules.cli-registry.commands = [
    {
      name = "module-manager";
      description = "Toggle all NixOS modules using fzf (dynamic discovery)";
      category = "system";
      script = "${moduleManagerScript}/bin/ncc-module-manager";
      arguments = [];
      dependencies = [ "fzf" "nix" ];
      shortHelp = "module-manager - Toggle NixOS modules";
      longHelp = ''
        Interactive module toggler using fzf for selection.
        Automatically discovers ALL available modules from your current systemConfig.
        Shows system, management, and optional modules with current status.
        Use TAB or SPACE to select multiple modules.
        Requires sudo privileges and triggers system rebuild.

        Categories:
        • system.* - Core OS functionality (usually enabled)
        • management.* - System management tools (usually enabled)
        • modules.* - Optional user modules (usually disabled)

        This tool dynamically reads your current NixOS configuration and shows all toggleable modules.
      '';
    }
  ];
}
