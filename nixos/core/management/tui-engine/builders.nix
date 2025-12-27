{ lib, buildGoApplication, gomod2nix, pkgs }:

let
  # Build function using gomod2nix (from OptiNix pattern)
  buildTUIApp = { pname, version, src, go ? null }:
    buildGoApplication {
      inherit pname version src go;
      modules = ./gomod2nix.toml;
      nativeBuildInputs = with pkgs; [
        installShellFiles
      ];
      postInstall = ''
        installShellCompletion --cmd ${pname} \
          --bash <($out/bin/${pname} completion bash) \
          --fish <($out/bin/${pname} completion fish) \
          --zsh <($out/bin/${pname} completion zsh)
      '';
    };

in {
  inherit buildTUIApp;
}
