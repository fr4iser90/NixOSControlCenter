{ config, pkgs, ... }:

let
  env = import ../../env.nix;
  requirePassword = env.sudo.requirePassword or true;
  timeout = env.sudo.timeout or 15;
in
{
  security.sudo = {
    enable = true;
    extraRules = [
      {
        users = [ env.mainUser ];
        commands = [
          {
            command = "ALL";
            options = 
              if requirePassword 
              then [ "PASSWD" "TIMESTAMP_TIMEOUT=${toString timeout}" ]
              else [ "NOPASSWD" ];
          }
        ];
      }
    ];
    
    extraConfig = ''
      Defaults secure_path="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/run/current-system/sw/bin:/run/current-system/sw/sbin"
      Defaults env_keep += "NIX_PATH NIX_PROFILES NIX_REMOTE NIX_SSL_CERT_FILE"
      Defaults timestamp_timeout=${toString timeout}
      Defaults lecture=once
    '';
  };
}