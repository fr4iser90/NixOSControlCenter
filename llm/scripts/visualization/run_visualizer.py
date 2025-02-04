#!/usr/bin/env python3
import streamlit.web.bootstrap
import streamlit.web.cli
import sys
from pathlib import Path

def run_streamlit():
    """Run the Streamlit visualization server with network access."""
    # Add project root to Python path
    project_root = str(Path(__file__).parent.parent.parent)
    if project_root not in sys.path:
        sys.path.insert(0, project_root)
        
    visualizer_path = Path(__file__).parent / "training_visualizer.py"
    sys.argv = [
        "streamlit",
        "run",
        str(visualizer_path),
        "--server.address=0.0.0.0",  # Allow external access
        "--server.port=8501",        # Default Streamlit port
        "--browser.serverAddress=0.0.0.0",  # Use network address
        "--server.headless=true"     # Run without auto-opening browser
    ]
    sys.exit(streamlit.web.bootstrap.run())

if __name__ == "__main__":
    run_streamlit()
