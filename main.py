## Path: main.py
#!/usr/bin/env python3
"""
Main entry point for the NixOS Control Center application.
"""

import logging
import sys
import os
from datetime import datetime
from src.app import NixOsControlCenterApp  # Import the main application class

# Create logs directory if it doesn't exist
log_dir = "logs"
os.makedirs(log_dir, exist_ok=True)

# Create log filename with timestamp
log_file = os.path.join(log_dir, f"nixos_control_center_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")

# Get debug mode from environment variable
DEBUG_MODE = os.environ.get('DEBUG_MODE', '0') == '1'

# Setup enhanced logging
logging.basicConfig(
    level=logging.DEBUG if DEBUG_MODE else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout),
    ],
)

# Configure specific loggers
backend_logger = logging.getLogger('src.backend')
backend_logger.setLevel(logging.DEBUG if DEBUG_MODE else logging.INFO)

frontend_logger = logging.getLogger('src.frontend')
frontend_logger.setLevel(logging.INFO)  # Frontend always uses INFO level

def main():
    """Main function to start the application."""
    logging.info("Starting NixOS Control Center...")
    logging.debug(f"Debug mode: {'enabled' if DEBUG_MODE else 'disabled'}")
    
    try:
        app = NixOsControlCenterApp()
        app.run()
    except Exception as e:
        logging.error("An unexpected error occurred: %s", e, exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
