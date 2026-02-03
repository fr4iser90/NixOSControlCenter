{ lib, pkgs }:

{
  # Validate screenshot quality
  validateQuality = quality: ''
    if [ ${toString quality} -lt 1 ] || [ ${toString quality} -gt 100 ]; then
      error "Screenshot quality must be between 1 and 100"
      return 1
    fi
    return 0
  '';

  # Validate max steps
  validateMaxSteps = maxSteps: ''
    if [ ${toString maxSteps} -lt 1 ]; then
      error "Max steps must be at least 1"
      return 1
    fi
    return 0
  '';

  # Validate output directory is writable
  validateOutputDir = outputDir: ''
    local expanded_dir="${outputDir}"
    eval expanded_dir="$expanded_dir"
    
    if ! mkdir -p "$expanded_dir" 2>/dev/null; then
      error "Cannot create output directory: $expanded_dir"
      return 1
    fi
    
    if [ ! -w "$expanded_dir" ]; then
      error "Output directory is not writable: $expanded_dir"
      return 1
    fi
    
    return 0
  '';

  # Validate backend is available
  validateBackend = backend: ''
    if [ "${backend}" = "x11" ]; then
      if ! command -v xprop &> /dev/null; then
        error "X11 backend requires xprop but it's not installed"
        return 1
      fi
      if ! command -v maim &> /dev/null; then
        error "X11 backend requires maim but it's not installed"
        return 1
      fi
    elif [ "${backend}" = "wayland" ]; then
      if ! command -v grim &> /dev/null && ! command -v spectacle &> /dev/null; then
        error "Wayland backend requires grim or spectacle but neither is installed"
        return 1
      fi
    fi
    return 0
  '';

  # Check if session is valid
  validateSession = sessionPath: ''
    if [ ! -d "${sessionPath}" ]; then
      error "Session directory does not exist: ${sessionPath}"
      return 1
    fi
    
    if [ ! -f "${sessionPath}/session.json" ]; then
      error "Session metadata not found: ${sessionPath}/session.json"
      return 1
    fi
    
    return 0
  '';

  # Validate JSON structure
  validateJson = jsonFile: ''
    if ! ${pkgs.jq}/bin/jq '.' "${jsonFile}" &> /dev/null; then
      error "Invalid JSON file: ${jsonFile}"
      return 1
    fi
    return 0
  '';
}
