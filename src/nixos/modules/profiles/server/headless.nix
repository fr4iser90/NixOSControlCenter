# modules/profiles/types/server/headless.nix
{
  type = "headless";
  category = "server";
  
  defaults = {
    desktop = null;
    ssh = true;
    virtualization = true;
    docker = true;
    monitoring = true;
    sound = false;
    bluetooth = false;
    printing = false;
    
    packages = {
      base = [
        "git" "wget" "tree"
        "htop" "tmux" "screen"
      ];
      network = [
        "nmap" "iperf3" "ethtool"
        "iptables" "tcpdump"
      ];
      monitoring = [
        "prometheus" "grafana"
      ];
    };
    
    services = {
      openssh.enable = true;
      prometheus = {
        enable = true;
        exporters.node.enable = true;
      };
    };
  };
}