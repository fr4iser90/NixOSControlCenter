{ lib, pkgs, cfg, getModuleApi }:

# Cloud Upload Module
# Exports all cloud storage integration tools

{
  # S3 Compatible (AWS S3, MinIO, DigitalOcean Spaces, Backblaze B2)
  s3 = import ./s3.nix { inherit lib pkgs cfg getModuleApi; };
  
  # Nextcloud / WebDAV
  nextcloud = import ./nextcloud.nix { inherit lib pkgs cfg getModuleApi; };
  
  # Dropbox
  dropbox = import ./dropbox.nix { inherit lib pkgs cfg getModuleApi; };
}
