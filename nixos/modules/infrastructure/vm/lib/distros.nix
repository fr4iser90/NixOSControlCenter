# modules/infrastructure/vm/lib/distros.nix
{ lib }:

with lib;

let
  # Helper für ISO-URLs
  # NixOS 26.05+ ships only unified graphical/minimal ISOs (no per-DE images).
  # Legacy variant names (gnome/plasma*/xfce) map to the graphical channel image.
  nixosChannelVariant = variant:
    if builtins.elem variant [ "graphical" "minimal" ] then variant else "graphical";

  mkNixosUrl = { version, variant }:
    "https://channels.nixos.org/nixos-${version}/latest-nixos-${nixosChannelVariant variant}-x86_64-linux.iso";
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
      osFamily = "linux";
      preferredVariant = "graphical";
      variants = {
        graphical = {
          name = "Graphical Installer";
          getUrl = mkNixosUrl;
          defaultVersion = "26.05";
        };
        minimal = {
          name = "Minimal Installer";
          getUrl = mkNixosUrl;
          defaultVersion = "26.05";
        };
        # Legacy aliases → same channel image as graphical (26.05+ has no per-DE ISOs)
        gnome = {
          name = "GNOME (alias → graphical ISO)";
          getUrl = mkNixosUrl;
          defaultVersion = "26.05";
        };
        plasma5 = {
          name = "KDE Plasma (alias → graphical ISO)";
          getUrl = mkNixosUrl;
          defaultVersion = "26.05";
        };
        plasma6 = {
          name = "KDE Plasma 6 (alias → graphical ISO)";
          getUrl = mkNixosUrl;
          defaultVersion = "26.05";
        };
        xfce = {
          name = "XFCE (alias → graphical ISO)";
          getUrl = mkNixosUrl;
          defaultVersion = "26.05";
        };
      };
    };

    ubuntu = {
      name = "Ubuntu";
      osFamily = "linux";
      variants.desktop = {
        name = "Desktop";
        getUrl = mkUbuntuUrl;
        defaultVersion = "22.04.3";
      };
    };

    fedora = {
      name = "Fedora";
      osFamily = "linux";
      variants.workstation = {
        name = "Workstation";
        getUrl = mkFedoraUrl;
        defaultVersion = "41";
        availableVersions = [ "41" "40" "39" ];
      };
    };

    arch = {
      name = "Arch Linux";
      osFamily = "linux";
      variants.default = {
        name = "Default";
        getUrl = mkArchUrl;
      };
    };

    kali = {
      name = "Kali Linux";
      osFamily = "linux";
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
      osFamily = "linux";
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
      osFamily = "linux";
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
      osFamily = "linux";
      variants.core = {
        name = "Core";
        getUrl = mkZorinUrl;
        defaultVersion = "16.3";
        defaultMemory = 4096;
      };
    };

    # Microsoft does not provide stable anonymous ISO URLs — place the ISO yourself:
    #   sudo cp Win11.iso /var/lib/virt/testing/iso/win11.iso
    # Or: VM_ISO=/path/to/Win11.iso ncc vm test-win11-run
    win10 = {
      name = "Windows 10";
      osFamily = "windows";
      requiresLocalIso = true;
      defaultMemory = 8192;
      defaultCores = 4;
      defaultDiskSize = 64;
      portOffset = 10;
      variants.enterprise = {
        name = "Enterprise Eval";
        localIso = true;
        defaultVersion = "22H2";
        defaultMemory = 8192;
        defaultCores = 4;
        defaultDiskSize = 64;
        isoHint = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-10-enterprise";
      };
    };

    win11 = {
      name = "Windows 11";
      osFamily = "windows";
      requiresLocalIso = true;
      defaultMemory = 8192;
      defaultCores = 4;
      defaultDiskSize = 80;
      portOffset = 11;
      variants.enterprise = {
        name = "Enterprise Eval";
        localIso = true;
        defaultVersion = "25H2";
        defaultMemory = 8192;
        defaultCores = 4;
        defaultDiskSize = 80;
        isoHint = "https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise";
      };
    };
  };
in {
  # Exports
  distros = supportedDistros;

  # Helper-Funktionen
  getDistroUrl = distro: variant: version:
    let
      d = supportedDistros.${distro}.variants.${variant};
    in
      if (d.localIso or false) then null
      else
        let
          urlParams =
            if distro == "nixos"
            then { inherit version variant; }
            else { inherit version; };
        in d.getUrl urlParams;

  isLocalIso = distro: variant:
    (supportedDistros.${distro}.requiresLocalIso or false)
    || (supportedDistros.${distro}.variants.${variant}.localIso or false);

  getOsFamily = distro:
    supportedDistros.${distro}.osFamily or "linux";

  getIsoHint = distro: variant:
    supportedDistros.${distro}.variants.${variant}.isoHint or null;

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
    else if !(variantAttr.localIso or false) && !isVersionValid version then
      throw "Version ${version} is not available for ${distro}. Available versions: ${toString availableVersions}"
    else version;

  # Hilfsfunktion für ISO-Pfade
  getExpectedIsoPaths = distro: variant: version: {
    main = "downloaded.iso";
    drivers = null;
  };
}
