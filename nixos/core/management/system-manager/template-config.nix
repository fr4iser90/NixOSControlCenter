{
  # Core module - always active (no enable option)
  # System manager is essential for system management operations
  
  # Core system configuration
  configVersion = "2.0";
  # layout: "monolith" (systemConfig.nix) | "split" (systemConfig/**/config.nix)
  layout = "monolith";
  systemType = "desktop";
  system.channel = "stable";
  # Nix Config
  allowUnfree = true;
  # Modules are managed via systemConfig (monolith nested attrs or split leaf files).
  # Each module has its own 'enable' option
}
