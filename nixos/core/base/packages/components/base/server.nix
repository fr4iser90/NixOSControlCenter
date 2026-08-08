# Server / homelab extras on top of base/core.nix.
# Core already has curl/wget/htop/jq/nano — here only server ops tools.

{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    tmux
    tree
    fzf
    iotop
    iftop
    nmap
    gnupg
    git
    neovim
  ];

  services.openssh.enable = true;
}
