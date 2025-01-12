# /etc/nixos/modules/homemanager/shellInit/bashInit.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    bash
    bash-completion
    fzf
    blesh
  ];

  programs.bash = {
    enable = true;
    initExtra = ''
      # Load ble.sh before setting up prompts
      if [ -f ${pkgs.blesh}/share/blesh/ble.sh ]; then
        source ${pkgs.blesh}/share/blesh/ble.sh --noattach
        # Initialize ble.sh with specific options for better stability
        [[ ''${BASH_VERSION-} ]] && ble-attach --noattach-stdio

        # Configure ble.sh to be less verbose with errors
        bleopt exec_errexit_mark=
        bleopt exec_exit_mark=
      fi

      # Ensure clean prompt handling
      [[ ! -v BLE_VERSION ]] && export PS1="\[\033[01;34m\]\w\[\033[00m\] > "

      # History configuration
      export HISTSIZE=10000
      export HISTFILESIZE=20000
      shopt -s histappend
      export PROMPT_COMMAND="history -a"

      # Enable bash completion for paths
      shopt -s direxpand
      shopt -s dirspell
      shopt -s cdspell

      # Colorful grep output
      alias grep='grep --color=auto'

      # Some useful aliases
      alias ll='ls -lah'
      alias la='ls -A'
      alias l='ls -CF'

      # Direnv if installed
      if command -v direnv >/dev/null 2>&1; then
        eval "$(direnv hook bash)"
      fi
    '';

    # Proper way to enable bash completion in NixOS
    enableCompletion = true;

    # Proper way to handle git prompt in NixOS
    bashrcExtra = ''
      if [ -f ${pkgs.git}/share/bash-completion/completions/git-prompt.sh ]; then
        source ${pkgs.git}/share/bash-completion/completions/git-prompt.sh
        # Set PS1 only if ble.sh is not active
        if [[ ! -v BLE_VERSION ]]; then
          export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]$(__git_ps1 " (%s)") > '
        fi
      fi
    '';
  };
}
