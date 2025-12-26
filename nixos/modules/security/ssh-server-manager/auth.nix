{ config, lib, pkgs, cfg, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";

  sshTempOpenScript = pkgs.writeScriptBin "ssh-temp-open" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-temp-open.lock"
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    USER="$1"
    if [ -z "$USER" ]; then
      ${ui.messages.error "Usage: ssh-temp-open USERNAME"}
      exit 1
    fi

    ${ui.messages.loading "Enabling temporary SSH password authentication..."}

    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
    fi

    ${ui.messages.success "SSH password authentication enabled for $USER for 60 seconds"}

    (
      sleep 60
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      ${ui.messages.info "SSH password authentication disabled"}
    ) &
  '';

  sshForceOpenScript = pkgs.writeScriptBin "ssh-force-open" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-force-open.lock"
    exec 200>$LOCKFILE
    flock -n 200 || { ${ui.messages.error "Another instance is running."}; exit 1; }

    USER="$1"
    if [ -z "$USER" ]; then
      ${ui.messages.error "Usage: ssh-force-open USERNAME"}
      exit 1
    fi

    ${ui.messages.loading "Enabling SSH password authentication..."}

    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
    fi

    ${ui.messages.success "SSH password authentication enabled until next login"}

    journalctl -f -u sshd | while read -r line; do
      if echo "$line" | grep -q "Accepted password for $USER"; then
        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo systemctl restart sshd
        ${ui.messages.info "SSH password authentication disabled after login"}
        break
      fi
    done
  '';
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      sshTempOpenScript
      sshForceOpenScript
    ];

    config = lib.mkMerge [
      cliRegistry.registerCommandsFor "ssh-server-auth" [
      {
        name = "ssh-temp-open";
        description = "Temporarily enable SSH password authentication";
        category = "security";
        script = "${sshTempOpenScript}/bin/ssh-temp-open";
        arguments = [ "USERNAME" ];
        dependencies = [ "openssh" ];
        shortHelp = "ssh-temp-open USERNAME - Enable password auth for 60 seconds";
        longHelp = ''
          Temporarily enables SSH password authentication for 60 seconds to allow
          a single login. Useful for emergency access or initial setup.
        '';
      }
      {
        name = "ssh-force-open";
        description = "Enable SSH password auth until next login";
        category = "security";
        script = "${sshForceOpenScript}/bin/ssh-force-open";
        arguments = [ "USERNAME" ];
        dependencies = [ "openssh" ];
        shortHelp = "ssh-force-open USERNAME - Enable password auth until next login";
        longHelp = ''
          Enables SSH password authentication until the next successful login,
          then automatically disables it. Useful for one-time access.
        '';
      }
      ])
    ];
  };
}
