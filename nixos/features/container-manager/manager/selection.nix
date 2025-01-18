{ lib, ... }:

let
  # Default container manager
  defaultContainerManager = "docker";

  # Supported managers
  manager = if defaultContainerManager == "docker" then 
              import ./docker.nix
            else if defaultContainerManager == "oci-container" then 
              import ./oci-container
            else if defaultContainerManager == "podman" then 
              import ./podman.nix
            else 
              throw "Invalid container manager: ${defaultContainerManager}";
in

{
  # Define the option for the container manager
  options.containerManager.containerManager = lib.mkOption {
    type = lib.types.enum [ "docker" "podman" "oci-container" ];
    default = "podman";
    description = "Container manager to use";
  };

  config.containerManager.containerManager = defaultContainerManager;

  # Dynamically import the selected module
  imports = [
    # Here you import the dynamically selected module
#    manager
  ];
}
