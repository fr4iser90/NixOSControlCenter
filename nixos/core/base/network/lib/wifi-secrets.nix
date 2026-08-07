# Build wifi.networks entries from /etc/nixos/secrets/wifi/*.psk (eval-time, headless-safe)
{ lib }:

let
  secretsPath = "/etc/nixos/secrets/wifi";
  pathExists = builtins.pathExists secretsPath;
  entries = if pathExists then builtins.readDir secretsPath else { };
  pskFiles = lib.filterAttrs (n: _: lib.hasSuffix ".psk" n) entries;
in
lib.mapAttrs' (filename: _: {
    name = lib.removeSuffix ".psk" filename;
    value = {
      ssid = lib.removeSuffix ".psk" filename;
      pskFile = "${secretsPath}/${filename}";
      autoconnect = true;
    };
}) pskFiles
