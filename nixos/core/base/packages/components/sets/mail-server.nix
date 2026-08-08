# Minimal local mail transfer agent (Postfix).
# Not a full hosted mail stack (no Dovecot/Rspamd) — enough for outbound/local MTA on a server.
{ config, lib, pkgs, ... }:
{
  services.postfix = {
    enable = true;
    # Local-only defaults; tighten hostname/domain in systemConfig overrides as needed.
  };

  environment.systemPackages = with pkgs; [
    postfix
    mailutils
  ];
}
