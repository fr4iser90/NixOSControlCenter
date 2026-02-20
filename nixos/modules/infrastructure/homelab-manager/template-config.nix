{
  enable = false;        # Enable homelab manager
  swarm = null;         # Swarm mode: "manager" | "worker" | null (single-server)

  stacks = [
    # Example stack configuration
    # {
    #   name = "my-homelab";
    #   compose = "/path/to/docker-compose.yml";
    #   env = "/path/to/.env";  # optional
    #   directory = "/opt/homelab/my-homelab";  # optional
    #   network = "homelab-net";  # optional
    #   volumes = [ ];  # optional
    # }
  ];
}
