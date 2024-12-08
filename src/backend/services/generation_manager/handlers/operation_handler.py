from typing import Dict, Any
import subprocess
import logging
import os

logger = logging.getLogger(__name__)

class GenerationOperationHandler:
    def rename(self, generation: Dict[str, Any], new_name: str) -> bool:
        """Handle generation rename operation."""
        try:
            # Extrahiere den Store-Pfad aus den Boot-Optionen
            boot_options = generation.get('tooltip', {}).get('boot_options', '')
            store_path = None
            if 'init=' in boot_options:
                store_path = boot_options.split('init=')[1].split()[0]
            
            if not store_path:
                logger.error("Could not find store path in generation info")
                return False

            # Verwende den Store-Pfad für die Umbenennung
            cmd = [
                "nix-env",
                "--profile", "/nix/var/nix/profiles/system",
                "--set", store_path,
                "--set-flag", "name", new_name
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                logger.error(f"Failed to rename: {result.stderr}")
                return False
            
            # Aktualisiere Boot-Einträge
            entry_path = f"/boot/loader/entries/nixos-generation-{generation['number']}.conf"
            if os.path.exists(entry_path):
                with open(entry_path, 'r') as f:
                    content = f.read()
                content = content.replace('title NixOS', f'title {new_name}')
                with open(entry_path, 'w') as f:
                    f.write(content)
                
            logger.info(f"Successfully renamed generation {generation['number']} to {new_name}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to rename generation: {e}")
            return False

    def lock(self, generation: Dict[str, Any]) -> bool:
        """Handle generation lock operation."""
        pass

    def analyze(self, generation: Dict[str, Any]) -> Dict[str, Any]:
        """Handle generation analysis operation."""
        pass

    def delete(self, generation: Dict[str, Any]) -> bool:
        """Handle generation delete operation."""
        pass 