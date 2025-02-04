#!/usr/bin/env python3
import streamlit.web.bootstrap
import streamlit.web.cli
import sys
import os
from pathlib import Path

# Add project root to Python path
ROOT_DIR = Path(__file__).parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from scripts.utils.path_config import ProjectPaths

def run_streamlit():
    """Run the Streamlit visualization server with network access."""
    # Set up Python path
    os.environ["PYTHONPATH"] = str(ProjectPaths.PROJECT_ROOT)
    
    # Prepare Streamlit arguments
    sys.argv = [
        "streamlit",
        "run",
        str(ProjectPaths.VISUALIZER_SCRIPT),
        "--server.address=0.0.0.0",
        "--server.port=8501",
        "--browser.serverAddress=0.0.0.0",
        "--server.headless=true"
    ]
    
    try:
        sys.exit(streamlit.web.bootstrap.run())
    except Exception as e:
        print(f"Error starting visualization server: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    run_streamlit()
