from typing import List, Dict, Any
import subprocess
import logging
import os

logger = logging.getLogger(__name__)

class SystemGenerationHandler:
    def get_generations(self) -> List[Dict[str, Any]]:
        """Get system generations with detailed information."""
        try:
            # Hole Basis-Informationen von nixos-rebuild
            result = subprocess.run(
                ["nixos-rebuild", "list-generations"],
                capture_output=True,
                text=True
            )
            
            generations = []
            lines = result.stdout.splitlines()
            
            # Skip header line
            for line in lines[1:]:
                if line.strip():
                    generation = self._parse_generation_line(line)
                    if generation:
                        # Ergänze Boot-Entry Informationen
                        boot_info = self._get_boot_entry_info(generation['number'])
                        if boot_info:
                            generation.update(boot_info)
                        
                        generation['type'] = 'system'
                        generations.append(generation)
            
            return generations
            
        except Exception as e:
            logger.error(f"Failed to get system generations: {e}")
            return []

    def _parse_generation_line(self, line: str) -> Dict[str, Any]:
        """Parse a generation line from nixos-rebuild output."""
        try:
            parts = line.strip().split()
            if not parts:
                return {}

            # Basis-Informationen
            generation = {
                'number': int(parts[0]),
                'status': 'current' if 'current' in parts else '',
                'date': f"{parts[-6]} {parts[-5]}",
                'nixos_version': parts[-4],
                'kernel': parts[-2],
                
                # Zusätzliche Informationen für Tooltip
                'tooltip': {
                    'date': f"{parts[-6]} {parts[-5]}",
                    'nixos_version': parts[-4],
                    'kernel': f"Linux {parts[-2]}",
                    'specialisation': parts[-1] == '*'
                }
            }
            
            return generation
            
        except Exception as e:
            logger.error(f"Failed to parse generation line '{line}': {e}")
            return {}

    def _get_boot_entry_info(self, gen_number: int) -> Dict[str, Any]:
        """Get information from boot entry file."""
        try:
            entry_path = f"/boot/loader/entries/nixos-generation-{gen_number}.conf"
            
            if not os.path.exists(entry_path):
                return {}
                
            with open(entry_path, 'r') as f:
                lines = f.readlines()
                
            entry_info = {}
            for line in lines:
                if line.startswith('title'):
                    entry_info['title'] = line.split('title', 1)[1].strip()
                elif line.startswith('version'):
                    entry_info['version'] = line.split('version', 1)[1].strip()
                elif line.startswith('options'):
                    entry_info['tooltip'] = entry_info.get('tooltip', {})
                    entry_info['tooltip']['boot_options'] = line.split('options', 1)[1].strip()
                    
            return entry_info
            
        except Exception as e:
            logger.error(f"Failed to read boot entry for generation {gen_number}: {e}")
            return {}