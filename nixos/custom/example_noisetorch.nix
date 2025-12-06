{ config, pkgs, lib, systemConfig, ... }:

{
  ######################################################################
  # 🎤 NoiseTorch: Real-time Noise Suppression for Microphone
  #    - Uses machine learning to filter background noise
  #    - Creates a virtual microphone device
  #    - Requires CAP_SYS_RESOURCE capability for real-time processing
  ######################################################################
  
  ######################################################################
  # 🧰 Packages
  ######################################################################
  environment.systemPackages = with pkgs; [
    noisetorch
  ];
  
  ######################################################################
  # 🔐 Security Wrapper: Grant CAP_SYS_RESOURCE capability
  #    - Required for real-time audio processing
  #    - Allows NoiseTorch to set real-time scheduling priorities
  ######################################################################
  security.wrappers.noisetorch = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_resource+ep";
    source = "${pkgs.noisetorch}/bin/noisetorch";
  };
}

