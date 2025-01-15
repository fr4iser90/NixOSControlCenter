{ lib, config, ... }:

with lib;

{
  containerVars = {
    WEBPASSWORD = {
      type = types.secret;
      description = "Password for Pi-hole web interface.";
      hash = true;
      required = true;
    };
    TZ = {
      type = types.str;
      description = "Timezone for the container.";
      default = config.time.timeZone or "UTC";
      required = false;
    };
    VIRTUAL_HOST = {
      type = types.str;
      description = "Subdomain and domain for Pi-hole.";
      default = "${config.services.pihole.subdomain}.${config.services.pihole.domain}";
      required = true;
    };
  };
}
