{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  cliRegistry = getModuleApi "cli-registry";
  hostname = lib.attrByPath [ "hostName" ] "nixos" (getModuleConfig "network");
  systemChecks = lib.attrByPath [ "enable" ] false (getModuleConfig "system-checks");
  # User config (systemConfig + template): channel, etc.
  smCfg = getModuleConfig "system-manager";
  channel = lib.attrByPath [ "system" "channel" ] "stable" smCfg;
  # NixOS options (options.nix) via discovery — dotted configPath key (not nested path)
  smPath = (getModuleMetadata "system-manager").configPath;
  nixosCfg = config.${smPath} or {};
  cmCfg = nixosCfg.components.channelManager or {};
  onCalendar = cmCfg.checkInterval or "weekly";
  enableNotify =
    (nixosCfg.enableDeprecationWarnings or true)
    && (cmCfg.enableNotify or true);

  channelManager = import ../components/channel-manager/default.nix {
    inherit pkgs lib getModuleApi hostname systemChecks channel onCalendar;
  };
in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [
        channelManager.updateChannelsScript
        channelManager.checkReleaseScript
      ];
    }

    (lib.mkIf enableNotify channelManager.notifyNixosConfig)

    (cliRegistry.registerCommandsFor "channel-manager" [
      {
        name = "update-channels";
        domain = "system";
        parent = "system";
        description = "Update Nix flake inputs / channels and rebuild the system";
        category = "system";
        script = "${channelManager.updateChannelsScript}/bin/ncc-update-channels";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "update-channels - Update flake inputs and rebuild";
        longHelp = ''
          Updates the flake inputs / channels by running 'nix flake update'
          and then rebuilds the system using 'nixos-rebuild switch'
          or 'ncc system build switch' if system checks are enabled.
          Requires sudo privileges.
        '';
      }
      {
        name = "check-release";
        domain = "system";
        parent = "system";
        description = "Check whether a newer NixOS stable release is available";
        category = "system";
        script = "${channelManager.checkReleaseScript}/bin/ncc-check-release";
        arguments = [ "--quiet" "--json" "--flake" ];
        dependencies = [ "curl" "jq" ];
        shortHelp = "check-release - Check for new NixOS stable releases";
        longHelp = ''
          Compares the nixos-YY.MM pin in /etc/nixos/flake.nix against the
          latest nixos-* branch on GitHub.

          Exit codes:
            0  - already on latest stable pin
            10 - newer stable release available
            1  - error

          Options:
            --quiet   Suppress human-readable output
            --json    Machine-readable JSON summary
            --flake PATH  Alternate flake.nix to inspect
        '';
      }
    ])
  ];
}
