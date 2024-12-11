from typing import Dict, Any, List

class ConfigGenerator:
    """Generator für NixOS-Konfigurationen"""
    
    def __init__(self):
        self.available_options = {
            'systemType': [
                'gaming-workstation',
                'headless',
                'gaming'
            ],
            'desktop': [
                'plasma',
                'gnome',
                'xfce',
                None
            ],
            'gpu': [
                'amdgpu',
                'nvidia',
                'intel'
            ]
        }
        
        self.base_configs = {
            'systemType': 'gaming-workstation',
            'bootloader': 'systemd-boot',
            'mainUser': 'testuser',
            'hostName': 'testhost',
            'timeZone': 'Europe/Berlin',
            'locales': ['en_US.UTF-8'],
            'keyboardLayout': 'de',
            'desktop': 'plasma',
            'displayManager': 'sddm',
            'gpu': 'amdgpu',
            'audio': 'pipewire'
        }
    
    def generate_config(self, **config) -> str:
        """Generiert vollständige env.nix"""
        env_config = self.base_configs.copy()
        env_config.update(config)
        
        return self._format_config(env_config)
    
    def _format_config(self, config: Dict[str, Any]) -> str:
        """Formatiert Konfiguration als Nix-Code"""
        return f'''
# This file is generated for testing
{{
  # System Configuration
  systemType = "{config['systemType']}";
  bootloader = "{config['bootloader']}";
  mainUser = "{config['mainUser']}";
  hostName = "{config['hostName']}";
  timeZone = "{config['timeZone']}";
  locales = [ {" ".join(f'"{x}"' for x in config['locales'])} ];
  keyboardLayout = "{config['keyboardLayout']}";
  
  # Desktop Environment
  desktop = {f'"{config["desktop"]}"' if config['desktop'] else "null"};
  displayManager = "{config['displayManager']}";
  
  # Hardware
  gpu = "{config['gpu']}";
  audio = "{config['audio']}";
  
  # Test Mode
  testing = true;
}}
'''
    
    def _format_overrides(self, overrides: Dict[str, Any]) -> str:
        """Formatiert Override-Optionen"""
        if not overrides:
            return ""
        
        lines = []
        for key, value in overrides.items():
            if isinstance(value, bool):
                lines.append(f"  {key} = {str(value).lower()};")
            elif isinstance(value, str):
                lines.append(f'  {key} = "{value}";')
            elif isinstance(value, (int, float)):
                lines.append(f"  {key} = {value};")
            
        return "\n".join(lines)