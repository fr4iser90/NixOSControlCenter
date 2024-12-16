# /etc/nixos/modules/homemanager/shellInit/zshInit.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-autocomplete
    zsh-you-should-use
    zsh-navigation-tools
    zsh-system-clipboard
    nix-zsh-completions
    oh-my-zsh
    autojump
    powerline-fonts    # Wichtig für Agnoster/Powerlevel10k
    meslo-lgs-nf      # Empfohlene Schriftart für Powerlevel10k
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "sudo"
        "autojump"
      ];
      theme = "agnoster";  # oder "powerlevel10k/powerlevel10k" wenn du das bevorzugst
    };

    initExtra = ''
      # Aliases
      alias ll='ls -lah'
      alias la='ls -A'
      alias l='ls -CF'
      alias buildNix='bash ~/Documents/nixos/build.sh'
      alias connect='bash ~/.scripts/connect.sh'
      alias connectDeploy='bash ~/.scripts/connectDeploy.sh'
    '';
  };
}