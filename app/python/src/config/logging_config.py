## Path: src/config/logging_config.py

import logging
import os
from datetime import datetime

def setup_logging(debug_mode: bool = False):
    """Setup application-wide logging configuration."""
    
    # Create logs directory if it doesn't exist
    log_dir = "logs"
    os.makedirs(log_dir, exist_ok=True)
    
    # Create a unique log file name with timestamp
    log_file = os.path.join(log_dir, f"nixos_manager_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log")
    
    # Basic logging configuration
    logging_level = logging.DEBUG if debug_mode else logging.INFO
    
    # Configure logging format
    log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    # Configure handlers
    handlers = [
        logging.FileHandler(log_file),
        logging.StreamHandler()  # Console output
    ]
    
    # Apply configuration
    logging.basicConfig(
        level=logging_level,
        format=log_format,
        handlers=handlers
    )
    
    # Set specific levels for different components
    logging.getLogger('src.backend').setLevel(logging_level)
    logging.getLogger('src.frontend').setLevel(logging.INFO)  # Frontend always uses INFO
