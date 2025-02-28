{ pkgs }:
''
  # System Settings
  export NIXPKGS_ALLOW_UNFREE=1
  export NIX_REMOTE=daemon
  export NIX_SUDO_INCLUDED=1
  
  # Add nixos-rebuild to PATH if needed
  if ! command -v nixos-rebuild >/dev/null 2>&1; then
    export PATH="${pkgs.nixos-rebuild}/bin:$PATH"
  fi
''