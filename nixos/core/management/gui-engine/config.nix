{ config, lib, pkgs, getCurrentModuleMetadata, getModuleMetadata, getModuleConfig, getModuleApi, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
  apiValue = import ./api.nix { inherit lib getModuleMetadata getModuleApi; metadata = metadata; };
  engPkg = import ./package.nix { inherit pkgs; };
  guiOn = apiValue.isEnabled getModuleConfig;

  iconTheme = pkgs.runCommand "ncc-icon-theme" { } ''
    mkdir -p $out/share/icons/hicolor/scalable/apps
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp ${./assets/ncc-icon.svg} $out/share/icons/hicolor/scalable/apps/ncc.svg
    cp ${./assets/ncc-icon.png} $out/share/icons/hicolor/256x256/apps/ncc.png
  '';

  desktop = pkgs.makeDesktopItem {
    name = "ncc";
    desktopName = "NixOS Control Center";
    genericName = "System control";
    comment = "Manage NixOS Control Center modules and hosts";
    exec = "ncc";
    icon = "ncc";
    categories = [ "System" "Settings" ];
    startupNotify = true;
    terminal = false;
  };
in {
  config = lib.mkMerge [
    { ${configPath}.api = apiValue; }
    (lib.mkIf guiOn {
      environment.systemPackages = [ iconTheme desktop ];
      # Event for running GUIs (QFileSystemWatcher) — no polling.
      system.activationScripts.ncc-gui-generation = {
        # After the new system is linked; atomic replace so inotify/dir watches fire.
        text = ''
          mkdir -p /run/ncc
          _ncc_gen_tmp=/run/ncc/generation.tmp.$$
          ${pkgs.coreutils}/bin/readlink -f /run/current-system > "$_ncc_gen_tmp"
          ${pkgs.coreutils}/bin/mv -f "$_ncc_gen_tmp" /run/ncc/generation
          ${pkgs.coreutils}/bin/chmod 644 /run/ncc/generation
        '';
      };
    })
  ];
}
