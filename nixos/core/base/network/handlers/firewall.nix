{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  recommendations = import ../processors/services.nix;
  rules = import ../lib/rules.nix { inherit lib; };

  networkCfg = getModuleConfig "network";
  pkgCfg = getModuleConfig "packages";
  configuredServices = lib.attrByPath ["services"] {} networkCfg;

  dockerOn =
    (pkgCfg.docker.enable or false)
    || lib.elem "docker" (pkgCfg.packageModules or [])
    || lib.elem "docker-rootless" (pkgCfg.packageModules or []);

  # Anti-lockout: if OpenSSH is on but network.services.ssh is unset, open
  # port 22 publicly (VPS). Override with network.services.ssh.exposure = "local".
  # Homelab/Traefik: Docker hosts need 80/443 public for the reverse proxy.
  # Catalog key is `nginx` (same ports). Override with network.services.nginx.exposure = "local".
  services =
    configuredServices
    // lib.optionalAttrs ((config.services.openssh.enable or false) && !(configuredServices ? ssh)) {
      ssh = { exposure = "public"; };
    }
    // lib.optionalAttrs (dockerOn && !(configuredServices ? nginx)) {
      nginx = { exposure = "public"; };
    };

  firewallEnabled = lib.attrByPath ["firewall" "enable"] true networkCfg;

  # Only services explicitly listed in network.services (plus ssh anti-lockout),
  # and only if we have a recommendation entry — never apply the whole catalog.
  activeServiceNames = builtins.filter (name: recommendations ? ${name}) (builtins.attrNames services);

  exposureOf = name:
    let
      userCfg = services.${name};
      svcRec = recommendations.${name};
    in userCfg.exposure or svcRec.recommended or "local";

  publicNames = builtins.filter (n: exposureOf n == "public") activeServiceNames;
  localNames = builtins.filter (n: exposureOf n != "public") activeServiceNames;

  publicTcpPorts = lib.unique (lib.concatLists (map (n: recommendations.${n}.ports.tcp or []) publicNames));
  publicUdpPorts = lib.unique (lib.concatLists (map (n: recommendations.${n}.ports.udp or []) publicNames));

  # Local rules must not DROP ports already opened publicly (e.g. pihole:80 vs nginx:80).
  localRecFiltered = name:
    let
      svcRec = recommendations.${name};
      tcp = builtins.filter (p: !(lib.elem p publicTcpPorts)) (svcRec.ports.tcp or []);
      udp = builtins.filter (p: !(lib.elem p publicUdpPorts)) (svcRec.ports.udp or []);
    in svcRec // { ports = { inherit tcp udp; }; };

  isPubliclyExposed = cfg: (cfg.exposure or "local") == "public";

in {
  networking.firewall = lib.mkMerge [
    {
      enable = firewallEnabled;
    }
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

        # Public first, then local (local skips ports already public).
        ${lib.concatMapStrings (service:
          rules.generateServiceRules service recommendations.${service} (services.${service} or {})
        ) publicNames}

        ${lib.concatMapStrings (service:
          rules.generateServiceRules service (localRecFiltered service) (services.${service} or {})
        ) localNames}

        ${lib.concatMapStrings (net: ''
          iptables -A INPUT -s ${net} -j ACCEPT
        '') (lib.attrByPath ["firewall" "trustedNetworks"] [] networkCfg)}
      '';
    })
  ];

  warnings = lib.flatten (lib.filter (w: w != null) (map (service:
    let
      svcRec = recommendations.${service};
      userCfg = services.${service} or {};
    in
    if isPubliclyExposed userCfg && (svcRec.recommended or "local") == "local"
    then "Warning: ${service} is exposed publicly but recommended to be local only (${svcRec.reason or "security risk"})"
    else null
  ) activeServiceNames));
}
