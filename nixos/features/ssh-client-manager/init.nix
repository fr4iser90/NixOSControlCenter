{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;

  setupUserCreds = user: ''
    # Path to user's home directory and .creds file
    USER_HOME="/home/${user}"
    CREDS_FILE="$USER_HOME/.creds"

    # Create home directory if it doesn't exist
    if [[ ! -d "$USER_HOME" ]]; then
      echo "Creating home directory for user ${user}..."
      mkdir -p "$USER_HOME"
      chown ${user}:${user} "$USER_HOME"
      chmod 700 "$USER_HOME"
    fi

    # Create .creds file if it doesn't exist
    if [[ ! -f "$CREDS_FILE" ]]; then
      echo "Creating .creds file for user ${user}..."
      touch "$CREDS_FILE"
      chown ${user}:${user} "$CREDS_FILE"
      chmod 600 "$CREDS_FILE"
      echo "Credentials file created at $CREDS_FILE"
    else
      echo "Credentials file already exists for user ${user}."
    fi
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