import os
import time
from datetime import datetime

def main():
    """Simple logger service to verify our environment is working."""
    print("Starting distributed logger service...")
    log_level = os.environ.get("LOG_LEVEL", "INFO")
    print(f"Log level set to: {log_level}")
    
    while True:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] Logger service is running. This will be part of our distributed system!")
        time.sleep(5)

if __name__ == "__main__":
    main()