# Nixify ISO Builder
# Erstellt Custom NixOS ISO mit kompletten NixOSControlCenter Repository + generierten configs/*.nix
# NOTE: This file is used by the web service at runtime, not during system build

{ pkgs, lib, systemConfig ? null, sessionConfigs, nixosControlCenterRepo ? null, nixpkgs ? null, ... }:

let
  # Generierte configs/*.nix Dateien
  generatedConfigsDir = pkgs.runCommand "nixify-generated-configs" {} ''
    mkdir -p $out/configs
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: content:
      "echo ${lib.escapeShellArg content} > $out/configs/${name}"
    ) sessionConfigs)}
  '';
  
  # Komplettes NixOSControlCenter Repository mit generierten configs
  # Falls nixosControlCenterRepo nicht angegeben, verwende aktuelles Verzeichnis
  repoPath = if nixosControlCenterRepo != null then nixosControlCenterRepo else ./.;
  
  # Repository + generierte configs zusammenführen
  completeRepo = pkgs.runCommand "nixos-control-center-with-configs" {} ''
    # Komplettes Repository kopieren
    cp -r ${repoPath}/* $out/
    
    # Generierte configs/*.nix in configs/ Verzeichnis kopieren
    mkdir -p $out/configs
    cp -r ${generatedConfigsDir}/configs/* $out/configs/
    
    # Berechtigungen setzen
    chmod -R u+w $out
  '';
  
  # Installer-Script für automatische Installation
  installerScript = pkgs.writeScript "nixify-auto-install.sh" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "=== Nixify Auto-Installation ==="
    echo ""
    
    # Check if NixOSControlCenter repository exists on ISO
    if [ ! -d /mnt/cdrom/nixos ]; then
      echo "⚠️  Warning: NixOSControlCenter repository not found on ISO"
      echo "   Proceeding with manual installation..."
      exit 0
    fi
    
    # Copy complete repository to target system
    echo "📋 Copying NixOSControlCenter repository to /mnt/etc/nixos/..."
    cp -r /mnt/cdrom/nixos/* /mnt/etc/nixos/
    
    # Generate hardware-configuration.nix (automatisch!)
    echo ""
    echo "🔧 Generating hardware-configuration.nix..."
    nixos-generate-config --root /mnt
    
    # Optional: Review configs before installation
    echo ""
    echo "📄 Generated config files in configs/:"
    echo "---"
    ls -la /mnt/etc/nixos/configs/
    echo "---"
    echo ""
    read -p "Review configs above. Continue with installation? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
      echo "Installation cancelled. Config is available at /mnt/etc/nixos/"
      exit 0
    fi
    
    # Run nixos-install with flake
    echo ""
    echo "🚀 Starting NixOS installation with NixOSControlCenter config..."
    # Hostname aus flake.nix extrahieren oder Standard verwenden
    HOSTNAME=$(grep -oP 'nixosConfigurations = \{.*?"\K[^"]+' /mnt/etc/nixos/flake.nix | head -1 || echo "nixos")
    nixos-install --flake /mnt/etc/nixos#${HOSTNAME}
    
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
    echo "The complete NixOSControlCenter repository is available at:"
    echo "  /mnt/cdrom/nixos/"
    echo ""
    echo "To use it:"
    echo "  1. Copy repository to your target system:"
    echo "     cp -r /mnt/cdrom/nixos/* /mnt/etc/nixos/"
    echo ""
    echo "  2. Generate hardware-configuration.nix:"
    echo "     nixos-generate-config --root /mnt"
    echo ""
    echo "  3. Review and edit configs if needed:"
    echo "     ls -la /mnt/etc/nixos/configs/"
    echo "     nano /mnt/etc/nixos/configs/desktop-config.nix"
    echo ""
    echo "  4. Run nixos-install with flake:"
    echo "     HOSTNAME=\$(grep -oP 'nixosConfigurations = \{.*?\"\\K[^\"]+' /mnt/etc/nixos/flake.nix | head -1 || echo 'nixos')"
    echo "     nixos-install --flake /mnt/etc/nixos#\${HOSTNAME}"
    echo ""
  '';
  
in
{
  # ISO Builder Function
  # NOTE: This is a placeholder - actual ISO building requires nixos-generate-config
  # and should be done via nix-build at runtime, not during system evaluation
  # variant wird aus dem generierten desktop-config.nix gelesen, KEIN Default!
  buildISO = { sessionId, repoPath ? null }:
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
  
  # Complete repository with generated configs for ISO
  completeRepo = completeRepo;
  
  # Generated configs only (for reference)
  generatedConfigs = generatedConfigsDir;
}
