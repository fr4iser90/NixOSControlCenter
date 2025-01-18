{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  # Import container variables
  containerVars = import ./modules/vars.nix { inherit lib config types pkgs; };

  # Erstelle Sub-UID und Sub-GID-Bereiche für Podman
  podmanUserConfig = {
    subUidRanges = [ { startUid = 100000; count = 65536; } ];
    subGidRanges = [ { startGid = 100000; count = 65536; } ];
  };

  # Finde alle Benutzer mit virtualization Rolle
  virtUsers = lib.filterAttrs 
    (name: user: user.role == "virtualization") 
    systemConfig.users;

  # Prüfe ob wir Virtualisierungsbenutzer haben
  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;

  # Erstelle einen dedizierten Podman Benutzer, falls kein Virtualisierungsbenutzer existiert
  podmanUser = {
    name = "podman";
    uid = 200;
    group = "podman";
    description = "Dedicated user for container management";
    isSystemUser = true;
  };

  # Hole den ersten Virtualisierungsbenutzer, falls vorhanden, sonst nutze podman user
  virtUser = if hasVirtUsers then lib.head (lib.attrNames virtUsers) else podmanUser.name;

  # Generate environment files from variables
  mkEnvFile = vars: 
    let
      filteredVars = lib.filterAttrs (name: value: value != null) vars;
    in
      pkgs.writeText "container.env" (
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: value: "${name}=${toString value}") filteredVars
        )
      );
in {
  imports = [
    ./modules/networking.nix
    ./modules/storage.nix
    ./modules/security.nix
    ./modules/monitoring.nix
    ./modules/types.nix
    ./modules/vars.nix
    ./modules/crud
    ./containers
  ];

  options.containerManager = {
    enable = lib.mkEnableOption "Container management";

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/containers";
      description = "Base directory for container data";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = virtUser;
      description = "Default user for container management";
    };

    containers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          image = lib.mkOption { type = lib.types.str; };
          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
            description = "Container environment variables";
          };
          vars = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
            description = "Container-specific variable overrides";
          };
        };
      });
      default = {};
      description = "Container definitions";
    };
  };

  config = {
    # Enable setuid for shadow utils
    security.wrappers = {
      newuidmap = {
        source = "${pkgs.shadow}/bin/newuidmap";
        setuid = true;
      };
      newgidmap = {
        source = "${pkgs.shadow}/bin/newgidmap";
        setuid = true;
      };
    };

    # Create dedicated podman user if needed
    users = lib.mkIf (!hasVirtUsers) {
      users.podman = {
        isSystemUser = true;
        group = "podman";
        extraGroups = [ "docker" ];
        home = "/var/lib/podman";
        createHome = true;
        shell = pkgs.bashInteractive;
        subUidRanges = podmanUserConfig.subUidRanges;
        subGidRanges = podmanUserConfig.subGidRanges;
      };
      groups.podman = {};
    };

    # Ensure container directories have correct permissions
    system.activationScripts.podman-setup = ''
      mkdir -p ${config.containerManager.dataDir}
      chown podman:podman ${config.containerManager.dataDir}
      chmod 755 ${config.containerManager.dataDir}
    '';

    # Generate container configurations with environment files
    containerManager.containers = lib.mapAttrs (name: container: {
      inherit (container) name image;
      env = let
        vars = lib.recursiveUpdate containerVars.containerManager.vars container.vars;
        validatedVars = lib.mapAttrs (varName: varDef:
          if !lib.hasAttr varName vars then
            throw "Missing required variable: ${varName}"
          else
            containerVars.validateVar varDef vars.${varName}
        ) vars;
      in mkEnvFile validatedVars;
    }) config.containerManager.containers;

    # Rootless Podman configuration
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      
      # Required packages for rootless operation
      package = pkgs.podman.override {
        extraPackages = with pkgs; [
          slirp4netns
          fuse-overlayfs
          crun
          shadow
          su
        ];
      };
      
      # Network configuration
      defaultNetwork = {
        settings = {
          dns_enabled = true;
          backend = "netavark";
        };
      };
      
      # Automatic cleanup
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };


    # Ensure proper permissions for storage directories
    system.activationScripts.podman-storage-setup = ''
      mkdir -p ${config.containerManager.dataDir}/storage
      chown -R podman:podman ${config.containerManager.dataDir}/storage
      chmod 755 ${config.containerManager.dataDir}/storage
    '';
  };
}
