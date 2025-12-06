# TEMPLATE: How to register commands in command-center correctly
# Use this template when creating new features that register commands
#
# PROBLEM: Scripts use cfg values in strings, but cfg can be null when feature is disabled
# SOLUTION: Use cfgWithDefaults in let block, register commands in mkIf cfg.enable

{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.my-feature;
  ui = config.features.terminal-ui.api or (
    # Fallback if terminal-ui not available
    let
      colors = import ../terminal-ui/colors.nix;
      core = import ../terminal-ui/core { inherit lib colors; config = {}; };
      status = import ../terminal-ui/status { inherit lib colors; config = {}; };
    in {
      inherit colors;
      inherit (core) text layout;
      inherit (status) messages badges;
    }
  );
  
  # CRITICAL: Create cfgWithDefaults to avoid null errors
  # This ensures cfg values are never null, even when feature is disabled
  cfgWithDefaults = lib.recursiveUpdate {
    # Define ALL cfg options with default values here
    option1 = "default-value";
    option2 = {
      subOption1 = false;
      subOption2 = null;
    };
    # ... all other options with defaults
  } (cfg or {});
  
  # Define scripts in let block (always evaluated)
  # Use cfgWithDefaults instead of cfg to avoid null errors
  myScript = pkgs.writeShellScriptBin "ncc-my-command-main" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Use cfgWithDefaults, NOT cfg directly
    VALUE="${cfgWithDefaults.option1}"
    
    ${ui.messages.info "Starting..."}
    # ... script logic
    ${ui.messages.success "Done!"}
  '';
  
  # Other scripts...
  anotherScript = pkgs.writeShellScriptBin "ncc-another-command-main" ''
    #!${pkgs.bash}/bin/bash
    # ... script content using cfgWithDefaults
  '';

in {
  options.features.my-feature = {
    enable = mkEnableOption "my feature";
    
    option1 = mkOption {
      type = types.str;
      default = "default-value";
      description = "Option 1";
    };
    
    option2 = {
      subOption1 = mkOption {
        type = types.bool;
        default = false;
        description = "Sub option 1";
      };
      
      subOption2 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Sub option 2";
      };
    };
  };

  config = mkMerge [
    # Map systemConfig.features.my-feature to config.features.my-feature.enable
    {
      features.my-feature = {
        enable = mkDefault (systemConfig.features.my-feature or false);
      };
    }
    
    # Register commands in command-center (only when feature is enabled)
    (mkIf cfg.enable {
      features.command-center.commands = [
        {
          name = "my-command";
          description = "Description of command";
          category = "system";
          script = "${myScript}/bin/ncc-my-command-main";
          arguments = [];
          dependencies = [];
          shortHelp = "my-command - Short help text";
          longHelp = ''
            Detailed help text here.
          '';
        }
        {
          name = "another-command";
          description = "Another command";
          category = "system";
          script = "${anotherScript}/bin/ncc-another-command-main";
          arguments = [ "--option1" "--option2" ];
          dependencies = [];
          shortHelp = "another-command [options] - Another command";
          longHelp = ''
            Detailed help for another command.
          '';
        }
      ];
    })
    
    # Feature implementation (only when enabled)
    (mkIf cfg.enable {
      # Feature-specific config here
      # systemd services, tmpfiles, etc.
    })
  ];
}

