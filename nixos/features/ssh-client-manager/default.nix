{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [ ./core ];

  config = {
    services.ssh-manager = {
      # Default FZF theme configuration
      fzf = {
        theme = {
          prompt = "→ ";
          pointer = "▶";
          marker = "✓";
          header = "bold";
        };

        preview = {
          enable = true;
          position = "right:40%";
        };

        keybindings = {
          "enter" = "connect";
          "ctrl-x" = "delete";
          "ctrl-e" = "edit";
          "ctrl-n" = "new";
        };
      };
    };
  };
}