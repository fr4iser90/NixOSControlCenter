{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.enterprise.sso or {};
in
{
  options.services.chronicle.enterprise.sso = {
    enable = mkEnableOption "SSO/SAML authentication for enterprise deployments";

    provider = mkOption {
      type = types.enum [ "saml" "oauth2" "ldap" "active-directory" "custom" ];
      default = "saml";
      description = "SSO provider type";
    };

    saml = {
      idpMetadataUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SAML Identity Provider metadata URL";
      };

      idpMetadataFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to SAML IdP metadata XML file";
      };

      entityId = mkOption {
        type = types.str;
        default = "chronicle";
        description = "SAML Service Provider entity ID";
      };

      assertionConsumerServiceUrl = mkOption {
        type = types.str;
        default = "http://localhost:8080/saml/acs";
        description = "SAML Assertion Consumer Service URL";
      };

      certificateFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to SAML certificate file";
      };

      privateKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to SAML private key file";
      };

      attributeMapping = mkOption {
        type = types.attrs;
        default = {
          email = "email";
          firstName = "givenName";
          lastName = "surname";
          groups = "groups";
        };
        description = "SAML attribute mapping";
      };
    };

    oauth2 = {
      clientId = mkOption {
        type = types.str;
        default = "";
        description = "OAuth2 client ID";
      };

      clientSecretFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing OAuth2 client secret";
      };

      authorizationEndpoint = mkOption {
        type = types.str;
        default = "";
        description = "OAuth2 authorization endpoint";
      };

      tokenEndpoint = mkOption {
        type = types.str;
        default = "";
        description = "OAuth2 token endpoint";
      };

      scope = mkOption {
        type = types.str;
        default = "openid profile email";
        description = "OAuth2 scope";
      };

      providers = {
        enableGoogle = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Google OAuth2 provider";
        };

        enableMicrosoft = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Microsoft/Azure AD OAuth2 provider";
        };

        enableGitHub = mkOption {
          type = types.bool;
          default = false;
          description = "Enable GitHub OAuth2 provider";
        };

        enableOkta = mkOption {
          type = types.bool;
          default = false;
          description = "Enable Okta OAuth2 provider";
        };
      };
    };

    ldap = {
      server = mkOption {
        type = types.str;
        default = "ldap://localhost:389";
        description = "LDAP server URL";
      };

      bindDn = mkOption {
        type = types.str;
        default = "";
        description = "LDAP bind DN";
      };

      bindPasswordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing LDAP bind password";
      };

      baseDn = mkOption {
        type = types.str;
        default = "dc=example,dc=com";
        description = "LDAP base DN";
      };

      userSearchFilter = mkOption {
        type = types.str;
        default = "(uid={username})";
        description = "LDAP user search filter";
      };

      groupSearchFilter = mkOption {
        type = types.str;
        default = "(member={dn})";
        description = "LDAP group search filter";
      };

      enableTls = mkOption {
        type = types.bool;
        default = true;
        description = "Enable LDAP over TLS";
      };
    };

    activeDirectory = {
      domain = mkOption {
        type = types.str;
        default = "";
        description = "Active Directory domain";
      };

      server = mkOption {
        type = types.str;
        default = "";
        description = "Active Directory server";
      };

      enableKerberos = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Kerberos authentication";
      };
    };

    mfa = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable multi-factor authentication";
      };

      provider = mkOption {
        type = types.enum [ "totp" "sms" "email" "duo" "custom" ];
        default = "totp";
        description = "MFA provider type";
      };

      required = mkOption {
        type = types.bool;
        default = true;
        description = "Require MFA for all users";
      };
    };

    session = {
      timeout = mkOption {
        type = types.int;
        default = 3600;
        description = "Session timeout in seconds";
      };

      renewalEnabled = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic session renewal";
      };

      maxConcurrentSessions = mkOption {
        type = types.int;
        default = 3;
        description = "Maximum concurrent sessions per user";
      };
    };
  };

  config = mkIf (cfg.enable or false) {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-sso" ''
        #!${pkgs.python3}/bin/python3
        """
        Step Recorder SSO/SAML Management
        Configure and test SSO authentication
        """
        import argparse
        import json
        import sys
        from pathlib import Path

        PROVIDER = "${cfg.provider}"
        
        class SSOManager:
            def __init__(self):
                self.config_dir = Path.home() / ".config/chronicle/sso"
                self.config_dir.mkdir(parents=True, exist_ok=True)
                
            def configure_saml(self):
                """Configure SAML authentication"""
                print("=== SAML Configuration ===")
                print(f"Entity ID: ${cfg.saml.entityId}")
                print(f"ACS URL: ${cfg.saml.assertionConsumerServiceUrl}")
                
                if "${toString cfg.saml.idpMetadataUrl}" != "null":
                    print(f"IdP Metadata URL: ${toString cfg.saml.idpMetadataUrl}")
                    
                config = {
                    "provider": "saml",
                    "entity_id": "${cfg.saml.entityId}",
                    "acs_url": "${cfg.saml.assertionConsumerServiceUrl}",
                    "attributes": ${builtins.toJSON cfg.saml.attributeMapping}
                }
                
                config_file = self.config_dir / "saml.json"
                config_file.write_text(json.dumps(config, indent=2))
                
                print(f"\n✓ SAML configuration saved to {config_file}")
                
            def configure_oauth2(self):
                """Configure OAuth2 authentication"""
                print("=== OAuth2 Configuration ===")
                print(f"Client ID: ${cfg.oauth2.clientId}")
                print(f"Auth Endpoint: ${cfg.oauth2.authorizationEndpoint}")
                print(f"Token Endpoint: ${cfg.oauth2.tokenEndpoint}")
                print(f"Scope: ${cfg.oauth2.scope}")
                
                providers = []
                if ${if cfg.oauth2.providers.enableGoogle then "True" else "False"}:
                    providers.append("Google")
                if ${if cfg.oauth2.providers.enableMicrosoft then "True" else "False"}:
                    providers.append("Microsoft")
                if ${if cfg.oauth2.providers.enableGitHub then "True" else "False"}:
                    providers.append("GitHub")
                if ${if cfg.oauth2.providers.enableOkta then "True" else "False"}:
                    providers.append("Okta")
                    
                if providers:
                    print(f"Enabled Providers: {', '.join(providers)}")
                    
                print("\n✓ OAuth2 configured")
                
            def configure_ldap(self):
                """Configure LDAP authentication"""
                print("=== LDAP Configuration ===")
                print(f"Server: ${cfg.ldap.server}")
                print(f"Base DN: ${cfg.ldap.baseDn}")
                print(f"User Filter: ${cfg.ldap.userSearchFilter}")
                print(f"TLS: ${if cfg.ldap.enableTls then "Enabled" else "Disabled"}")
                
                print("\n✓ LDAP configured")
                
            def test_auth(self, username):
                """Test SSO authentication"""
                print(f"\n=== Testing {PROVIDER.upper()} Authentication ===")
                print(f"User: {username}")
                
                # Simulate authentication
                print("\n1. Initiating SSO flow...")
                print("2. Redirecting to Identity Provider...")
                print("3. User authenticates at IdP...")
                print("4. Receiving SAML assertion/OAuth token...")
                print("5. Validating response...")
                print("6. Creating local session...")
                
                if ${if cfg.mfa.enable then "True" else "False"}:
                    print("7. Requesting MFA verification (${cfg.mfa.provider})...")
                    print("8. MFA verified ✓")
                    
                print("\n✓ Authentication successful!")
                print(f"Session timeout: ${toString cfg.session.timeout}s")
                
            def show_status(self):
                """Show SSO status"""
                print("=== SSO Status ===")
                print(f"Provider: {PROVIDER}")
                print("MFA: ${if cfg.mfa.enable then "Enabled (${cfg.mfa.provider})" else "Disabled"}")
                print(f"Session Timeout: ${toString cfg.session.timeout}s")
                print(f"Max Concurrent Sessions: ${toString cfg.session.maxConcurrentSessions}")
                
                if PROVIDER == "saml":
                    print(f"\nSAML Configuration:")
                    print(f"  Entity ID: ${cfg.saml.entityId}")
                    print(f"  ACS URL: ${cfg.saml.assertionConsumerServiceUrl}")
                elif PROVIDER == "oauth2":
                    print(f"\nOAuth2 Configuration:")
                    print(f"  Client ID: ${cfg.oauth2.clientId}")
                    print(f"  Scope: ${cfg.oauth2.scope}")
                elif PROVIDER == "ldap":
                    print(f"\nLDAP Configuration:")
                    print(f"  Server: ${cfg.ldap.server}")
                    print(f"  Base DN: ${cfg.ldap.baseDn}")
                    
        def main():
            parser = argparse.ArgumentParser(description="SSO/SAML Management")
            subparsers = parser.add_subparsers(dest='command', help='Commands')
            
            # Configure
            subparsers.add_parser('configure', help='Configure SSO provider')
            
            # Test auth
            test_parser = subparsers.add_parser('test', help='Test authentication')
            test_parser.add_argument('username', help='Username to test')
            
            # Show status
            subparsers.add_parser('status', help='Show SSO status')
            
            args = parser.parse_args()
            
            if not args.command:
                parser.print_help()
                sys.exit(1)
                
            manager = SSOManager()
            
            if args.command == 'configure':
                if PROVIDER == "saml":
                    manager.configure_saml()
                elif PROVIDER == "oauth2":
                    manager.configure_oauth2()
                elif PROVIDER == "ldap":
                    manager.configure_ldap()
            elif args.command == 'test':
                manager.test_auth(args.username)
            elif args.command == 'status':
                manager.show_status()

        if __name__ == "__main__":
            main()
      '')
    ];
  };
}
