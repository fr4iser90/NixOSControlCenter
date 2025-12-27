{
  pkgs ? (
    let
      inherit (builtins) fetchTree fromJSON readFile;
      inherit ((fromJSON (readFile ./flake.lock)) or ((fromJSON ../flake.lock).nodes) or {}) nixpkgs gomod2nix;
    in
      import (fetchTree nixpkgs.locked) {
        overlays = [
          (import "${fetchTree gomod2nix.locked}/overlay.nix")
        ];
      }
  ),
  mkGoEnv ? pkgs.mkGoEnv,
  gomod2nix ? pkgs.gomod2nix,
}:

pkgs.mkShell {
  packages = with pkgs; [
    go_1_25
    gopls
    gotools
    go-tools
    gomod2nix
  ];

  shellHook = ''
    echo "TUI Engine Development Environment"
    echo "Go version: $(go version)"
    echo ""
    echo "Available commands:"
    echo "  gomod2nix                    - Generate gomod2nix.toml"
    echo "  go run src/main.go          - Run the TUI"
    echo "  go build -o tui-engine      - Build the binary"
  '';
}
