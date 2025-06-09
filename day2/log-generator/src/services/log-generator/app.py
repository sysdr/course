"""
Main application entry point for the log generator service.
"""
import os
import time
import sys

from config import config
from log_generator import LogGenerator

def main():
    """Run the log generator service."""
    # Print configuration for debugging
    print("Starting log generator with configuration:")
    for key, value in config.items():
        print(f"  {key}: {value}")
    
    # Create and run the log generator
    generator = LogGenerator(config)
    
    # Check if duration was provided as command line argument
    duration = None
    if len(sys.argv) > 1:
        try:
            duration = float(sys.argv[1])
            print(f"Generator will run for {duration} seconds")
        except ValueError:
            print(f"Invalid duration: {sys.argv[1]}")
    
    generator.run(duration)

if __name__ == "__main__":
    main()