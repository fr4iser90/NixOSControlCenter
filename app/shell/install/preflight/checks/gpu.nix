# app/shell/install/preflight/checks/gpu.nix
{ pkgs, lib }:

{


  check = pkgs.writeScriptBin "check-gpu" ''
    #!${pkgs.runtimeShell}
    
    echo "Checking GPU configuration..."
    GPU_INFO=$(${pkgs.pciutils}/bin/lspci | grep -E 'VGA|3D|2D')
    
    if echo "$GPU_INFO" | grep -q "NVIDIA" && echo "$GPU_INFO" | grep -q "Intel"; then
      DETECTED="nvidiaIntelPrime"
    elif echo "$GPU_INFO" | grep -q "AMD\|ATI" && echo "$GPU_INFO" | grep -q "Intel"; then
      DETECTED="amdIntelPrime"
    elif echo "$GPU_INFO" | grep -q "NVIDIA"; then
      DETECTED="nvidia"
    elif echo "$GPU_INFO" | grep -q "AMD\|ATI"; then
      DETECTED="amdgpu"
    elif echo "$GPU_INFO" | grep -q "Intel"; then
      DETECTED="intel"
    else
      DETECTED="generic"
    fi
    
    echo ""
    echo "GPU Detection Results:"
    echo "--------------------"
    echo "Detected GPU: $DETECTED"
    echo ""
    echo "Raw GPU Info:"
    echo "$GPU_INFO"
    echo ""
  '';
}