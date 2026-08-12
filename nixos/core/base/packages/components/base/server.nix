# Server / homelab extras on top of base/core.nix.
# Core already has curl/wget/htop/jq/nano — here only server ops tools.
#
# OpenSSH (daemon + unlock/lockdown + optional client) lives in
# modules/security/ssh-manager — enable that feature, do not turn
# openssh on from package profiles.

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
}
