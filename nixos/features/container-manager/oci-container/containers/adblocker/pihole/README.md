# Pi-hole Container Configuration

## Overview
This module provides a declarative configuration for running Pi-hole in a container. Pi-hole is a network-wide ad blocker that also provides DNS services.

## Configuration Options

### Required Configuration
- `services.pihole.subdomain`: Subdomain for Pi-hole web interface (e.g., "pihole")
- `services.pihole.domain`: Base domain for the service (e.g., "example.com")
- `services.pihole.security.secrets.webpassword.source`: Path to file containing web interface password

### Optional Configuration
- `services.pihole.imageTag`: Docker image tag/version (default: "latest")
- `services.pihole.monitoring.enable`: Enable monitoring (default: false)
- `services.pihole.monitoring.interval`: Health check interval (default: "30s")

## Environment Variables

The following environment variables are automatically configured:

| Variable       | Description                              | Default Value          |
|----------------|------------------------------------------|------------------------|
| WEBPASSWORD    | Web interface password                   | From config file       |
| TZ             | Timezone                                 | System timezone or UTC |
| VIRTUAL_HOST   | Subdomain and domain                     | pihole.example.com     |
| DNS1           | Primary upstream DNS server              | 1.1.1.1                |
| DNS2           | Secondary upstream DNS server            | 1.0.0.1                |
| WEBTHEME       | Web interface theme                      | default                |
| ADMIN_EMAIL    | Admin email address                      | ""                     |

## Usage

1. Add the Pi-hole module to your NixOS configuration:

```nix
{
  imports = [
    ./nixos/features/container-manager/containers/adblocker/pihole
  ];

  services.pihole = {
    enable = true;
    subdomain = "pihole";
    domain = "example.com";
    security.secrets.webpassword.source = "/path/to/webpassword";
  };
}
```

2. Deploy the configuration:

```bash
sudo nixos-rebuild switch
```

## Security Considerations

- Always use a strong password for the web interface
- Store the web password in a secure location
- Enable HTTPS for the web interface
- Regularly update the Pi-hole container

## Monitoring

When monitoring is enabled, the container will expose metrics on port 80 at `/metrics`. You can configure Prometheus to scrape these metrics.

```nix
{
  services.pihole.monitoring = {
    enable = true;
    interval = "30s";
  };
}
```

## Troubleshooting

- Check container logs: `journalctl -u pihole-container`
- Verify DNS resolution
- Check firewall rules if unable to access web interface
