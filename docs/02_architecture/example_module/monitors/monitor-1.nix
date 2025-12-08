# Example monitor: Monitors system state/health/metrics
# Monitors track and report on system conditions

{ pkgs, lib, ui, ... }:

{
  monitor = ''
    # Example: Monitor system state
    # STATE=$(systemctl is-active example-service)
    
    # Example: Check health
    # HEALTH=$(check-health)
    
    # Example: Report metrics
    ${ui.messages.info "Monitoring system state"}
  '';
}

