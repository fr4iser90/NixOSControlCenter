{ config, lib, pkgs, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  smRoot = (getModuleMetadata "system-manager").path;
  backupHelpers = import "${smRoot}/lib/backup-helpers.nix" { inherit pkgs lib; };

  grantAccessScript = pkgs.writeScriptBin "ssh-grant-access" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-grant-access.lock"
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    USER="$1"
    DURATION="$2"
    REASON="$3"

    if [ -z "$USER" ]; then
      ${ui.messages.error "Usage: ncc ssh grant-access USERNAME [DURATION] [REASON]"}
      ${ui.messages.info "Example: ncc ssh grant-access fr4iser 300 'Emergency access for key setup'"}
      exit 1
    fi

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "SSH grant-access"}
    fi

    DURATION=''${DURATION:-300}
    REASON=''${REASON:-"Direct admin grant"}

    ${ui.messages.loading "Granting temporary SSH password authentication for $USER…"}
    ${ui.tables.keyValue "User" "$USER"}
    ${ui.tables.keyValue "Duration" "$DURATION seconds"}
    ${ui.tables.keyValue "Reason" "$REASON"}

    ${backupHelpers.backupSSHConfig "/etc/ssh/sshd_config"} >/dev/null 2>&1 || true

    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
      sudo systemctl restart sshd

      if [ $? -eq 0 ]; then
        ${ui.messages.success "SSH password authentication enabled successfully"}
      else
        ${ui.messages.error "Failed to restart SSH service"}
        exit 1
      fi
    else
      ${ui.messages.info "Password authentication already enabled"}
    fi

    ${ui.messages.success "SSH password authentication granted for $USER for $DURATION seconds"}

    (
      sleep $DURATION
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      ${ui.messages.info "SSH password authentication disabled after $DURATION seconds"}
    ) &

    ${ui.messages.info "Auto-disable timer set for $DURATION seconds"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: connect as $USER with password, then wait for auto-disable (or ncc ssh lockdown)"}
    fi
  '';
in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ grantAccessScript ];
    }
    (cliRegistry.registerCommandsFor "ssh-server-grant-access" [
      {
        name = "grant-access";
        parent = "ssh";
        domain = "ssh";
        description = "Grant temporary SSH password authentication";
        category = "security";
        script = "${grantAccessScript}/bin/ssh-grant-access";
        arguments = [ "USERNAME" "[DURATION]" "[REASON]" ];
        dependencies = [ "openssh" ];
        shortHelp = "grant-access USERNAME [DURATION] [REASON] - Grant password auth directly";
        longHelp = ''
          Directly grants temporary SSH password authentication for a specified user.
          This bypasses the request/approval workflow for emergency situations.

          Arguments:
            USERNAME  - The username to grant access to
            DURATION  - Duration in seconds (optional, default: 300)
            REASON    - Reason for granting access (optional)

          Examples:
            ncc ssh grant-access fr4iser
            ncc ssh grant-access fr4iser 600 "Emergency server maintenance"
        '';
      }
    ])
  ];
}
