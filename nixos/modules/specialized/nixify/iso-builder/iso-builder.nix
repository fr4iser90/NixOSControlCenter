# Nixify ISO Builder
# Erstellt Custom NixOS ISO mit eingebetteter system-config.nix
# NOTE: This file is used by the web service at runtime, not during system build

{ pkgs, lib, systemConfig ? null, sessionConfig, nixpkgs ? null, ... }:

let
  # Custom Config einbetten
  customConfigFile = pkgs.writeText "system-config.nix" sessionConfig;
  
  # Installer-Script für automatische Installation
  installerScript = pkgs.writeScript "nixify-auto-install.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "=== Nixify Auto-Installation ==="
    echo ""
    
    # Check if system-config.nix exists on ISO
    if [ ! -f /mnt/cdrom/system-config.nix ]; then
      echo "⚠️  Warning: system-config.nix not found on ISO"
      echo "   Proceeding with manual installation..."
      exit 0
    fi
    
    # Copy config to target system
    echo "📋 Copying system-config.nix to /mnt/etc/nixos/..."
    mkdir -p /mnt/etc/nixos
    cp /mnt/cdrom/system-config.nix /mnt/etc/nixos/
    
    # Optional: Review config before installation
    echo ""
    echo "📄 Generated system-config.nix:"
    echo "---"
    head -20 /mnt/etc/nixos/system-config.nix
    echo "..."
    echo "---"
    echo ""
    read -p "Review config above. Continue with installation? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
      echo "Installation cancelled. Config is available at /mnt/etc/nixos/system-config.nix"
      exit 0
    fi
    
    # Run nixos-install with the config
    echo ""
    echo "🚀 Starting NixOS installation with generated config..."
    nixos-install --system /mnt/etc/nixos/system-config.nix
    
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
    echo "The generated system-config.nix is available at:"
    echo "  /mnt/cdrom/system-config.nix"
    echo ""
    echo "To use it:"
    echo "  1. Copy it to your target system:"
    echo "     cp /mnt/cdrom/system-config.nix /mnt/etc/nixos/"
    echo ""
    echo "  2. Review and edit if needed:"
    echo "     nano /mnt/etc/nixos/system-config.nix"
    echo ""
    echo "  3. Run nixos-install:"
    echo "     nixos-install"
    echo ""
  '';
  
  # ISO mit eingebetteter Config
  customIso = pkgs.symlinkJoin {
    name = "nixos-nixified-iso";
    paths = [
      # Base ISO would be built here
      # For now, we create a structure that can be used with nixos-generate-config
    ];
  };
  
in
{
  # ISO Builder Function
  # NOTE: This is a placeholder - actual ISO building requires nixos-generate-config
  # and should be done via nix-build at runtime, not during system evaluation
  buildISO = { sessionId, variant ? "plasma" }:
    throw "ISO building must be done at runtime via nix-build, not during system evaluation";
  
  # Helper: Extract config from session
  extractConfig = sessionId:
    let
      configPath = "/var/lib/nixify/session-${sessionId}-config.nix";
    in
      if builtins.pathExists configPath then
        builtins.readFile configPath
      else
        throw "Config not found for session ${sessionId}";
  
  # Scripts for ISO
  scripts = {
    autoInstall = installerScript;
    manualInstall = manualInstallScript;
  };
}
