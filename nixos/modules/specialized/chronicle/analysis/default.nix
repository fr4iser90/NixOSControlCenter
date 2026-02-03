{ lib, pkgs, cfg }:

# Analysis & Insights Module
{
  performanceMetrics = import ./performance-metrics.nix { inherit lib pkgs cfg; };
  systemLogs = import ./system-logs.nix { inherit lib pkgs cfg; };
  fileChanges = import ./file-changes.nix { inherit lib pkgs cfg; };
}
