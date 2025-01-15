{ lib, config, ... }:

with lib;

let
  cfg = config.services.pihole;
  types = lib.types;
in {
  config.containerManager.vars = {
    WEBPASSWORD = {
      type = config.containerManager.varTypes.secret;
      description = ''
        Password for Pi-hole web interface.
        Must be at least 8 characters long.
        Will be automatically hashed before being passed to the container.
      '';
      default = "CHANGEME11!!";
      hash = true;
      required = true;
    };

    TZ = {
      type = types.str;
      description = ''
        Timezone for the container.
        Must be in the format "Area/Location" (e.g., "America/New_York").
        Defaults to system timezone or UTC if not specified.
      '';
      default = config.time.timeZone or "UTC";
      required = false;
    };

    VIRTUAL_HOST = {
      type = types.str;
      description = ''
        Subdomain and domain for Pi-hole web interface.
        Format: <subdomain>.<domain> (e.g., pihole.example.com).
      '';
      default = "${cfg.subdomain}.${cfg.domain}";
      required = true;
    };

    DNS1 = {
      type = types.str;
      description = "Primary upstream DNS server";
      default = "1.1.1.1";
      required = false;
    };

    DNS2 = {
      type = types.str;
      description = "Secondary upstream DNS server";
      default = "1.0.0.1";
      required = false;
    };

    WEBTHEME = {
      type = types.str;
      description = ''
        Web interface theme.
        Available options: default, dark, light, high-contrast.
      '';
      default = "default";
      required = false;
    };

    ADMIN_EMAIL = {
      type = types.str;
      description = "Email address for the admin user";
      default = "";
      required = false;
    };
  };
}
