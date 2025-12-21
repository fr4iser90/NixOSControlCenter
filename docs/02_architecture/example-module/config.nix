{ config, lib, pkgs, systemConfig, ... }:

let

{
  example-module = {
    enable = false;
    option1 = "default-value";
    option2 = 42;
    nested = {
      option = false;
    };
  };
}
'';
in
  lib.mkMerge [
    {
      # Set default enable value
      example-module.enable = lib.mkDefault (systemConfig.modules.example-module or false);
    }
    {
      # Symlink management (always runs, even if disabled)
      config.system.activationScripts.example-module-config-symlink = 
        if configHelpers != null then
          configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig
        else ''
          # Fallback if configHelpers not available
          mkdir -p "$(dirname "${symlinkPath}")"
          mkdir -p "$(dirname "${userConfigFile}")"
          
          if [ ! -f "${userConfigFile}" ]; then
            cat > "${userConfigFile}" <<'EOF'
${defaultConfig}
EOF
          fi
          
          if [ -L "${symlinkPath}" ] || [ -f "${symlinkPath}" ]; then
            CURRENT_TARGET=$(readlink -f "${symlinkPath}" 2>/dev/null || echo "")
            EXPECTED_TARGET=$(readlink -f "${userConfigFile}" 2>/dev/null || echo "")
            
            if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
              if [ -f "${symlinkPath}" ] && [ ! -L "${symlinkPath}" ]; then
                cp "${symlinkPath}" "${symlinkPath}.backup.$(date +%s)"
              fi
              ln -sfn "${userConfigFile}" "${symlinkPath}"
            fi
          else
            ln -sfn "${userConfigFile}" "${symlinkPath}"
          fi
        '';
    }
    (lib.mkIf (cfg.enable or false) {
      # Module implementation (only when enabled)
      
      # Example: Add system packages
      environment.systemPackages = with pkgs; [
        # Add your packages here
      ];

      # Example: Configure services
      # services.example-service = {
      #   enable = true;
      #   config = cfg.option1;
      # };

      # Example: Assertions
      assertions = [
        {
          assertion = cfg.option2 > 0;
          message = "option2 must be greater than 0";
        }
      ];
    })
  ];

