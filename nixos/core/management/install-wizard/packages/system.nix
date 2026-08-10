# app/shell/install/packages/system.nix
{ pkgs }:

with pkgs; [
  # System-Tools
  pciutils
  usbutils
  lshw
  dmidecode

  
  # Disk-Tools
  parted
  gptfdisk
  dosfstools
  ntfs3g
  fzf
  # Network-Tools
  iw
  wirelesstools
  ethtool
  networkmanager
  
  # System Monitoring
  htop
  iotop
  lsof
  
  # File Tools
  file
  tree
  ncdu
  
  # Utilities
  git
  curl
  wget
  jq
  
  # Text Tools
  nano
  neovim
  less
  
  # Hardware Detection
  hwinfo
  lm_sensors


  # Boot Tools
  efibootmgr
  os-prober
  
  # Compression
  gzip
  bzip2
  xz
  zip
  unzip
]