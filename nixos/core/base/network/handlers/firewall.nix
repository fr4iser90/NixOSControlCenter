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
  networking.firewall = lib.mkIf firewallEnabled {
    enable = true;
    allowPing = true;

    extraCommands = ''
      # Lösche existierende Regeln
      iptables -F

      # Standardregeln
      iptables -P INPUT DROP
      iptables -P FORWARD DROP
      iptables -P OUTPUT ACCEPT

      # Erlaube etablierte Verbindungen
      iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
      iptables -A INPUT -i lo -j ACCEPT

      # ICMP erlauben (für Ping)
      iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
      iptables -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

      # Service-spezifische Regeln
      ${lib.concatMapStrings (service: 
        rules.generateServiceRules service recommendations.${service} (services.${service} or {})
      ) (builtins.attrNames recommendations)}

      # Zusätzliche vertrauenswürdige Netze
      ${lib.concatMapStrings (net: ''
        iptables -A INPUT -s ${net} -j ACCEPT
      '') (lib.attrByPath ["firewall" "trustedNetworks"] [] networkCfg)}
    '';
  };

  # Warnungen für unsichere Konfigurationen
  warnings = lib.flatten (map (service:
    let
      cfg = recommendations.${service};
      userCfg = services.${service} or {};
    in
    if isPubliclyExposed userCfg && (cfg.recommended or "local") == "local"
    then [ "Warning: ${service} is exposed publicly but recommended to be local only (${cfg.reason or "security risk"})" ]
    else []
  ) (builtins.attrNames recommendations));
}