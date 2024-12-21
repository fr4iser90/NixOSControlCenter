{ lib }:

with lib;

let
  # Helper für ISO-URLs
  mkNixosUrl = { version, variant }: "https://channels.nixos.org/nixos-${version}/latest-nixos-${variant}-x86_64-linux.iso";
  mkUbuntuUrl = { version }: "https://releases.ubuntu.com/${version}/ubuntu-${version}-desktop-amd64.iso";
  mkFedoraUrl = { version }: "https://download.fedoraproject.org/pub/fedora/linux/releases/${version}/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-${version}-1.7.iso";
  mkArchUrl = { version ? null }: "https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso";

  # Distro-Definitionen
  supportedDistros = {
    nixos = {
      name = "NixOS";
      variants = {
        plasma5 = {
          name = "KDE Plasma";
          getUrl = mkNixosUrl;
          defaultVersion = "23.11";
        };
        gnome = {
          name = "GNOME";
          getUrl = mkNixosUrl;
          defaultVersion = "23.11";
        };
        xfce = {
          name = "XFCE";
          getUrl = mkNixosUrl;
          defaultVersion = "23.11";
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
        defaultVersion = "39";
      };
    };

    arch = {
      name = "Arch Linux";
      variants.default = {
        name = "Default";
        getUrl = mkArchUrl;
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
    if !hasAttr distro supportedDistros then
      throw "Unknown distribution: ${distro}"
    else if !hasAttr variant supportedDistros.${distro}.variants then
      throw "Unknown variant ${variant} for ${distro}"
    else if version == null then
      supportedDistros.${distro}.variants.${variant}.defaultVersion or null
    else version;
}