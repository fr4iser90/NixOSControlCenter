{
  systemConfig.core.management.system-manager.submodules.system-update = {
    enable = true;
    autoBuild = false;
    backup = {
      enable = true;
      retention = 5;
      directory = "/var/backup/nixos";
    };
    sources = [
      {
        name = "remote";
        url = "https://github.com/fr4iser90/NixOSControlCenter.git";
        branches = [ "main" "develop" "experimental" ];
      }
      {
        name = "local";
        url = "/home/user/Documents/Git/NixOSControlCenter/nixos";
        branches = [];
      }
    ];
  };
}
