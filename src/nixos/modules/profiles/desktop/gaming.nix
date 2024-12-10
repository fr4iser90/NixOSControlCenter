# modules/profiles/types/desktop/gaming.nix
{
  type = "gaming";
  category = "desktop";
  
  # Profil-Defaults
  defaults = {
    desktop = true;
    ssh = false;
    sound = true;
    bluetooth = true;
    steam = true;
    gaming-tools = true;
    
    # Paket-Listen
    packages = {
      base = [
        "git" "wget" "tree"
      ];
      gaming = [
        "steam" "lutris" "wine"
        "discord" "mangohud" "vesktop"
      ];
      multimedia = [
        "firefox" "vlc" "kitty"
      ];
    };
    
    # Service-Konfiguration
    services = {
      steam.enable = true;
      pipewire = {
        enable = true;
        gaming = true;
      };
    };
  };
}