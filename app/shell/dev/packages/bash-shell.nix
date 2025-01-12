{ pkgs }:

with pkgs; [
  # Shell Basics
  bash-completion
  fzf
  direnv
  
  # Syntax Highlighting & Tools
  less            
  bat             
  eza             
  delta           
  sourceHighlight
  autojump
  
  # Entwickler Tools
  ripgrep         
  fd              
  jq              
  shellcheck      
  
  # Zusätzliche notwendige Pakete
  coreutils               
  gawk            
  which           
  ncurses   
  fontconfig   
]