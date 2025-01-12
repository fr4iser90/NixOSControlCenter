# app/shell/dev/hooks/bash-extensions.nix
{ pkgs }:

{  
  shellHook = ''
    # Bash Completion initialisieren
    export BASH_COMPLETION_USER_DIR="${pkgs.bash-completion}/share/bash-completion"
    export BASH_COMPLETION_DIR="${pkgs.bash-completion}/etc/bash_completion.d"
    source "${pkgs.bash-completion}/share/bash-completion/bash_completion"
    
    # FZF Integration
    export FZF_DEFAULT_COMMAND='fd --type f'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    source ${pkgs.fzf}/share/fzf/completion.bash
    source ${pkgs.fzf}/share/fzf/key-bindings.bash
    
    # BAT Configuration
    export BAT_THEME="Dracula"
    export BAT_STYLE="numbers,changes,header"
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    
    # Ripgrep Configuration
    export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
    
    # Less mit Syntax-Highlighting
    export LESS='-R --use-color -Dd+r$Du+b'
    export LESSOPEN="| ${pkgs.bat}/bin/bat --color=always %s"

    # Source Highlight (nur wenn verfügbar)
    if [ -f "${pkgs.sourceHighlight}/share/source-highlight/src-hilite-lesspipe.sh" ]; then
      export HIGHLIGHT_STYLE=emacs
      source "${pkgs.sourceHighlight}/share/source-highlight/src-hilite-lesspipe.sh"
    fi

    # Direnv Hook
    eval "$(${pkgs.direnv}/bin/direnv hook bash)"
    
    # Terminal Setup
    export TERM=xterm-256color
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    # EZA Setup (nur Farben, keine Icons)
    echo "Konfiguriere EZA mit Farben"
    
    # Better Tools Aliases nur mit Farben
    alias ls='eza --color=always --group-directories-first -x --no-permissions'
    alias ll='eza -l --color=always --group-directories-first --git -h --time-style=long-iso --no-user --no-filesize'
    alias la='eza -la --color=always --group-directories-first --git -h'
    alias lt='eza --tree --color=always --group-directories-first -L 2'
    
    # Debug Info
    echo "Terminal Setup:"
    echo "TERM=$TERM"
    echo "LANG=$LANG"
    echo "EZA Version:"
    eza --version
    
    # Git mit Delta
    git config --global core.pager "${pkgs.delta}/bin/delta"
    git config --global delta.navigate true
    git config --global delta.light false
  '';
}