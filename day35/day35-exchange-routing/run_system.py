#!/usr/bin/env python3
"""
Day 35: Exchange Types for Log Routing - Main Execution
"""
import subprocess
import sys
import time
import webbrowser
import threading

def run_command(command, description):
    """Run a command and handle output"""
    print(f"\n🔄 {description}")
    print("-" * 50)
    
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ {description} completed successfully")
            if result.stdout:
                print(result.stdout)
        else:
            print(f"❌ {description} failed")
            if result.stderr:
                print(result.stderr)
            return False
    except Exception as e:
        print(f"❌ Error running {description}: {e}")
        return False
    
    return True

def main():
    print("🚀 Day 35: Exchange Types for Log Routing System")
    print("=" * 60)
    print("This will setup, build, test, and demonstrate the system")
    print()
    
    # Install dependencies
    if not run_command("pip install -r requirements.txt", "Installing Python dependencies"):
        return
    
    # Run tests
    if not run_command("python -m pytest tests/ -v", "Running unit tests"):
        print("⚠️  Tests failed, but continuing with demo...")
    
    # Start RabbitMQ
    print("\n🐰 Starting RabbitMQ...")
    subprocess.run("docker run -d --name log-routing-rabbitmq -p 5672:5672 -p 15672:15672 -e RABBITMQ_DEFAULT_USER=guest -e RABBITMQ_DEFAULT_PASS=guest rabbitmq:3.12-management", shell=True)
    
    print("⏳ Waiting for RabbitMQ to initialize...")
    time.sleep(15)
    
    # Start web dashboard in background
    print("\n🌐 Starting web dashboard...")
    dashboard_process = subprocess.Popen([sys.executable, "web/dashboard.py"])
    
    time.sleep(3)
    
    # Open web browser
    print("🔗 Opening web dashboard...")
    webbrowser.open("http://localhost:5000")
    
    # Run demo
    print("\n🎬 Running demonstration...")
    demo_process = subprocess.Popen([sys.executable, "scripts/demo.py"])
    
    print("\n✅ System is fully operational!")
    print("📊 Web Dashboard: http://localhost:5000")
    print("🐰 RabbitMQ Management: http://localhost:15672 (guest/guest)")
    print("\nPress CTRL+C to stop all services...")
    
    try:
        # Keep main process alive
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Shutting down...")
        demo_process.terminate()
        dashboard_process.terminate()
        subprocess.run("docker stop log-routing-rabbitmq", shell=True)
        subprocess.run("docker rm log-routing-rabbitmq", shell=True)
        print("✅ Cleanup complete")

if __name__ == "__main__":
    main()
