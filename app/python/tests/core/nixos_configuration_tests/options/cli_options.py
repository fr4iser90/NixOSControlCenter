"""CLI options for pytest configuration"""

def setup_cli_options(parser):
    """Setup all CLI options for the test suite"""
    
    # Test execution options
    parser.addoption(
        "--show-progress", 
        action="store_true", 
        help="Show progress bar during tests"
    )
    
    parser.addoption(
        "--test-strategy",
        choices=["validate-only", "full"],
        default="validate-only",
        help="Test strategy: validate-only or full (validate + build)"
    )
    
    # Random test options
    parser.addoption(
        "--random-tests",
        type=int,
        default=20,
        help="Number of random configurations to test (default: 20)"
    )