# modules/networking/lib/rules.nix
{ lib, ... }:

{
  # Generiere Firewall-Regeln für Services
  generateServiceRules = service: cfg: userCfg:
    let
      exposure = userCfg.exposure or cfg.recommended;
    in ''
      # Regeln für ${service}
      ${lib.concatMapStrings (port: ''
        ${if exposure == "local" then ''
          # Lokaler Zugriff für ${service} TCP/${toString port}
          iptables -A INPUT -p tcp --dport ${toString port} -i lo -j ACCEPT
          iptables -A INPUT -p tcp --dport ${toString port} -s 10.0.0.0/8 -j ACCEPT
          iptables -A INPUT -p tcp --dport ${toString port} -s 172.16.0.0/12 -j ACCEPT
          iptables -A INPUT -p tcp --dport ${toString port} -s 192.168.0.0/16 -j ACCEPT
          iptables -A INPUT -p tcp --dport ${toString port} -j DROP
        '' else ''
          # Öffentlicher Zugriff für ${service} TCP/${toString port}
          iptables -A INPUT -p tcp --dport ${toString port} -j ACCEPT
        ''}
      '') cfg.ports.tcp}
      
      ${lib.concatMapStrings (port: ''
        ${if exposure == "local" then ''
          # Lokaler Zugriff für ${service} UDP/${toString port}
          iptables -A INPUT -p udp --dport ${toString port} -i lo -j ACCEPT
          iptables -A INPUT -p udp --dport ${toString port} -s 10.0.0.0/8 -j ACCEPT
          iptables -A INPUT -p udp --dport ${toString port} -s 172.16.0.0/12 -j ACCEPT
          iptables -A INPUT -p udp --dport ${toString port} -s 192.168.0.0/16 -j ACCEPT
          iptables -A INPUT -p udp --dport ${toString port} -j DROP
        '' else ''
          # Öffentlicher Zugriff für ${service} UDP/${toString port}
          iptables -A INPUT -p udp --dport ${toString port} -j ACCEPT
        ''}
      '') cfg.ports.udp}
    '';
}