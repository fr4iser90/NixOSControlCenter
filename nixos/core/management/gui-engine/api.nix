# GUI Engine API — getModuleApi "gui-engine"
# Peer module paths via getModuleMetadata — never relative ../../other-module
# Domain pages: always pass `config` so guiPages from cli-registry are aggregated.
{ lib, metadata, getModuleMetadata }:

let
  packagesRoot = (getModuleMetadata "packages").path;
  assistantRoot = (getModuleMetadata "ncc-assistant").path;
  cliMeta = getModuleMetadata "cli-registry";
  cliApi = import "${cliMeta.path}/api.nix" {
    inherit lib getModuleMetadata;
    metadata = cliMeta;
  };
in
{
  package = pkgs: import ./package.nix { inherit pkgs; };

  disabledHint = import ./lib/disabled-hint.nix;

  # Mirror tui-engine: null = auto from desktop.enable (GUI on when desktop on).
  isEnabled = getModuleConfig:
    let
      gui = getModuleConfig "gui-engine";
      desktop = getModuleConfig "desktop";
      raw = gui.enable or null;
      desktopEnable = desktop.enable or null;
    in
      if raw != null then raw
      else if desktopEnable == null then false
      else desktopEnable;

  # domainGui pkgs config — includes every registerGuiPage from modules
  domainGui = pkgs: config:
    (import ./domain-gui.nix {
      inherit pkgs lib getModuleMetadata packagesRoot assistantRoot;
      guiPages = cliApi.guiPages config;
    }).nccDomainGui;

  rootGui = pkgs: config:
    (import ./root-gui.nix {
      inherit pkgs lib getModuleMetadata packagesRoot;
      guiPages = cliApi.guiPages config;
    }).nccGui;

  domainGuiBundle = pkgs: config:
    import ./domain-gui.nix {
      inherit pkgs lib getModuleMetadata packagesRoot assistantRoot;
      guiPages = cliApi.guiPages config;
    };
}
