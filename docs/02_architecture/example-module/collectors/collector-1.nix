# Example collector: Gathers data from system/configs/files/APIs
# Collectors only gather data, they don't transform it

{ pkgs, lib, ... }:

{
  collect = ''
    # Example: Read from system
    # DATA=$(cat /path/to/file)
    
    # Example: Read from config
    # CONFIG_VALUE="${"$"}{cfg.option1}"
    
    # Example: Call external API
    # API_DATA=$(curl -s https://api.example.com/data)
    
    # Return collected data (no transformation)
    echo "Collected data"
  '';
}

