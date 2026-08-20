{
  enable = false;
  _version = "2.0.0";

  swarm = null; # "manager" | "worker" | null

  catalog = {
    repoUrl = "https://github.com/fr4iser90/NCC-HomeLab.git";
    ref = "main";
    installRoot = "";
  };

  # Examples: [ "homelab-core" ] or [ "compute-llm-arm" ]
  profiles = [];

  stacks = [];
}
