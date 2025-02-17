{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;

  setupUserCreds = user: ''
    # Path to user's home directory and .creds file
    USER_HOME="/home/${user}"
    CREDS_FILE="$USER_HOME/.creds"

    # Create home directory if it doesn't exist
    [[ -d "$USER_HOME" ]] || { mkdir -p "$USER_HOME"; chown ${user}:${user} "$USER_HOME"; chmod 700 "$USER_HOME"; }

    # Create .creds file if it doesn't exist
    [[ -f "$CREDS_FILE" ]] || { touch "$CREDS_FILE"; chown ${user}:${user} "$CREDS_FILE"; chmod 600 "$CREDS_FILE"; }
  '';
in {
  config = {
    system.activationScripts.sshManagerSetup = let
      configuredUsers = lib.attrNames systemConfig.users;
    in ''
      # Erstelle .creds für konfigurierte Benutzer
      ${lib.concatMapStrings setupUserCreds configuredUsers}
    '';
  };
}
