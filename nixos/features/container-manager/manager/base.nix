{
  config, pkgs, lib, systemConfig, ... 
}:

let
  # Define the container manager (e.g., "docker" or "podman").
  containerManager = config.containerManager.containerManager;

  # Configuration for a specific container manager (docker or podman).
  containerManagerConfig = managerName: {
    userConfig = {
      # Create a dedicated system user for the container manager.
      name = managerName;
      uid = lib.mkForce (if managerName == "docker" then 300 else 200); # Ensure unique UID.
      group = lib.mkForce managerName; # Group matches the container manager name.
      description = "Dedicated user for ${managerName} container management"; # Description for clarity.
      isSystemUser = true; # Mark as a system-level user.
      linger = true; # Allow this user to keep processes running after logout.
      home = "/var/lib/${managerName}"; # Assign a dedicated home directory.
      createHome = true; # Automatically create the home directory.
      shell = pkgs.bashInteractive; # Set the shell for better user experience.
      subUidRanges = [ { startUid = 100000; count = 65536; } ]; # UID range for user namespace remapping.
      subGidRanges = [ { startGid = 100000; count = 65536; } ]; # GID range for user namespace remapping.

      sessionVariables = {
        # Environment variables for container management.
        DOMAIN = systemConfig.domain;
        EMAIL = systemConfig.email;
        CERT_EMAIL = systemConfig.certEmail;
        TIMEZONE = systemConfig.timeZone;
        DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock"; # Rootless Docker socket.
        DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString config.users.users.${containerManager}.uid}/bus"; # DBus session address.
      };
    };

    # Configuration for the container manager's API socket.
    socketConfig = {
      description = lib.mkForce "${managerName} API socket"; # Description for the systemd socket.
      wantedBy = [ "sockets.target" ]; # Ensure the socket is part of the sockets target.
      socketConfig = {
        ListenStream = "/run/${managerName}/${managerName}.sock"; # API socket location.
        SocketMode = "0660"; # Restrict permissions for security.
        SocketUser = lib.mkForce managerName; # Socket user matches the container manager user.
        SocketGroup = lib.mkForce managerName; # Socket group matches the container manager group.
      };
    };

    # Service configuration for podman (not needed for Docker).
    serviceConfig = lib.mkIf (managerName == "podman") {
      description = "${managerName} container management"; # Service description.
      requires = [ "${managerName}.socket" ]; # Ensure the socket is active before starting the service.
      after = [ "${managerName}.socket" ]; # Start service after socket is ready.
      serviceConfig = {
        Type = "notify"; # Use systemd's notify type for readiness.
        User = managerName; # Run service as the dedicated container manager user.
        ExecStart = lib.mkForce "${pkgs.podman}/bin/podman system service --time=0 --log-level=debug"; # Command to start the Podman API service.
        Restart = "on-failure"; # Restart the service on failure for reliability.
        RestartSec = "5s"; # Delay between restart attempts.
        Delegate = true; # Delegate cgroup management to Podman.
        TimeoutStartSec = "300"; # Timeout for starting the service.
        TimeoutStopSec = "30"; # Timeout for stopping the service.
      };
    };
  };

  # Select the configuration for the current container manager.
  selectedConfig = containerManagerConfig containerManager;

in {
  config = {
    # Add required system packages for container management.
    environment.systemPackages = with pkgs; [
      podman
      slirp4netns # Networking for rootless containers.
      fuse-overlayfs # Overlay file system support.
      crun # Lightweight OCI runtime for containers.
      shadow # User management tools.
      conmon # Podman container monitor.
      iptables # Required for container networking.
      dbus # DBus for session communication.
    ];

    security = {
      # Set subuid and subgid ranges for user namespace remapping.
      subUidRanges = selectedConfig.userConfig.subUidRanges;
      subGidRanges = selectedConfig.userConfig.subGidRanges;

      # Ensure subuid and subgid ranges are properly configured for the container manager user.
      subUidOwners = [ { name = containerManager; ranges = selectedConfig.userConfig.subUidRanges; } ];
      subGidOwners = [ { name = containerManager; ranges = selectedConfig.userConfig.subGidRanges; } ];

      # Configure wrappers for newuidmap and newgidmap with setuid for namespace remapping.
      wrappers = {
        newuidmap = {
          source = "${pkgs.shadow}/bin/newuidmap";
          setuid = true;
        };
        newgidmap = {
          source = "${pkgs.shadow}/bin/newgidmap";
          setuid = true;
        };
      };
    };

    # Define the container manager user and group.
    users = {
      users.${containerManager} = {
        inherit (selectedConfig.userConfig) name uid group description isSystemUser home createHome shell;
      };
      groups.${containerManager} = {
        gid = lib.mkOverride 50 989; # Preserve existing GID for backward compatibility.
      };
    };

    # Activation script to set up the container manager's home directory.
    system.activationScripts.container-setup = ''
      mkdir -p ${selectedConfig.userConfig.home} # Ensure the home directory exists.
      chown ${containerManager}:${containerManager} ${selectedConfig.userConfig.home} # Set ownership.
      chmod 755 ${selectedConfig.userConfig.home} # Set permissions.
    '';

    # Enable rootless Docker with the specified package.
    virtualisation.docker.rootless = {
      enable = true; # Activate rootless Docker for security.
      package= pkgs.docker; # Use the specified Docker package.
      setSocketVariable = true; # Automatically set the Docker socket environment variable.
    };

    # Increase the maximum number of user namespaces for rootless containers.
    boot.kernel.sysctl."user.max_user_namespaces" = 15000;

    # Optionally set DOCKER_HOST systemwide (commented out here for specific session use).
    # environment.sessionVariables = {
    #   DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
    # };
  };
}
