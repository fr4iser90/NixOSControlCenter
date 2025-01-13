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
    fzf      
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
        "history-substring-search"  
        "fzf"
      ];
      theme = "agnoster";
    };

    initExtra = ''
      # Aliases
      export MANPAGER='nvim +Man!'
      
      alias buildNix='bash ~/Documents/build.sh'
     
      # Navigation
      alias ..='cd ..'
      alias ...='cd ../..'
      alias ....='cd ../../..'
      alias .....='cd ../../../..'
      alias ~='cd ~'
      
      # List Directory
      alias ll='ls -lah'                        # Ausführliche Liste
      alias la='ls -A'                          # Zeige versteckte Dateien
      alias l='ls -CF'                          # Spaltenformat
      alias lt='ls -ltrh'                       # Sortiert nach Zeit, neuste unten
      alias lsize='ls -lSrh'                    # Sortiert nach Größe
      
      # System
      alias df='df -h'                          # Menschlich lesbare Größen
      alias free='free -h'                      # Menschlich lesbare Größen
      alias top='htop'                          # Besseres top
      alias duf='du -sh *'                      # Verzeichnisgrößen
      
      # Git
      alias g='git'
      alias gs='git status'
      alias ga='git add'
      alias gc='git commit'
      alias gp='git push'
      alias gl='git pull'
      alias gd='git diff'
      alias glog='git log --oneline --graph'
      
      # Nix
      alias buildNix='bash ~/Documents/build.sh'
      alias nrs='sudo nixos-rebuild switch'
      alias nrb='sudo nixos-rebuild boot'
      alias nrt='sudo nixos-rebuild test'
      alias nsp='nix-shell -p'
      
      # Vim/Neovim
      alias vim='nvim'
      alias vi='nvim'
      
      # Netzwerk
      alias ports='netstat -tulanp'
      alias myip='curl http://ipecho.net/plain; echo'
      
      # Sicherheit
      alias checkports='sudo lsof -i -P -n | grep LISTEN'
      alias sshconfig='${EDITOR:-nvim} ~/.ssh/config'
      
      # Utility
      alias c='clear'
      alias h='history'
      alias j='jobs -l'
      alias path='echo -e ''${PATH//:/\\n}'
      alias now='date +"%T"'
      alias nowtime=now
      alias nowdate='date +"%d-%m-%Y"'
      
      # Fehlerkorrektur für häufige Tippfehler
      alias cd..='cd ..'
      alias pdw='pwd'
      alias udpate='update'
      alias claer='clear'
      
      # Entwicklung
      alias py='python'
      alias pip='pip3'
      alias serve='python -m http.server'       # Schneller HTTP-Server
      
      # Docker
      alias d='docker'
      alias dc='docker-compose'
      alias dps='docker ps'
      alias dimg='docker images'

      # History-Einstellungen
      HISTSIZE=10000
      SAVEHIST=10000
      setopt SHARE_HISTORY
      setopt HIST_IGNORE_DUPS
      setopt HIST_FIND_NO_DUPS
      
      # Automatische CD
      setopt AUTO_CD
      
      # Fuzzy-Finder-Konfiguration
      if [ -n "$(command -v fzf)" ]; then
        source ${pkgs.fzf}/share/fzf/completion.zsh
        source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      fi

      # Aktiviere erweiterte Globbing-Funktionen
      setopt EXTENDED_GLOB
    '';
  };
}
