{
  description = "NixOS Configuration with Home Manager";

  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Home-Manager Inputs für verschiedene Versionen
    home-manager-stable.url = "github:nix-community/home-manager/release-25.11";
    home-manager-unstable.url = "github:nix-community/home-manager";
  };

  outputs = { self
    , nixpkgs-stable
    , nixpkgs-unstable
    , home-manager-stable
    , home-manager-unstable
    , ... 
  }: let
    system = "x86_64-linux";
    
    # Check if old structure exists (fallback for compatibility)
    # If system-config.nix still has all values, it will still work
    # (will be overridden by optional configs if present)
    
    # 1. Load minimal system-config (MUST exist)
    # If old structure: contains all values, will be overridden by optional configs
    baseConfig = import ./system-config.nix;
    
    # 2. Load optional configs (if present)
    desktopConfig = if builtins.pathExists ./configs/desktop-config.nix
      then import ./configs/desktop-config.nix else {};
    localizationConfig = if builtins.pathExists ./configs/localization-config.nix
      then import ./configs/localization-config.nix else {};
    hardwareConfig = if builtins.pathExists ./configs/hardware-config.nix
      then import ./configs/hardware-config.nix else {};
    featuresConfig = if builtins.pathExists ./configs/features-config.nix
      then import ./configs/features-config.nix else {};
    packagesConfig = if builtins.pathExists ./configs/packages-config.nix
      then import ./configs/packages-config.nix else {};
    networkConfig = if builtins.pathExists ./configs/network-config.nix
      then import ./configs/network-config.nix else {};
    securityConfig = if builtins.pathExists ./configs/security-config.nix
      then import ./configs/security-config.nix else {};
    performanceConfig = if builtins.pathExists ./configs/performance-config.nix
      then import ./configs/performance-config.nix else {};
    storageConfig = if builtins.pathExists ./configs/storage-config.nix
      then import ./configs/storage-config.nix else {};
    monitoringConfig = if builtins.pathExists ./configs/monitoring-config.nix
      then import ./configs/monitoring-config.nix else {};
    backupConfig = if builtins.pathExists ./configs/backup-config.nix
      then import ./configs/backup-config.nix else {};
    loggingConfig = if builtins.pathExists ./configs/logging-config.nix
      then import ./configs/logging-config.nix else {};
    updateConfig = if builtins.pathExists ./configs/update-config.nix
      then import ./configs/update-config.nix else {};
    servicesConfig = if builtins.pathExists ./configs/services-config.nix
      then import ./configs/services-config.nix else {};
    virtualizationConfig = if builtins.pathExists ./configs/virtualization-config.nix
      then import ./configs/virtualization-config.nix else {};
    hostingConfig = if builtins.pathExists ./configs/hosting-config.nix
      then import ./configs/hosting-config.nix else {};
    environmentConfig = if builtins.pathExists ./configs/environment-config.nix
      then import ./configs/environment-config.nix else {};
    identityConfig = if builtins.pathExists ./configs/identity-config.nix
      then import ./configs/identity-config.nix else {};
    certificatesConfig = if builtins.pathExists ./configs/certificates-config.nix
      then import ./configs/certificates-config.nix else {};
    complianceConfig = if builtins.pathExists ./configs/compliance-config.nix
      then import ./configs/compliance-config.nix else {};
    haConfig = if builtins.pathExists ./configs/ha-config.nix
      then import ./configs/ha-config.nix else {};
    disasterRecoveryConfig = if builtins.pathExists ./configs/disaster-recovery-config.nix
      then import ./configs/disaster-recovery-config.nix else {};
    secretsConfig = if builtins.pathExists ./configs/secrets-config.nix
      then import ./configs/secrets-config.nix else {};
    multiTenantConfig = if builtins.pathExists ./configs/multi-tenant-config.nix
      then import ./configs/multi-tenant-config.nix else {};
    overridesConfig = if builtins.pathExists ./configs/overrides-config.nix
      then import ./configs/overrides-config.nix else {};
    
    # 3. Merge: baseConfig is overridden by optional configs
    # Order is important: later configs override earlier ones
    systemConfig = baseConfig
      // desktopConfig
      // localizationConfig
      // hardwareConfig
      // featuresConfig
      // packagesConfig
      // networkConfig
      // securityConfig
      // performanceConfig
      // storageConfig
      // monitoringConfig
      // backupConfig
      // loggingConfig
      // updateConfig
      // servicesConfig
      // virtualizationConfig
      // hostingConfig
      // environmentConfig
      // identityConfig
      // certificatesConfig
      // complianceConfig
      // haConfig
      // disasterRecoveryConfig
      // secretsConfig
      // multiTenantConfig
      // overridesConfig;
    
    # Wähle das richtige nixpkgs und home-manager basierend auf der Konfiguration
    nixpkgs = if systemConfig.system.channel == "stable"
              then nixpkgs-stable
              else nixpkgs-unstable;
              
    home-manager = if systemConfig.system.channel == "stable"
                   then home-manager-stable
                   else home-manager-unstable;

    # Set stateVersion once for both system and home-manager
    # NOTE: Version wird oben in inputs definiert - hier nur stateVersion setzen
    stateVersion = if systemConfig.system.channel == "stable"
      then "25.11"
      else "25.11"; # Use latest stable for unstable as well, or set to a default
    
    pkgs = import nixpkgs { 
      inherit system;
      config.allowUnfree = systemConfig.allowUnfree or false;
    };
    lib = pkgs.lib;

    # Base modules required for all systems
    systemModules = [
      ./hardware-configuration.nix
      ./core
      ./desktop
      ./packages
      ./features
      ./custom
    ];

  in {
    nixosConfigurations = {
      "${systemConfig.hostName}" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit systemConfig; }; 

        modules = systemModules ++ [      
          {
            # System Version
            system.stateVersion = stateVersion;

            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            # Unfree Konfiguration
            nixpkgs.config = {
              allowUnfree = systemConfig.allowUnfree or false;
            };
          }     
          
          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit systemConfig; };
              users = lib.mapAttrs (username: userConfig: 
                { config, ... }: {
                  imports = [ 
                    (import ./core/user/home-manager/roles/${userConfig.role}.nix {
                      inherit pkgs lib config systemConfig;
                      user = username;
                    })
                  ];
                    home = {
                    username = username;
                    homeDirectory = "/home/${username}";
                    stateVersion = stateVersion;
                  };
              }) systemConfig.users;
            };
          }
        ];
      };
    };
  };
}
