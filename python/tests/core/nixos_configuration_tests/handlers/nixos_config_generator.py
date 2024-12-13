class NixOSEnvGenerator:
    """Generator for NixOS configurations"""
    
    def __init__(self):
        # Available options with their possible values
        self.available_options = {
            # System options
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

            # User options
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

            # Localization
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

            # Desktop environment
            'desktop': [
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
            'gpu': [
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

            # Security
            'sudoOptions': {
                'requirePassword': [True, False],
                'timeout': [0, 5, 15, 30, 60]
            },
            'enableFirewall': [True, False],

            # Feature flags
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
        
        # Base configuration
        self.base_configs = {
            'systemType': 'gaming-workstation',
            'bootloader': 'systemd-boot',
            'allowUnfree': True,
            'users': {
                'testuser': {
                    'role': 'admin',
                    'defaultShell': 'zsh',
                    'autoLogin': False
                }
            },
            'hostName': 'testhost',
            'timeZone': 'Europe/Berlin',
            'locales': ['en_US.UTF-8'],
            'keyboardLayout': 'de',
            'keyboardOptions': 'eurosign:e',
            'desktop': 'plasma',
            'displayManager': 'sddm',
            'session': 'plasmawayland',
            'darkMode': False,
            'gpu': 'amdgpu',
            'audio': 'pipewire',
            'sudo': {
                'requirePassword': True,
                'timeout': 15
            },
            'enableFirewall': True,
            'testing': True
        }

        # Profile-specific defaults
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

        # Desktop-specific defaults
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

    def generate_test_variants(self, components=None, max_combinations=None):
        """Generates test combinations for specific components"""
        from itertools import product

        if components is None:
            components = ['systemType', 'desktop', 'audio']

        options_to_test = {}
        for comp in components:
            if comp == 'displayManager':
                options = self.available_options.get('displayManagers', [])
            else:
                options = self.available_options.get(comp, [])
            options_to_test[comp] = options

        combinations = list(product(*options_to_test.values()))
        test_configs = []
        
        for values in combinations:
            config = {}
            for comp, value in zip(components, values):
                config[comp] = value
                
            if 'desktop' in config and config['desktop']:
                config['mainUser'] = 'testuser'
                
            test_configs.append(config)

        valid_configs = [
            config for config in test_configs 
            if self._is_valid_combination(config)
        ]

        if max_combinations:
            valid_configs = valid_configs[:max_combinations]

        return valid_configs
    
    def _is_valid_combination(self, config):
        """Validates if a configuration combination is valid"""
        if config.get('systemType') == 'headless':
            if config.get('desktop') or config.get('displayManager'):
                return False
                
        if config.get('desktop') == 'gnome':
            if config.get('displayManager') not in [None, 'gdm']:
                return False
                
        return True

    def generate_config(self, **config):
        """Generates complete env.nix configuration"""
        result = self.base_configs.copy()
        
        system_type = config.get('systemType')
        if system_type in self.profile_defaults:
            result.update(self.profile_defaults[system_type])
        
        desktop = config.get('desktop')
        if desktop in self.desktop_defaults:
            result.update(self.desktop_defaults[desktop])
        
        result.update(config)
        
        if 'overrides' in config:
            result.setdefault('overrides', {})
            result['overrides'].update(config['overrides'])
        
        return self._format_config(result)
    
    def _format_value(self, value):
        """Formats a value for Nix"""
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
        """Formats attributes for Nix"""
        spaces = " " * indent
        lines = ["{"]
        
        for key, value in sorted(attrs.items()):
            formatted_value = self._format_value(value)
            lines.append(f"{spaces}{key} = {formatted_value};")
            
        lines.append("}")
        return "\n".join(lines)
    
    def _format_config(self, config):
        """Formats the complete configuration"""
        return f'''
# This file is generated for testing
{self._format_attrs(config)}
'''