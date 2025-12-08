{
  # Configuration Schema Version
  configVersion = "1.0";
  
  # System-Identität
  systemType = "@SYSTEM_TYPE@";
  hostName = "@HOSTNAME@";
  
  # System-Version
  system = {
    channel = "stable";  # [stable/unstable] - Version wird in flake.nix definiert
    bootloader = "@BOOTLOADER@";
  };
  
  # Nix-Config
  allowUnfree = @ALLOW_UNFREE@;
  
  # User-Management
  users = {
    @USERS@  
  };
  
  # TimeZone
  timeZone = "@TIMEZONE@";
}