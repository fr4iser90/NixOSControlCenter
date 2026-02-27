# NixOS ISO Configuration with Calamares and NixOS Control Center Module
# CLEAN VERSION - Store-only, no hardcoded paths

{ pkgs, lib, config, desktopEnv, buildTimestamp ? "cached", ... }:

let
  # NixOS Control Center repository (will be copied to ISO)
  nixosDir = builtins.path {
    path = ../../../..;
    filter = path: type:
      type == "directory" || 
      (type == "regular" && !(builtins.match ".*\\.git.*" path != null));
  };
  
  shellDir = builtins.path {
    path = ../../../../../shell;
    filter = path: type:
      type == "directory" || 
      (type == "regular" && !(builtins.match ".*\\.git.*" path != null));
  };
  
  nixosControlCenterRepo = pkgs.runCommand "nixos-control-center-repo" {} ''
    mkdir -p $out
    cp -r ${nixosDir}/* $out/ 2>/dev/null || true
    mkdir -p $out/shell
    cp -r ${shellDir}/* $out/shell/ 2>/dev/null || true
    rm -rf $out/.git $out/result $out/result-* $out/*.iso 2>/dev/null || true
    chmod -R u+w $out
  '';
  
  # Module derivation from overlay (job only - no viewqml!)
  calamaresJobModule = pkgs.calamaresJobModule;
  
  # Select base ISO based on desktop environment
  baseIsoModule = 
    if desktopEnv == "gnome" then
      <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix>
    else if desktopEnv == "plasma6" then
      ./base-iso-patched.nix
    else
      throw "Unknown desktop environment: ${desktopEnv}. Supported: gnome, plasma6";
in
{
  imports = [ baseIsoModule ];

  # ISO configuration
  image = {
    baseName = lib.mkForce "nixos-nixify-${desktopEnv}-${config.system.nixos.version}-${pkgs.stdenv.hostPlatform.system}";
  };

  isoImage = {
    # Copy NixOS Control Center repo to ISO
    contents = lib.mkAfter [
      {
        source = nixosControlCenterRepo;
        target = "/nixos";
      }
    ];
    
    # Include modules in Store (job only!)
    storeContents = lib.mkAfter [
      nixosControlCenterRepo
      calamaresJobModule
    ];
    
    makeEfiBootable = true;
    makeUsbBootable = true;
  };
  
  # Force ISO rebuild when config changes
  system.build.isoImage = lib.mkOverride 1000 (
    (config.system.build.isoImage).overrideAttrs (old: {
      inherit buildTimestamp;
      buildInputs = (old.buildInputs or []) ++ [
        nixosControlCenterRepo
        calamaresJobModule
      ];
    })
  );

  # System packages
  environment.systemPackages = with pkgs; lib.mkAfter [
    python3
    python3Packages.pyqt5
    pciutils
    usbutils
    dmidecode
    bash
    git
    nix
    pkgs.calamares-nixos
  ];

  services.udev.enable = true;
  hardware.enableAllFirmware = true;
  
  # Force into closure
  system.extraDependencies = [
    pkgs.calamares-nixos-extensions
    calamaresJobModule
  ];
}
