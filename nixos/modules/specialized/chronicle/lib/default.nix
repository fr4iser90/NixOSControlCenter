{ lib, pkgs, cfg ? {} }:

let
  # Helper to import modules with cfg parameter
  importWithCfg = module: import module { inherit lib pkgs cfg; };
in
{
  # Import all library modules
  utils = import ./utils.nix { inherit lib pkgs; };
  privacy = import ./privacy.nix { inherit lib pkgs; };
  validators = import ./validators.nix { inherit lib pkgs; };
  state = import ./state.nix { inherit lib pkgs; };
  
  # New Quick Wins & Phase 1 modules
  hotkeys = importWithCfg ./hotkeys.nix;
  notifications = importWithCfg ./notifications.nix;
  session = importWithCfg ./session.nix;
  pauseResume = importWithCfg ./pause-resume.nix;
  comments = importWithCfg ./comments.nix;
  mouseTracking = importWithCfg ./mouse-tracking.nix;
  exportAll = importWithCfg ./export-all.nix;
  
  # Phase 2 modules - Production Ready
  multiMonitor = importWithCfg ./multi-monitor.nix;
  crashRecovery = importWithCfg ./crash-recovery.nix;
  errorHandling = importWithCfg ./error-handling.nix;
  
  # Performance module
  performance = import ./performance.nix { inherit lib pkgs; };
  
  # Phase 3 modules - Enhanced UX (v1.1+)
  darkMode = import ./dark-mode.nix { inherit lib pkgs; };
  videoRecording = import ./video-recording.nix { inherit lib pkgs; };
  keyboardRecording = import ./keyboard-recording.nix { inherit lib pkgs; };
  audioCommentary = import ./audio-commentary.nix { inherit lib pkgs; };
  
  # Phase 4 modules - Enhanced UX Part 2 (v1.2+)
  smartDetection = importWithCfg ./smart-detection.nix;
  themes = importWithCfg ./themes.nix;
  stepEditing = importWithCfg ./step-editing.nix;
  annotations = importWithCfg ./annotations.nix;
}
