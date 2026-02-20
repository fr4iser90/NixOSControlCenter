# Nixify ISO Builder
# Erstellt Custom NixOS ISO mit eingebetteten configs/*.nix Dateien
# NOTE: This file is used by the web service at runtime, not during system build

{ pkgs, lib, systemConfig ? null, sessionConfigs, nixpkgs ? null, ... }:

let
  # Configs-Verzeichnis auf ISO erstellen
  configsDir = pkgs.runCommand "nixify-configs" {} ''
    mkdir -p $out/configs
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: content:
      "echo ${lib.escapeShellArg content} > $out/configs/${name}"
    ) sessionConfigs)}
  '';
  
  # Installer-Script für automatische Installation
  installerScript = pkgs.writeScript "nixify-auto-install.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "=== Nixify Auto-Installation ==="
    echo ""
    
    # Check if configs directory exists on ISO
    if [ ! -d /mnt/cdrom/configs ]; then
      echo "⚠️  Warning: configs/ directory not found on ISO"
      echo "   Proceeding with manual installation..."
      exit 0
    fi
    
    # Copy configs to target system
    echo "📋 Copying configs/ directory to /mnt/etc/nixos/..."
    mkdir -p /mnt/etc/nixos/configs
    cp -r /mnt/cdrom/configs/* /mnt/etc/nixos/configs/
    
    # Optional: Review configs before installation
    echo ""
    echo "📄 Generated config files:"
    echo "---"
    ls -la /mnt/etc/nixos/configs/
    echo "---"
    echo ""
    read -p "Review configs above. Continue with installation? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
      echo "Installation cancelled. Configs are available at /mnt/etc/nixos/configs/"
      exit 0
    fi
    
    # Run nixos-install (configs will be loaded automatically via flake.nix)
    echo ""
    echo "🚀 Starting NixOS installation with generated configs..."
    nixos-install
    
    echo ""
    echo "✅ Installation complete!"
    echo "   Reboot and enjoy your Nixified system!"
  '';
  
  # Helper script for manual installation
  manualInstallScript = pkgs.writeScript "nixify-manual-install.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "=== Nixify Manual Installation ==="
    echo ""
    echo "The generated configs/ directory is available at:"
    echo "  /mnt/cdrom/configs/"
    echo ""
    echo "To use it:"
    echo "  1. Copy configs to your target system:"
    echo "     mkdir -p /mnt/etc/nixos/configs"
    echo "     cp -r /mnt/cdrom/configs/* /mnt/etc/nixos/configs/"
    echo ""
    echo "  2. Review and edit if needed:"
    echo "     ls -la /mnt/etc/nixos/configs/"
    echo "     nano /mnt/etc/nixos/configs/desktop-config.nix"
    echo ""
    echo "  3. Run nixos-install:"
    echo "     nixos-install"
    echo ""
    echo "The configs will be automatically loaded by flake.nix"
  '';
  
in
{
  # ISO Builder Function
  # NOTE: This is a placeholder - actual ISO building requires nixos-generate-config
  # and should be done via nix-build at runtime, not during system evaluation
  buildISO = { sessionId, variant ? "plasma" }:
    throw "ISO building must be done at runtime via nix-build, not during system evaluation";
  
  # Helper: Extract configs from session
  extractConfigs = sessionId:
    let
      configsPath = "/var/lib/nixify/session-${sessionId}-configs";
    in
      if builtins.pathExists configsPath then
        builtins.readDir configsPath
      else
        throw "Configs not found for session ${sessionId}";
  
  # Scripts for ISO
  scripts = {
    autoInstall = installerScript;
    manualInstall = manualInstallScript;
  };
  
  # Configs directory for ISO
  configs = configsDir;
}
