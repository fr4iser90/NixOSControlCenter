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
    powerline-fonts   
    meslo-lgs-nf      
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
      theme = "agnoster";
    };

    initExtra = ''
      # Aliases
      export MANPAGER='nvim +Man!'
      
      alias ll='ls -lah'
      alias la='ls -A'
      alias l='ls -CF'
      alias buildNix='bash ~/Documents/build.sh'
    '';
  };
}