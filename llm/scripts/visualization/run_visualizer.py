#!/usr/bin/env python3
import streamlit.web.bootstrap
import streamlit.web.cli
import sys
from pathlib import Path

def run_streamlit():
    """Run the Streamlit visualization server with network access."""
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
