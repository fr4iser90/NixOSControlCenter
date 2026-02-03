{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.integrations.salesforce or {};
in
{
  options.services.chronicle.integrations.salesforce = {
    enable = mkEnableOption "Salesforce integration";

    instance = mkOption {
      type = types.str;
      default = "login.salesforce.com";
      description = "Salesforce instance URL";
    };

    authentication = mkOption {
      type = types.submodule {
        options = {
          clientIdFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing OAuth2 client ID (Connected App)";
          };

          clientSecretFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing OAuth2 client secret";
          };

          usernameFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing Salesforce username";
          };

          passwordFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to file containing Salesforce password + security token";
          };
        };
      };
      default = {};
      description = "Authentication configuration";
    };

    case = mkOption {
      type = types.submodule {
        options = {
          autoCreate = mkOption {
            type = types.bool;
            default = false;
            description = "Automatically create cases from sessions";
          };

          defaultPriority = mkOption {
            type = types.enum [ "High" "Medium" "Low" ];
            default = "Medium";
            description = "Default case priority";
          };

          defaultOrigin = mkOption {
            type = types.str;
            default = "Step Recorder";
            description = "Default case origin";
          };

          defaultType = mkOption {
            type = types.str;
            default = "Problem";
            description = "Default case type";
          };
        };
      };
      default = {};
      description = "Case creation configuration";
    };

    chatter = mkOption {
      type = types.submodule {
        options = {
          enablePosts = mkOption {
            type = types.bool;
            default = true;
            description = "Post session summaries to Chatter";
          };

          mentionUsers = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of Salesforce user IDs to mention in posts";
          };
        };
      };
      default = {};
      description = "Chatter integration configuration";
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-salesforce" ''
        #!${pkgs.bash}/bin/bash
        
        # Set environment variables for Python
        export INSTANCE="${cfg.instance}"
        export PRIORITY="${cfg.case.defaultPriority}"
        export ORIGIN="${cfg.case.defaultOrigin}"
        export CASE_TYPE="${cfg.case.defaultType}"
        export ENABLE_CHATTER="${if cfg.chatter.enablePosts then "True" else "False"}"
        export MENTION_USERS="${builtins.toJSON cfg.chatter.mentionUsers}"
        
        ${pkgs.python3}/bin/python3 ${./salesforce.py} "$@"
      '')
    ];
  };
}
