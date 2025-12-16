{
  # Network System Configuration
  system = {
    network = {
      enable = true;
      # NetworkManager DNS configuration
      networkManager = {
        dns = "default";  # Options: "default", "systemd-resolved", "none"
      };

      # Networking services for firewall rules
      networking = {
        services = {
          # Service configurations would go here
          # Each service can have: exposure = "local"|"public", port, protocol, etc.
        };

        firewall = {
          trustedNetworks = [
            # Add trusted networks here, e.g.:
            # "192.168.1.0/24"
            # "10.0.0.0/8"
          ];
        };
      };
    };
  };
}
