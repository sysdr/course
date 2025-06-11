#!/usr/bin/env python3
"""
Main execution script for RabbitMQ setup demonstration.
"""
import subprocess
import sys
import time
import os
from colorama import init, Fore, Style

init()  # Initialize colorama

def run_command(command, description):
    """Run a command with colored output."""
    print(f"\n{Fore.CYAN}🔄 {description}{Style.RESET_ALL}")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"{Fore.GREEN}✅ {description} completed successfully{Style.RESET_ALL}")
        if result.stdout:
            print(result.stdout)
        return True
    except subprocess.CalledProcessError as e:
        print(f"{Fore.RED}❌ {description} failed{Style.RESET_ALL}")
        if e.stdout:
            print(e.stdout)
        if e.stderr:
            print(e.stderr)
        return False

def main():
    """Main execution flow."""
    print(f"{Fore.MAGENTA}🚀 RabbitMQ Log Processing Setup{Style.RESET_ALL}")
    print("=" * 50)
    
    # Check if we're using Docker
    use_docker = len(sys.argv) > 1 and sys.argv[1] == '--docker'
    
    if use_docker:
        print(f"{Fore.YELLOW}🐳 Using Docker setup{Style.RESET_ALL}")
        
        # Start RabbitMQ with Docker
        if not run_command("docker-compose up -d rabbitmq", "Starting RabbitMQ with Docker"):
            return False
            
        # Wait for RabbitMQ to be ready
        print(f"{Fore.YELLOW}⏳ Waiting for RabbitMQ to start...{Style.RESET_ALL}")
        time.sleep(10)
        
    else:
        print(f"{Fore.YELLOW}🖥️ Using native setup (ensure RabbitMQ is installed and running){Style.RESET_ALL}")
    
    # Build and test
    steps = [
        ("bash scripts/build.sh", "Building project"),
        ("bash scripts/test.sh", "Running tests and demos"),
        ("bash scripts/demo.sh", "Running final demonstration")
    ]
    
    for command, description in steps:
        if not run_command(command, description):
            print(f"{Fore.RED}🛑 Setup failed at: {description}{Style.RESET_ALL}")
            return False
    
    # Final success message
    print(f"\n{Fore.GREEN}🎉 RabbitMQ setup completed successfully!{Style.RESET_ALL}")
    print(f"{Fore.CYAN}📊 Management UI: http://localhost:15672{Style.RESET_ALL}")
    print(f"{Fore.CYAN}👤 Credentials: guest/guest{Style.RESET_ALL}")
    
    if use_docker:
        print(f"\n{Fore.YELLOW}🐳 To stop Docker services: docker-compose down{Style.RESET_ALL}")
    
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
