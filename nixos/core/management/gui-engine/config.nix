{ config, lib, pkgs, getCurrentModuleMetadata, getModuleMetadata, getModuleConfig, getModuleApi, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
  apiValue = import ./api.nix { inherit lib getModuleMetadata; metadata = metadata; };
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
    })
  ];
}
