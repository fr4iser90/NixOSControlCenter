# modules/profiles/types/default.nix
{
  systemTypes = {
    # Server-Profile
    server = {
      headless = {
        type = "headless";
        category = "server";
        defaults = {
          desktop = null;
          ssh = true;
          virtualization = true;
          docker = true;
          monitoring = true;
          sound = false;
          bluetooth = false;
          printing = false;
        };
      };
    };

    # Desktop-Profile
    desktop = {
      gaming = {
        type = "gaming";
        category = "desktop";
        defaults = {
          desktop = true;
          ssh = false;
          sound = true;
          bluetooth = true;
          steam = true;
          gaming-tools = true;
        };
      };
    };

    # Hybrid-Profile
    hybrid = {
      gaming-workstation = {
        type = "gaming-workstation";
        category = "hybrid";
        defaults = {
          desktop = true;
          ssh = true;
          sound = true;
          bluetooth = true;
          virtualization = true;
          development = true;
        };
      };
    };
  };
}