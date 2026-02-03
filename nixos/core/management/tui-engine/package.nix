{ lib, getModuleApi, pkgs, buildGoApplication, gomod2nix, ... }:

let
  # Build function using gomod2nix (from OptiNix pattern)
  buildTUIApp = { pname, version, src, go ? null }:
    buildGoApplication {
      inherit pname version src go;
      modules = ./gomod2nix.toml;
      subPackages = [ "." ];
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
in
{

  # Define the module-manager-tui package
  environment.systemPackages = [
    jq 
    (buildTUIApp {
      pname = "module-manager-tui";
      version = "1.0.0";
      src = ./.;
    })
  ];
}
