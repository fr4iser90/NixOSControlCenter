# NixOS Custom Configuration

This directory contains custom NixOS configurations that are automatically imported via `default.nix`. 

## Usage

1. Add `.nix` files to this directory
2. The configurations will be automatically imported and applied
3. Files are imported in alphabetical order

## Examples

The following examples demonstrate how to create custom configurations:

### KDE Connect Configuration (kde-connect.nix)
```nix
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    kdePackages.kdeconnect-kde
    kdePackages.krfb
    kdePackages.krdc
    kdePackages.plasma-browser-integration
    kdePackages.qtwebengine
    kdePackages.plasma-firewall
    kdePackages.plasma-nm
    kdePackages.kdenetwork-filesharing
    kdePackages.plasma-systemmonitor
    kdePackages.plasma-workspace
    kdePackages.knotifications
    kdePackages.bluedevil
    bluez
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-kde ];
    config = {
      common.default = ["kde"];
      kde = {
        default = ["kde"];
        "org.freedesktop.impl.portal.Secret" = ["kde"];
        "org.freedesktop.impl.portal.ScreenCast" = ["kde"];
      };
    };
  };

  hardware.bluetooth.enable = true;
  services.dbus.packages = [ pkgs.kdePackages.kdeconnect-kde ];
  networking.firewall.allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
  networking.firewall.allowedUDPPortRanges = [ { from = 1714; to = 1764; } ];
}
```

### NoiseTorch Configuration (noisetorch.nix)
```nix
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.noisetorch ];
  
  security.wrappers.noisetorch = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_resource+ep";
    source = "${pkgs.noisetorch}/bin/noisetorch";
  };
}
```

## Import System

The `default.nix` file automatically imports all `.nix` files in this directory:

```nix
let
  currentDir = toString ./.;
  nixFiles = builtins.attrNames (lib.filterAttrs 
    (_: v: lib.hasSuffix ".nix" v) 
    (builtins.readDir currentDir));
  
  imports = map (file: currentDir + "/${file}") nixFiles;
in
{
  imports = if nixFiles == [] then [] else imports;
}
```

> Note: Files are imported in alphabetical order. Use proper naming if configuration order matters.
