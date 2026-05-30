{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  recommendations = import ../processors/services.nix;
  rules = import ../lib/rules.nix { inherit lib; };
  
  # Service-Konfigurationen aus systemConfig.nix
  services = lib.attrByPath ["services"] {} (getModuleConfig "network");
  
  # Firewall-Config lesen
  networkCfg = getModuleConfig "network";
  firewallEnabled = lib.attrByPath ["firewall" "enable"] true networkCfg;

  # Helper für sicheres Prüfen der Exposure
  isPubliclyExposed = cfg:
    (cfg.exposure or "local") == "public";

in {
  # Firewall-Konfiguration mit explizitem enable-Status
  networking.firewall = lib.mkMerge [
    # Firewall-Status IMMER explizit setzen (auch wenn false)
    {
      enable = firewallEnabled;
    }
    # Rest der Firewall-Konfiguration nur wenn aktiviert
    (lib.mkIf firewallEnabled {
      allowPing = true;

      extraCommands = ''
        # Nur INPUT leeren — kein globales iptables -F: das würde Docker-Ketten
        # (DOCKER, DOCKER-USER, FORWARD-Sprünge) leeren und Bridge-Traffic brechen.
        iptables -F INPUT

        iptables -P INPUT DROP
        # FORWARD muss für Docker/Podman-Bridge (Container↔Container) durchlassen;
        # leere FORWARD-Kette + Policy DROP = TCP-Timeouts zwischen Containern.
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT

        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A INPUT -i lo -j ACCEPT

        iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
        iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

        ${lib.concatMapStrings (service:
          rules.generateServiceRules service recommendations.${service} (services.${service} or {})
        ) (builtins.attrNames recommendations)}

        ${lib.concatMapStrings (net: ''
          iptables -A INPUT -s ${net} -j ACCEPT
        '') (lib.attrByPath ["firewall" "trustedNetworks"] [] networkCfg)}
      '';
    })
  ];

  # Warnungen für unsichere Konfigurationen
  warnings = lib.flatten (lib.filter (w: w != null) (map (service:
    let
      cfg = recommendations.${service};
      userCfg = services.${service} or {};
    in
    if isPubliclyExposed userCfg && (cfg.recommended or "local") == "local"
    then "Warning: ${service} is exposed publicly but recommended to be local only (${cfg.reason or "security risk"})"
    else null
  ) (builtins.attrNames recommendations)));
}