{
  # Core system configuration
  configVersion = "1.0";
  systemType = "desktop";
  system.channel = "stable";
  # Nix Config
  allowUnfree = true;
  # Modules are managed via their own config files:
  # /etc/nixos/configs/modules/*/config.nix
  # Each module has its own 'enable' option
}
