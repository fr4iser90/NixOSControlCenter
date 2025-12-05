{ config, lib, ... }:

let
  cfg = config.features.terminal-ui;
  colors = import ./colors.nix;
  
  core = import ./core { 
    inherit lib colors; 
    inherit (cfg) config;
  };
  
  components = import ./components { 
    inherit lib colors; 
    inherit (cfg) config;
  };
  
  interactive = import ./interactive { 
    inherit lib colors; 
    inherit (cfg) config;
  };
  
  status = import ./status { 
    inherit lib colors; 
    inherit (cfg) config;
  };

  # API definition - always available
  apiValue = {
    inherit colors;
    inherit (core) text layout;
    inherit (components) lists tables progress boxes;
    inherit (interactive) prompts spinners;
    inherit (status) messages badges;
  };

in {
  options.features.terminal-ui = {
    enable = lib.mkEnableOption "terminal UI";
    
    config = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Terminal UI configuration options";
    };

    api = lib.mkOption {
      type = lib.types.attrs;
      default = apiValue;
      description = "Terminal UI API für andere Features";
    };

    components = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable this component";
          refreshInterval = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "Refresh interval in seconds";
          };
          template = lib.mkOption {
            type = lib.types.lines;
            description = "Component template using terminal-ui API";
          };
        };
      });
      default = {};
      description = "Custom terminal UI components";
    };
  };

  config = {
    # API always available, not just when enable = true
    features.terminal-ui.api = apiValue;
  };
}
