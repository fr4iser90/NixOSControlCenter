{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;
  cfg = getModuleConfig moduleName;
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  
  # SSH Status Display Script
  sshStatusScript = pkgs.writeShellScriptBin "ncc-ssh-status" ''
    #!/usr/bin/env bash
    
    # Header
    echo "${ui.text.header "SSH Status"}"
    
    # Password Auth
    if ${lib.optionalString (config.services.openssh.settings.PasswordAuthentication or false) "true" "false"}; then
      echo "${ui.tables.keyValue "Password Auth" "Enabled"}"
    else
      echo "${ui.tables.keyValue "Password Auth" "Disabled"}"
    fi
    
    # Active Sessions
    SESSIONS=$(ss -tn state established '( dport = :ssh )' | wc -l)
    echo "${ui.tables.keyValue "Active Sessions" "$SESSIONS"}"
    
    # Client Alive Interval
    echo "${ui.tables.keyValue "Client Alive Interval" "${toString (config.services.openssh.settings.ClientAliveInterval or 0)}"}"
    
    # Client Alive Count Max
    echo "${ui.tables.keyValue "Client Alive Count Max" "${toString (config.services.openssh.settings.ClientAliveCountMax or 0)}"}"
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or false)
      (cliRegistry.registerCommandsFor "ssh-server-manager" [
        {
          name = "ssh-status";
          script = "${sshStatusScript}/bin/ncc-ssh-status";
          description = "Show SSH server status and configuration";
          category = "security";
          arguments = [];
          dependencies = [ "ss" ];
          shortHelp = "ssh-status - Show SSH server status";
          longHelp = ''
            Display SSH server status including:
            - Password authentication status
            - Active SSH sessions
            - Client alive settings
            
            Usage: ncc ssh-status
          '';
        }
      ])
    )
  ];
}
