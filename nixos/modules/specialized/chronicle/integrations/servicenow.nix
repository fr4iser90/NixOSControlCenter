{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.integrations.servicenow or {};
in
{
  options.services.chronicle.integrations.servicenow = {
    enable = mkEnableOption "ServiceNow integration";

    instance = mkOption {
      type = types.str;
      default = "";
      description = "ServiceNow instance URL (e.g., company.service-now.com)";
    };

    authentication = mkOption {
      type = types.submodule {
        options = {
          method = mkOption {
            type = types.enum [ "basic" "oauth2" "api-key" ];
            default = "oauth2";
            description = "Authentication method";
          };

          username = mkOption {
            type = types.str;
            default = "";
            description = "ServiceNow username (for basic auth)";
          };

          passwordFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing password";
          };

          clientIdFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing OAuth2 client ID";
          };

          clientSecretFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing OAuth2 client secret";
          };
        };
      };
      default = {};
      description = "Authentication configuration";
    };

    incident = mkOption {
      type = types.submodule {
        options = {
          autoCreate = mkOption {
            type = types.bool;
            default = false;
            description = "Automatically create incidents from sessions";
          };

          defaultPriority = mkOption {
            type = types.enum [ "1" "2" "3" "4" "5" ];
            default = "3";
            description = "Default incident priority (1=Critical, 5=Planning)";
          };

          defaultCategory = mkOption {
            type = types.str;
            default = "software";
            description = "Default incident category";
          };

          assignmentGroup = mkOption {
            type = types.str;
            default = "";
            description = "Default assignment group";
          };
        };
      };
      default = {};
      description = "Incident creation configuration";
    };

    attachments = mkOption {
      type = types.submodule {
        options = {
          includeScreenshots = mkOption {
            type = types.bool;
            default = true;
            description = "Attach screenshots to incidents";
          };

          includeVideo = mkOption {
            type = types.bool;
            default = false;
            description = "Attach video recordings to incidents";
          };

          includeLogs = mkOption {
            type = types.bool;
            default = true;
            description = "Attach system logs to incidents";
          };
        };
      };
      default = {};
      description = "Attachment configuration";
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-servicenow" ''
        #!${pkgs.bash}/bin/bash
        
        # Set environment variables for Python
        export INSTANCE="${cfg.instance}"
        export AUTH_METHOD="${cfg.authentication.method}"
        export PRIORITY="${cfg.incident.defaultPriority}"
        export CATEGORY="${cfg.incident.defaultCategory}"
        export ASSIGNMENT_GROUP="${cfg.incident.assignmentGroup}"
        export INCLUDE_SCREENSHOTS="${if cfg.attachments.includeScreenshots then "True" else "False"}"
        export INCLUDE_LOGS="${if cfg.attachments.includeLogs then "True" else "False"}"
        
        ${pkgs.python3}/bin/python3 ${./servicenow.py} "$@"
      '')
    ];
  };
}
