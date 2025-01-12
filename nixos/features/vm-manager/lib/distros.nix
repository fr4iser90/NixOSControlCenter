# modules/virtualization-management/lib/distros.nix
{ lib }:

with lib;

let
  # Helper für ISO-URLs
  mkNixosUrl = { version, variant }: "https://channels.nixos.org/nixos-${version}/latest-nixos-${variant}-x86_64-linux.iso";
  mkUbuntuUrl = { version }: "https://releases.ubuntu.com/${version}/ubuntu-${version}-desktop-amd64.iso";
  mkFedoraUrl = { version }: let
    # Build numbers für bekannte Versionen
    buildNumbers = {
      "41" = "1.4";
      "40" = "1.6";
      "39" = "1.5";
    };
    buildNumber = buildNumbers.${version} or "1.4"; # Fallback to latest known
  in "https://download.fedoraproject.org/pub/fedora/linux/releases/${version}/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-${version}-${buildNumber}.iso";
  mkArchUrl = { version ? null }: "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso";
  mkKaliUrl = { version }: "https://cdimage.kali.org/kali-${version}/kali-linux-${version}-installer-amd64.iso";
  mkPopUrl = { version }: "https://iso.pop-os.org//${version}/amd64/intel/pop-os_${version}_amd64_intel.iso";
  mkMintUrl = { version }: "https://mirrors.edge.kernel.org/linuxmint/stable/${version}/linuxmint-${version}-cinnamon-64bit.iso";
  mkZorinUrl = { version }: "https://mirrors.edge.kernel.org/zorinos/16/Zorin-OS-${version}-Core-64-bit.iso";

  # Distro-Definitionen
  supportedDistros = {
    nixos = {
      name = "NixOS";
      variants = {
        plasma5 = {
          name = "KDE Plasma";
          getUrl = mkNixosUrl;
          defaultVersion = "24.05";
        };
        gnome = {
          name = "GNOME";
          getUrl = mkNixosUrl;
          defaultVersion = "24.05";
        };
        xfce = {
          name = "XFCE";
          getUrl = mkNixosUrl;
          defaultVersion = "24.05";
        };
      };
    };

    ubuntu = {
      name = "Ubuntu";
      variants.desktop = {
        name = "Desktop";
        getUrl = mkUbuntuUrl;
        defaultVersion = "22.04.3";
      };
    };

    fedora = {
      name = "Fedora";
      variants.workstation = {
        name = "Workstation";
        getUrl = mkFedoraUrl;
        defaultVersion = "41";
        availableVersions = [ "41" "40" "39" ];
      };
    };

    arch = {
      name = "Arch Linux";
      variants.default = {
        name = "Default";
        getUrl = mkArchUrl;
      };
    };

    kali = {
      name = "Kali Linux";
      variants.default = {
        name = "Default";
        getUrl = mkKaliUrl;
        defaultVersion = "2024.4";
        availableVersions = [ "2024.4" "2024.3" ];
        defaultMemory = 4096;
        defaultCores = 2;
        defaultDiskSize = 30;
      };
    };

    pop = {
      name = "Pop!_OS";
      variants = {
        intel = {
          name = "Intel/AMD";
          getUrl = mkPopUrl;
          defaultVersion = "22.04";
          availableVersions = [ "22.04" "21.10" ];
          defaultMemory = 4096;
          defaultDiskSize = 25;
        };
      };
    };

    mint = {
      name = "Linux Mint";
      variants.cinnamon = {
        name = "Cinnamon";
        getUrl = mkMintUrl;
        defaultVersion = "21.3";
        availableVersions = [ "21.3" "21.2" ];
        defaultMemory = 4096;
      };
    };

    zorin = {
      name = "Zorin OS";
      variants.core = {
        name = "Core";
        getUrl = mkZorinUrl;
        defaultVersion = "16.3";
        defaultMemory = 4096;
      };
    };
  };
in {
  # Exports
  distros = supportedDistros;  # Als Attribut!

  # Helper-Funktionen
  getDistroUrl = distro: variant: version:
    let 
      d = supportedDistros.${distro}.variants.${variant};
      urlParams = 
        if distro == "nixos" 
        then { inherit version variant; }
        else { inherit version; };
    in d.getUrl urlParams;

  # Validierung
  validateDistro = distro: variant: version:
    let
      variantAttr = supportedDistros.${distro}.variants.${variant};
      availableVersions = variantAttr.availableVersions or null;
      isVersionValid = version: availableVersions == null || elem version availableVersions;
    in
    if !hasAttr distro supportedDistros then
      throw "Unknown distribution: ${distro}"
    else if !hasAttr variant supportedDistros.${distro}.variants then
      throw "Unknown variant ${variant} for ${distro}"
    else if version == null then
      variantAttr.defaultVersion or null
    else if !isVersionValid version then
      throw "Version ${version} is not available for ${distro}. Available versions: ${toString availableVersions}"
    else version;

  # Hilfsfunktion für ISO-Pfade
  getExpectedIsoPaths = distro: variant: version: {
    main = "downloaded.iso";
    drivers = null;
  };
}