## Path: src/backend/services/generation_manager.py

import subprocess
import logging
from typing import List, Optional
from datetime import datetime
import json
import os

# Logger-Konfiguration
logger = logging.getLogger(__name__)

class GenerationManager:
    """Handles generation-related functionality in NixOS."""

    def __init__(self, debug_mode: bool = False):
        self.debug_mode = debug_mode
        if debug_mode:
            logger.setLevel(logging.DEBUG)
        else:
            logger.setLevel(logging.INFO)
        self.names_file = "generation_names.json"
        self.generation_names = self.load_generation_names()

    def load_generation_names(self):
        """Load generation names from a JSON file."""
        if os.path.exists(self.names_file):
            with open(self.names_file, 'r') as f:
                return json.load(f)
        return {}

    def save_generation_names(self):
        """Save generation names to a JSON file."""
        with open(self.names_file, 'w') as f:
            json.dump(self.generation_names, f)

    def get_generations(self) -> List[dict]:
        """Fetch system generations."""
        try:
            # Alternative Methode mit nixos-rebuild
            system_result = self._execute_command(["nixos-rebuild", "list-generations"])
            
            all_generations = []
            
            # Debug output
            print("Command output:", system_result.stdout)
            print("Return code:", system_result.returncode)
            
            # Parse system generations
            if system_result.returncode == 0:
                system_gens = system_result.stdout.splitlines()
                for line in system_gens:
                    if line.strip():
                        parts = line.strip().split()
                        # Debug output
                        print("Processing line:", line)
                        print("Parts:", parts)
                        
                        # Check if first part is a number and handle "current"
                        if len(parts) >= 2:
                            number = parts[0].strip()
                            if number.isdigit():
                                # Handle date and time, accounting for "current" in the line
                                date_parts = parts[1:]
                                date_str = " ".join(date_parts)
                                if "(current)" in line:
                                    date_str = date_str.replace("(current)", "").strip()
                                    status = "(current)"
                                else:
                                    status = ""
                                    
                                # Get custom name if available
                                custom_name = self.get_generation_name(number)
                                
                                gen = {
                                    'type': 'system',
                                    'number': number,
                                    'date': date_str,
                                    'name': custom_name,  # Use custom name
                                    'status': status
                                }
                                all_generations.append(gen)
                                print(f"Added generation: {gen}")

            if all_generations:
                logger.info(f"Total generations found: {len(all_generations)}")
                return all_generations
            else:
                logger.warning("No generations found in the system")
                return []

        except Exception as e:
            logger.error(f"Error fetching generations: {str(e)}", exc_info=self.debug_mode)
            return []

    def _execute_command(self, command: List[str]) -> subprocess.CompletedProcess:
        """Execute a shell command and log its execution."""
        logger.debug(f"Executing command: {' '.join(command)}")
        start_time = datetime.now()
        
        result = subprocess.run(command, capture_output=True, text=True)
        
        execution_time = (datetime.now() - start_time).total_seconds()
        logger.debug(f"Command execution time: {execution_time:.2f}s")
        
        return result

    def rename_generation(self, generation, new_name):
        """Rename a specific generation."""
        logger.info(f"Renaming generation: {generation} to {new_name}")
        try:
            # Update the local storage with the new name
            self.generation_names[generation['number']] = new_name
            # Save the updated names to the JSON file
            self.save_generation_names()
            logger.info(f"Successfully renamed generation {generation['number']} to '{new_name}'")
            return True
        except Exception as e:
            logger.error(f"Error renaming generation: {str(e)}", exc_info=self.debug_mode)
            return False

    def get_generation_name(self, number):
        """Get the name of a generation."""
        # Fetch the custom name from the JSON file, default to "NixOS System" if not found
        return self.generation_names.get(number, "NixOS System")

    def lock_generation(self, generation):
        """Lock a specific generation."""
        logger.info(f"Locking generation: {generation}")
        # Implement lock logic here

    def analyze_generation(self, generation):
        """Analyze a specific generation."""
        logger.info(f"Analyzing generation: {generation}")
        # Implement analyze logic here

    def delete_generation(self, generation):
        """Delete a specific generation."""
        logger.info(f"Deleting generation: {generation}")
        # Implement delete logic here

# Example usage:
manager = GenerationManager()
generations = manager.get_generations()
print(generations)
