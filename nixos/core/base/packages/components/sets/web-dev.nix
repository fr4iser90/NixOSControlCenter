# Web / JS toolchain for development (system set).
# Production nginx/postgres → database / web-server sets.
# Personal IDE stacks → user presets (scope = "user").
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nodejs
    yarn
    pnpm
    deno
    vscode
    httpie
    sqlite
    sass
    eslint
    chromium
  ];

  environment.variables = {
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = "${pkgs.chromium}/bin/chromium";
  };
}
