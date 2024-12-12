class ConfigGenerator:
    """Generator für NixOS-Konfigurationen"""
    
    def __init__(self):
        # Alle verfügbaren Optionen mit ihren möglichen Werten
        self.available_options = {
            # System
            'systemType': [
                'gaming',
                'gaming-workstation',
                'headless',
                'workstation'
            ],
            'bootloader': [
                'systemd-boot',
                'grub',
                'refind'
            ],
            'allowUnfree': [True, False],

            # User-Optionen
            'userRoles': [
                'admin',
                'guest',
                'restricted-admin'
            ],
            'shells': [
                'bash',
                'dash',
                'fish',
                'ksh',
                'tcsh',
                'xonsh',
                'zsh'
            ],

            # Lokalisierung
            'timeZones': [
                'Europe/Berlin',
                'Europe/London',
                'America/New_York',
                'Asia/Tokyo'
            ],
            'locales': [
                'en_US.UTF-8',
                'de_DE.UTF-8',
                'fr_FR.UTF-8',
                'es_ES.UTF-8'
            ],
            'keyboardLayouts': [
                'de',
                'us',
                'fr',
                'es'
            ],
            'keyboardOptions': [
                'eurosign:e',
                'caps:escape',
                'grp:alt_shift_toggle'
            ],

            # Desktop
            'desktops': [
                'plasma',
                'gnome',
                'xfce',
                None
            ],
            'displayManagers': [
                'sddm',
                'gdm',
                'lightdm',
                None
            ],
            'sessions': [
                'plasmawayland',
                'plasmax11',
                'gnomewayland',
                'gnomex11',
                'xfce',
                'i3',
                None
            ],
            'darkMode': [True, False],

            # Hardware
            'gpus': [
                'nvidia',
                'nvidiaIntelPrime',
                'intel',
                'amdgpu'
            ],
            'audio': [
                'pipewire',
                'pulseaudio',
                'alsa'
            ],

            # Sicherheit
            'sudoOptions': {
                'requirePassword': [True, False],
                'timeout': [0, 5, 15, 30, 60]
            },
            'enableFirewall': [True, False],

            # Feature-Flags (Overrides)
            'features': {
                'enableSSH': [True, False, None],
                'enableSteam': [True, False, None],
                'enableGameMode': [True, False, None],
                'enableDiscord': [True, False, None],
                'enableDocker': [True, False, None],
                'enableVirtualization': [True, False, None],
                'enableDevelopmentTools': [True, False, None],
                'enableSystemdBootloader': [True, False, None]
            }
        }
        
        # Standard-Konfiguration
        self.base_configs = {
            # System
            'systemType': 'gaming-workstation',
            'bootloader': 'systemd-boot',
            'allowUnfree': True,
            
            # User
            'users': {
                'testuser': {
                    'role': 'admin',
                    'defaultShell': 'zsh',
                    'autoLogin': False
                }
            },
            
            # System Settings
            'hostName': 'testhost',
            'timeZone': 'Europe/Berlin',
            'locales': ['en_US.UTF-8'],
            'keyboardLayout': 'de',
            'keyboardOptions': 'eurosign:e',
            
            # Desktop
            'desktop': 'plasma',
            'displayManager': 'sddm',
            'session': 'plasmawayland',
            'darkMode': False,
            
            # Hardware
            'gpu': 'amdgpu',
            'audio': 'pipewire',
            
            # Security
            'sudo': {
                'requirePassword': True,
                'timeout': 15
            },
            'enableFirewall': True,
            
            # Testing
            'testing': True
        }

        self.profile_defaults = {
            'gaming': {
                'desktop': 'plasma',
                'allowUnfree': True,
                'overrides': {
                    'enableSteam': True,
                    'enableGameMode': True,
                    'enableDiscord': True
                }
            },
            'headless': {
                'desktop': None,
                'displayManager': None,
                'session': None,
                'overrides': {
                    'enableSSH': True,
                    'enableFirewall': True
                }
            },
            'gaming-workstation': {
                'desktop': 'plasma',
                'allowUnfree': True,
                'overrides': {
                    'enableDocker': True,
                    'enableVirtualization': True,
                    'enableDevelopmentTools': True
                }
            },
            'workstation': {
                'desktop': 'gnome',
                'allowUnfree': True,
                'overrides': {
                    'enableDevelopmentTools': True,
                    'enableDocker': True
                }
            }
        }

        # Desktop-spezifische Defaults
        self.desktop_defaults = {
            'gnome': {
                'darkMode': True,
                'session': 'gnomewayland',
                'displayManager': 'gdm'
            },
            'plasma': {
                'session': 'plasmawayland',
                'displayManager': 'sddm'
            },
            'xfce': {
                'session': 'xfce',
                'displayManager': 'lightdm',
                'darkMode': False
            }
        }  

    def generate_config(self, **config):
        """Generiert vollständige env.nix"""
        result = self.base_configs.copy()
        
        # Profile-Defaults anwenden
        system_type = config.get('systemType')
        if system_type in self.profile_defaults:
            result.update(self.profile_defaults[system_type])
        
        # Desktop-Defaults anwenden
        desktop = config.get('desktop')
        if desktop in self.desktop_defaults:
            result.update(self.desktop_defaults[desktop])
        
        # Benutzer-Konfiguration überschreiben
        result.update(config)
        
        # Overrides zusammenführen
        if 'overrides' in config:
            result.setdefault('overrides', {})
            result['overrides'].update(config['overrides'])
        
        return self._format_config(result)
    
    def _format_value(self, value):
        """Formatiert einen Wert für Nix"""
        if isinstance(value, bool):
            return str(value).lower()
        elif isinstance(value, (list, tuple)):
            return f'[ {" ".join(f'"{x}"' for x in value)} ]'
        elif isinstance(value, dict):
            return self._format_attrs(value)
        elif value is None:
            return "null"
        else:
            return f'"{value}"'
    
    def _format_attrs(self, attrs, indent=2):
        """Formatiert Attribute für Nix"""
        spaces = " " * indent
        lines = ["{"]
        
        for key, value in sorted(attrs.items()):
            formatted_value = self._format_value(value)
            lines.append(f"{spaces}{key} = {formatted_value};")
            
        lines.append("}")
        return "\n".join(lines)
    
    def _format_config(self, config):
        """Formatiert die vollständige Konfiguration"""
        return f'''
# This file is generated for testing
{self._format_attrs(config)}
'''