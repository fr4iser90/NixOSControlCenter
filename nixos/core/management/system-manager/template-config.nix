{
  # Core module - always active (no enable option)
  # System manager is essential for system management operations
  
  # Core system configuration
  configVersion = "2.1";
  # layout: "monolith" (systemConfig.nix) | "split" (systemConfig/**/config.nix)
  layout = "monolith";
  systemType = "desktop";
  system.channel = "stable";
  # system.platform: install / migrate / prebuild-check-platform / system-update
  # write from live uname. Flake also reads hardware-configuration.nix (pure; no --impure).
  # Nix Config
  allowUnfree = true;
  # Host policy: skip build y/n after system update and run build+switch
  autoBuild = false;
  # Modules are managed via systemConfig (monolith nested attrs or split leaf files).
  # Each module has its own 'enable' option
}
