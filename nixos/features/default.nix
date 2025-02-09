{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.features;

  # Check if at least one feature is active
  hasActiveFeatures = lib.any (x: x) [
    (cfg.system-checks or false)
    (cfg.system-updater or false)
    (cfg.system-logger or false)
    (cfg.container-manager or false)
    (cfg.system-config-manager or false)
    (cfg.homelab-manager or false)
    (cfg.bootentry-manager or false)
    (cfg.ssh-manager or false)
    (cfg.vm-manager or false)
    (cfg.ai-workspace or false)
    (cfg.tracker or false)
  ];

  # Check if the systemType is set to "homelab"
  isHomelabSystem = (systemConfig.systemType or "") == "homelab";

in {
  imports = 
    lib.optionals hasActiveFeatures || isHomelabSystem [
      ./terminal-ui
      ./command-center
    ]
    ++ lib.optionals (cfg.system-checks or false) [ ./system-checks ]
    ++ lib.optionals (cfg.system-updater or false) [ ./system-updater ]
    ++ lib.optionals (cfg.system-logger or false) [ ./system-logger ]
    ++ lib.optionals (cfg.system-config-manager or false) [ ./system-config-manager ]
    ++ lib.optionals (cfg.container-manager or false) [ ./container-manager ]
    # Import homelab-manager if the feature is enabled or if systemType is "homelab"
    ++ lib.optionals ((cfg.homelab-manager or false) || isHomelabSystem) [ ./homelab-manager ]
    ++ lib.optionals (cfg.bootentry-manager or false) [ ./bootentry-manager ]
    ++ lib.optionals (cfg.ssh-client-manager or false) [ ./ssh-client-manager ]
    ++ lib.optionals (cfg.ssh-server-manager or false) [ ./ssh-server-manager ]
    ++ lib.optionals (cfg.vm-manager or false) [ ./vm-manager ]
    ++ lib.optionals (cfg.ai-workspace or false) [ ./ai-workspace ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
